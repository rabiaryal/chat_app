"""
Main FastAPI application with WebSocket chat endpoint and Redis integration.

Architecture:
- JWT verification for authentication
- Database membership verification for authorization
- In-memory connection tracking per room
- Redis pub/sub for distributed messaging
- Message persistence to database
"""

import asyncio
from fastapi import (
    FastAPI, WebSocket, WebSocketDisconnect, Depends, HTTPException,
    status, Query, BackgroundTasks
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import json
from datetime import datetime
from typing import Dict, List, Set, Optional
import logging
import redis.asyncio as redis
from contextlib import asynccontextmanager

from config import settings, CORS_ALLOWED_ORIGINS
from jwt_utils import JWTHandler
from ai_utils import AIChat, ConversationContext
from schemas import (
    MessageIn, MessageOut, TypingIndicator, AIRequest, AIResponse,
    ErrorMessage, RoomUsersUpdate, UserJoinedEvent, UserLeftEvent,
    FriendRequestOut
)
from pydantic import ValidationError

# Database imports
from db import AsyncSessionLocal, init_db, close_db
from room_service import room_service, friend_service

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global Redis client
redis_client: Optional[redis.Redis] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Manage the lifespan of the FastAPI application.
    Handles startup and shutdown of:
    - Database connection pool
    - Redis connections
    """
    # ┌─────────────────────────────────────────────────┐
    # │ STARTUP                                         │
    # └─────────────────────────────────────────────────┘
    global redis_client
    
    # 1. Initialize database
    db_ok = await init_db()
    if not db_ok:
        logger.warning("⚠ Continuing without database (local mode)")
    
    # 2. Connect to Redis
    try:
        redis_client = await redis.from_url(
            settings.REDIS_URL,
            encoding="utf8",
            decode_responses=True
        )
        await redis_client.ping()
        logger.info("✓ Redis connected successfully")
    except Exception as e:
        logger.error(f"✗ Failed to connect to Redis: {e}")
        redis_client = None
    
    yield
    
    # ┌─────────────────────────────────────────────────┐
    # │ SHUTDOWN                                        │
    # └─────────────────────────────────────────────────┘
    
    # 1. Close database
    await close_db()
    
    # 2. Close Redis
    if redis_client:
        await redis_client.close()
        logger.info("✓ Redis connection closed")


# Initialize FastAPI app with lifespan
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    debug=settings.DEBUG,
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Dependency to get user from token
async def get_current_user(token: str = Query(...)):
    """
    Get the current user from the JWT token.

    Args:
        token: JWT token string

    Returns:
        User ID from the token

    Raises:
        Exception: If token is invalid or verification fails (401)
    """
    try:
        payload = verify_token(token)
        user_id = payload.get('user_id')
        username = payload.get('username')
        email = payload.get('email')
        
        if not user_id or not username:
            await websocket.close(code=4001, reason="Invalid token: missing user_id or username")
            logger.warning(f"Token missing required claims: {payload}")
            return
            
    except Exception as e:
        await websocket.close(code=4001, reason=f"Unauthorized: {str(e)}")
        logger.warning(f"WebSocket connection rejected - {e}")
        return
    
    return user_id


@app.get("/api/v1/friendship/requests/incoming/", response_model=List[FriendRequestOut])
async def get_incoming_friend_requests(
    current_user: int = Depends(get_current_user)
):
    """Get all incoming friend requests for the current user."""
    async with AsyncSessionLocal() as session:
        requests = await friend_service.get_incoming_requests(session, current_user)
        return requests


@app.get("/api/v1/friendship/requests/outgoing/", response_model=List[FriendRequestOut])
async def get_outgoing_friend_requests(
    current_user: int = Depends(get_current_user)
):
    """Get all outgoing friend requests for the current user."""
    async with AsyncSessionLocal() as session:
        requests = await friend_service.get_outgoing_requests(session, current_user)
        return requests


# ============================================================================
# 3. WEBSOCKET ENDPOINT
# ============================================================================
@app.websocket("/ws/chat/{room_id}")
async def websocket_endpoint(websocket: WebSocket, room_id: str, token: str = Query(...)):
    """
    WebSocket endpoint for real-time chat with JWT authentication.
    
    Path Parameters:
        room_id: The chat room ID
        
    Query Parameters:
        token: JWT token from Django authentication (required)
    
    Connection Requirements:
        - Valid JWT token with user_id and username claims
        - Properly formatted WebSocket upgrade request
        
    Example URL:
        ws://192.168.1.65:8081/ws/chat/room-123?token=<jwt_token>
        
    Message Types:
        - text_message: Regular chat message
        - ai_request: Request AI response
        - typing: User typing indicator
    """
    # ────────────────────────────────────────────────────────────────────
    # Step 1: Verify JWT Token (401 on failure)
    # ────────────────────────────────────────────────────────────────────
    try:
        payload = verify_token(token)
        user_id = payload.get('user_id')
        username = payload.get('username')
        email = payload.get('email')
        
        if not user_id or not username:
            await websocket.close(code=4001, reason="Invalid token: missing user_id or username")
            logger.warning(f"Token missing required claims: {payload}")
            return
            
    except Exception as e:
        await websocket.close(code=4001, reason=f"Unauthorized: {str(e)}")
        logger.warning(f"WebSocket connection rejected - {e}")
        return
    
    # ────────────────────────────────────────────────────────────────────
    # Step 2: VERIFY ROOM MEMBERSHIP (Database is Truth) (403 on failure)
    # ────────────────────────────────────────────────────────────────────
    async with AsyncSessionLocal() as session:
        is_member = await room_service.verify_room_membership(
            session,
            user_id,
            room_id
        )
    
    if not is_member:
        await websocket.close(
            code=4003,
            reason="Forbidden: User is not a member of this room"
        )
        logger.warning(
            f"✗ UNAUTHORIZED room access attempt: User {user_id} ({username}) "
            f"tried to access room {room_id}"
        )
        return
    
    # ────────────────────────────────────────────────────────────────────
    # Step 3: Register Socket and Connect
    # ────────────────────────────────────────────────────────────────────
    connection = await manager.connect(websocket, room_id, user_id, username, email)
    logger.info(f"✓ WebSocket connected: {username} in room {room_id}")
    
    # Send current room users to the new connection
    room_users = manager.get_room_users(room_id)
    await manager.send_personal(
        websocket,
        {
            "type": "room_users",
            "users": room_users,
            "room_id": room_id,
            "user_id": user_id,
            "username": username,
            "timestamp": datetime.utcnow().isoformat()
        }
    )
    
    # ────────────────────────────────────────────────────────────────────
    # Step 3: Start Receive Loop
    # ────────────────────────────────────────────────────────────────────
    try:
        while True:
            # Receive message from client
            data = await websocket.receive_text()
            
            # ────────────────────────────────────────────────────────────────
            # Validate message schema using Pydantic
            # ────────────────────────────────────────────────────────────────
            try:
                message_data = json.loads(data)
            except json.JSONDecodeError as e:
                error_response = ErrorMessage(
                    message="Invalid JSON format",
                    error_code="INVALID_JSON"
                )
                await manager.send_personal(websocket, error_response.dict())
                logger.warning(f"Invalid JSON from {username}: {str(e)[:100]}")
                continue
            
            message_type = message_data.get('type', 'text_message')
            
            # Validate against MessageIn schema
            try:
                validated_message = MessageIn(
                    text=message_data.get('text', ''),
                    room_id=room_id,
                    type=message_type,
                    timestamp=message_data.get('timestamp')
                )
                logger.info(
                    f"✓ Message validated from @{username} "
                    f"({validated_message.type}): {validated_message.text[:50]}..."
                )
            except ValidationError as e:
                error_response = ErrorMessage(
                    message=f"Message validation failed: {e.error_count()} error(s)",
                    error_code="VALIDATION_ERROR"
                )
                await manager.send_personal(websocket, error_response.dict())
                logger.warning(
                    f"Validation error from {username}: {e.json()[:200]}"
                )
                continue
            
            # Handle different message types
            if validated_message.type == 'text_message':
                await handle_text_message(
                    manager, room_id, user_id, username,
                    validated_message.text, validated_message.timestamp
                )
            
            elif validated_message.type == 'ai_request':
                await handle_ai_request(
                    manager, room_id, user_id, username,
                    validated_message.text, validated_message.timestamp
                )
            
            elif validated_message.type == 'typing':
                typing_indicator = TypingIndicator(
                    type='typing',
                    room_id=room_id,
                    user_id=user_id,
                    username=username
                )
                await manager.broadcast_to_room(
                    room_id,
                    typing_indicator.dict(),
                    exclude_user_id=user_id
                )
            
            elif validated_message.type == 'stop_typing':
                stop_typing = TypingIndicator(
                    type='stop_typing',
                    room_id=room_id,
                    user_id=user_id,
                    username=username
                )
                await manager.broadcast_to_room(
                    room_id,
                    stop_typing.dict(),
                    exclude_user_id=user_id
                )
    
    except WebSocketDisconnect:
        manager.disconnect(room_id, connection)
        
        # Create and broadcast user left event
        user_left = UserLeftEvent(
            user_id=user_id,
            username=username
        )
        await manager.broadcast_to_room(room_id, user_left.dict())
        
        # Publish to Redis
        if redis_client:
            await redis_client.publish(
                f"room:{room_id}",
                json.dumps(user_left.dict())
            )
        
        logger.info(f"✗ WebSocket disconnected: {username}")
    
    except Exception as e:
        logger.error(f"WebSocket error for {username}: {e}")
        manager.disconnect(room_id, connection)


# ============================================================================
# MESSAGE HANDLERS
# ============================================================================
async def handle_text_message(
    manager: ConnectionManager,
    room_id: str,
    user_id: int,
    username: str,
    content: str,
    timestamp: datetime = None
):
    """
    Handle regular text messages.
    
    Args:
        manager: ConnectionManager instance
        room_id: Room ID
        user_id: User ID
        username: Username
        content: Message content (validated)
        timestamp: Message timestamp (auto-set if None)
    """
    if timestamp is None:
        timestamp = datetime.utcnow()
    
    message_id = f"{room_id}_{user_id}_{datetime.utcnow().timestamp()}"
    
    # Create validated response message
    message = MessageOut(
        type="text_message",
        room_id=room_id,
        user_id=user_id,
        username=username,
        text=content,
        message_id=message_id,
        timestamp=timestamp
    )
    
    # Add to conversation context
    if room_id in manager.room_contexts:
        manager.room_contexts[room_id].add_message("user", content, user_id)
    
    # Broadcast to all WebSocket users in the room
    await manager.broadcast_to_room(room_id, message.dict())
    
    # ────────────────────────────────────────────────────────────────────
    # 4. SAVE MESSAGE TO DATABASE (Persistence)
    # ────────────────────────────────────────────────────────────────────
    async with AsyncSessionLocal() as session:
        saved = await room_service.save_message(
            session,
            room_id,
            user_id,
            content,
            'TEXT'
        )
        if not saved:
            logger.warning(f"Failed to persist message {message_id} to database")
    
    # ────────────────────────────────────────────────────────────────────
    # 5. REDIS PUB/SUB INTEGRATION
    # ────────────────────────────────────────────────────────────────────
    # Publish to Redis for distributed systems
    if redis_client:
        try:
            await redis_client.publish(
                f"room:{room_id}",
                json.dumps(message.dict())
            )
            logger.info(
                f"✓ Published to Redis room:{room_id} "
                f"by @{username} (ID: {message_id})"
            )
        except Exception as e:
            logger.error(
                f"Error publishing to Redis for room {room_id}: {e}"
            )


async def handle_ai_request(
    manager: ConnectionManager,
    room_id: str,
    user_id: int,
    username: str,
    content: str,
    timestamp: datetime = None
):
    """
    Handle AI response requests.
    
    Args:
        manager: ConnectionManager instance
        room_id: Room ID
        user_id: User ID
        username: Username
        content: Message content (validated)
        timestamp: Message timestamp (auto-set if None)
    """
    if timestamp is None:
        timestamp = datetime.utcnow()
    
    # Send user message first as validated response
    user_message_id = f"{room_id}_{user_id}_{datetime.utcnow().timestamp()}"
    user_message = MessageOut(
        type="text_message",
        room_id=room_id,
        user_id=user_id,
        username=username,
        text=content,
        message_id=user_message_id,
        timestamp=timestamp
    )
    
    await manager.broadcast_to_room(room_id, user_message.dict())
    
    # Save user message to database
    async with AsyncSessionLocal() as session:
        await room_service.save_message(
            session,
            room_id,
            user_id,
            content,
            'TEXT'
        )
    
    # Publish to Redis
    if redis_client:
        await redis_client.publish(
            f"room:{room_id}",
            json.dumps(user_message.dict())
        )
    
    # Add to conversation context and generate AI response
    if room_id in manager.room_contexts:
        manager.room_contexts[room_id].add_message("user", content, user_id)
        
        # Get AI response
        try:
            ai_chat = AIChat()
            ai_response = await ai_chat.get_response(
                content,
                manager.room_contexts[room_id]
            )
            
            # Add AI response to context
            manager.room_contexts[room_id].add_message("assistant", ai_response)
            
            # Broadcast AI response as validated response
            ai_message_id = f"{room_id}_ai_{datetime.utcnow().timestamp()}"
            ai_message = AIResponse(
                type="ai_response",
                room_id=room_id,
                text=ai_response,
                message_id=ai_message_id,
                timestamp=datetime.utcnow()
            )
            
            await manager.broadcast_to_room(room_id, ai_message.dict())
            
            # Save AI response to database
            async with AsyncSessionLocal() as session:
                await room_service.save_message(
                    session,
                    room_id,
                    user_id,  # AI is attributed to the user who requested it
                    ai_response,
                    'AI_RESPONSE'
                )
            
            # Publish to Redis
            if redis_client:
                await redis_client.publish(
                    f"room:{room_id}",
                    json.dumps(ai_message.dict())
                )
            
            logger.info(
                f"✓ AI response generated for room {room_id} "
                f"from question by @{username}"
            )
        
        except Exception as e:
            logger.error(f"Error generating AI response: {e}")
            error_message = ErrorMessage(
                message=f"Failed to generate AI response: {str(e)[:200]}",
                error_code="AI_RESPONSE_ERROR"
            )
            await manager.broadcast_to_room(room_id, error_message.dict())


# ============================================================================
# BACKGROUND TASK FOR REDIS LISTENING
# ============================================================================
@app.on_event("startup")
async def startup_redis_listener():
    """
    Background task that listens to Redis Pub/Sub channels.
    
    On message receive: Broadcast to applicable WebSocket connections
    """
    async def redis_listener():
        if not redis_client:
            logger.warning("Redis not available, skipping listener")
            return
        
        logger.info("Starting Redis Pub/Sub listener...")
        
        try:
            # Create a separate pubsub for listening to all rooms
            pubsub = redis_client.pubsub()
            await pubsub.psubscribe("room:*")
            
            async for message in pubsub.listen():
                if message['type'] == 'pmessage':
                    room_id = message['channel'].replace('room:', '')
                    
                    try:
                        data = json.loads(message['data'])
                        logger.info(f"Redis received from {room_id}: {data.get('type')}")
                        
                        # Broadcast to WebSocket subscribers if they exist
                        if room_id in manager.active_connections:
                            await manager.broadcast_to_room(room_id, data)
                    
                    except json.JSONDecodeError:
                        logger.error(f"Invalid JSON in Redis message: {message['data']}")
                    except Exception as e:
                        logger.error(f"Error processing Redis message: {e}")
        
        except Exception as e:
            logger.error(f"Redis listener error: {e}")
    
    # Start the listener in a background task
    asyncio.create_task(redis_listener())


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.RELOAD
    )


# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    debug=settings.DEBUG
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# WebSocket connection manager
class ConnectionManager:
    """Manager for WebSocket connections."""
    
    def __init__(self):
        # Dict of room_id -> list of connections
        self.active_connections: Dict[str, List[Dict]] = {}
        # Track conversation contexts per room
        self.room_contexts: Dict[str, ConversationContext] = {}
    
    async def connect(self, websocket: WebSocket, room_id: str, user_id: int, username: str):
        """Accept and register a WebSocket connection."""
        await websocket.accept()
        
        if room_id not in self.active_connections:
            self.active_connections[room_id] = []
            self.room_contexts[room_id] = ConversationContext()
        
        connection = {
            "websocket": websocket,
            "user_id": user_id,
            "username": username,
            "connected_at": datetime.utcnow().isoformat()
        }
        
        self.active_connections[room_id].append(connection)
        logger.info(f"User {username} connected to room {room_id}")
        
        # Notify others about new user
        await self.broadcast_to_room(
            room_id,
            {
                "type": "user_joined",
                "username": username,
                "user_id": user_id,
                "timestamp": datetime.utcnow().isoformat()
            },
            exclude_user_id=user_id
        )
        
        return connection
    
    def disconnect(self, room_id: str, connection: Dict):
        """Remove a WebSocket connection."""
        if room_id in self.active_connections:
            self.active_connections[room_id] = [
                conn for conn in self.active_connections[room_id]
                if conn != connection
            ]
            logger.info(f"User {connection['username']} disconnected from room {room_id}")
    
    async def broadcast_to_room(self, room_id: str, data: Dict, exclude_user_id: int = None):
        """Broadcast a message to all users in a room."""
        if room_id not in self.active_connections:
            return
        
        message = json.dumps(data)
        disconnected = []
        
        for connection in self.active_connections[room_id]:
            if exclude_user_id and connection['user_id'] == exclude_user_id:
                continue
            
            try:
                await connection['websocket'].send_text(message)
            except Exception as e:
                logger.error(f"Error sending message to {connection['username']}: {e}")
                disconnected.append(connection)
        
        # Clean up disconnected connections
        for conn in disconnected:
            self.disconnect(room_id, conn)
    
    async def send_personal(self, websocket: WebSocket, data: Dict):
        """Send a personal message to a specific connection."""
        try:
            await websocket.send_text(json.dumps(data))
        except Exception as e:
            logger.error(f"Error sending personal message: {e}")
    
    def get_room_users(self, room_id: str) -> List[Dict]:
        """Get all users in a room."""
        if room_id not in self.active_connections:
            return []
        return [
            {
                "user_id": conn['user_id'],
                "username": conn['username'],
            }
            for conn in self.active_connections[room_id]
        ]


manager = ConnectionManager()


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "timestamp": datetime.utcnow().isoformat()
    }


# WebSocket chat endpoint
@app.websocket("/ws/chat/{room_id}")
async def websocket_endpoint(websocket: WebSocket, room_id: str, token: str = Query(...)):
    """
    WebSocket endpoint for real-time chat.
    
    Connection requires:
    - room_id: The chat room ID
    - token: JWT token from Django (as query parameter)
    
    Usage:
        ws://localhost:8081/ws/chat/room123?token=<jwt_token>
    """
    # Verify JWT token
    try:
        payload = await get_token_from_query(token)
        user_id = payload.get('user_id')
        username = payload.get('username')
        email = payload.get('email')
        
        if not user_id or not username:
            await websocket.close(code=4001, reason="Invalid token payload")
            return
            
    except Exception as e:
        await websocket.close(code=4001, reason=f"Authentication failed: {str(e)}")
        return
    
    # Accept connection and register
    connection = await manager.connect(websocket, room_id, user_id, username)
    
    # Send current room users to the new user
    room_users = manager.get_room_users(room_id)
    await manager.send_personal(
        websocket,
        {
            "type": "room_users",
            "users": room_users,
            "room_id": room_id,
            "timestamp": datetime.utcnow().isoformat()
        }
    )
    
    try:
        while True:
            # Receive message from client
            data = await websocket.receive_text()
            message_data = json.loads(data)
            
            message_type = message_data.get('type', 'text_message')
            content = message_data.get('content', '')
            
            logger.info(f"Message from {username} in room {room_id}: {content[:50]}")
            
            # Handle different message types
            if message_type == 'text_message':
                # Regular text message
                await handle_text_message(
                    websocket, manager, room_id, user_id, username, content
                )
            
            elif message_type == 'ai_request':
                # Request AI response
                await handle_ai_request(
                    websocket, manager, room_id, user_id, username, content
                )
            
            elif message_type == 'typing':
                # User typing indicator
                await manager.broadcast_to_room(
                    room_id,
                    {
                        "type": "user_typing",
                        "user_id": user_id,
                        "username": username,
                        "timestamp": datetime.utcnow().isoformat()
                    },
                    exclude_user_id=user_id
                )
            
    except WebSocketDisconnect:
        connection = {
            "websocket": websocket,
            "user_id": user_id,
            "username": username
        }
        manager.disconnect(room_id, connection)
        
        # Notify others about user leaving
        await manager.broadcast_to_room(
            room_id,
            {
                "type": "user_left",
                "username": username,
                "user_id": user_id,
                "timestamp": datetime.utcnow().isoformat()
            }
        )
        logger.info(f"WebSocket connection closed for user {username}")


async def handle_text_message(
    websocket: WebSocket,
    manager: ConnectionManager,
    room_id: str,
    user_id: int,
    username: str,
    content: str
):
    """Handle regular text messages."""
    message = {
        "type": "text_message",
        "room_id": room_id,
        "user_id": user_id,
        "username": username,
        "content": content,
        "message_id": f"{room_id}_{user_id}_{datetime.utcnow().timestamp()}",
        "timestamp": datetime.utcnow().isoformat()
    }
    
    # Add to conversation context
    if room_id in manager.room_contexts:
        manager.room_contexts[room_id].add_message("user", content, user_id)
    
    # Broadcast to all users in the room
    await manager.broadcast_to_room(room_id, message)


async def handle_ai_request(
    websocket: WebSocket,
    manager: ConnectionManager,
    room_id: str,
    user_id: int,
    username: str,
    content: str
):
    """Handle AI response requests."""
    # Send message to room
    message = {
        "type": "text_message",
        "room_id": room_id,
        "user_id": user_id,
        "username": username,
        "content": content,
        "message_id": f"{room_id}_{user_id}_{datetime.utcnow().timestamp()}",
        "timestamp": datetime.utcnow().isoformat()
    }
    
    await manager.broadcast_to_room(room_id, message)
    
    # Add to conversation context
    if room_id in manager.room_contexts:
        manager.room_contexts[room_id].add_message("user", content, user_id)
    
    # Generate AI response with streaming
    try:
        async for chunk in AIChat.generate_response(content, user_id, room_id):
            # Parse and broadcast each chunk
            chunk_data = json.loads(chunk.strip())
            await manager.broadcast_to_room(room_id, chunk_data)
            await asyncio.sleep(0.05)  # Rate limit
        
        # Add AI response to context
        if room_id in manager.room_contexts:
            manager.room_contexts[room_id].add_message("assistant", "AI Response", None)
            
    except Exception as e:
        logger.error(f"Error generating AI response: {e}")
        error_msg = {
            "type": "error",
            "message": f"Failed to generate AI response: {str(e)}",
            "timestamp": datetime.utcnow().isoformat()
        }
        await manager.send_personal(websocket, error_msg)


# Info endpoint to get current active connections
@app.get("/rooms/{room_id}/info")
async def get_room_info(room_id: str):
    """Get information about a chat room."""
    users = manager.get_room_users(room_id)
    return {
        "room_id": room_id,
        "active_users": users,
        "user_count": len(users),
        "timestamp": datetime.utcnow().isoformat()
    }


# Error handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    """Custom HTTP exception handler."""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "detail": exc.detail,
            "timestamp": datetime.utcnow().isoformat()
        }
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.RELOAD
    )
