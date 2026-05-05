# FastAPI Room Membership Verification Implementation

## Step 1: Add Database Connection to FastAPI

Create `fastapi_chat/db.py`:

```python
"""
Database connection setup for FastAPI.
Connects to the same PostgreSQL as Django.
"""
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
from config import settings
import logging

logger = logging.getLogger(__name__)

# Create async engine
engine = create_async_engine(
    settings.DATABASE_URL.replace('postgresql://', 'postgresql+asyncpg://'),
    pool_size=20,
    max_overflow=10,
    echo=False,
    pool_pre_ping=True,  # Verify connections before using
)

# Create session factory
AsyncSessionLocal = sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)

async def get_db() -> AsyncSession:
    """Get a database session for dependency injection."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

async def init_db():
    """Initialize database connection pool."""
    try:
        async with engine.begin() as conn:
            await conn.run_sync(lambda c: None)  # Test connection
        logger.info("✓ Database connection pool initialized")
    except Exception as e:
        logger.error(f"✗ Failed to initialize database: {e}")

async def close_db():
    """Close database connection pool."""
    await engine.dispose()
    logger.info("✓ Database connection pool closed")
```

---

## Step 2: Add Models to FastAPI

Create `fastapi_chat/models.py`:

```python
"""
SQLAlchemy models that mirror Django models.
Used for querying in FastAPI.
"""
from sqlalchemy import Column, String, Integer, Boolean, DateTime, ForeignKey, Table
from sqlalchemy.orm import declarative_base, relationship
from datetime import datetime

Base = declarative_base()

# Association table for M2M relationship
room_participants = Table(
    'chat_app_chatroom_participants',
    Base.metadata,
    Column('chatroom_id', String(36), ForeignKey('chat_app_chatroom.id')),
    Column('customuser_id', Integer, ForeignKey('auth_user.id')),
    schema='public'
)

class ChatRoom(Base):
    """Mirror of Django ChatRoom model."""
    __tablename__ = 'chat_app_chatroom'
    __table_args__ = {'schema': 'public'}
    
    id = Column(String(36), primary_key=True)
    name = Column(String(255))
    description = Column(String)
    room_type = Column(String(10))
    creator_id = Column(Integer, ForeignKey('auth_user.id'))
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    
    participants = relationship(
        'CustomUser',
        secondary=room_participants,
        lazy='selectin'
    )

class CustomUser(Base):
    """Mirror of Django CustomUser model."""
    __tablename__ = 'auth_user'
    __table_args__ = {'schema': 'public'}
    
    id = Column(Integer, primary_key=True)
    username = Column(String(150), unique=True)
    email = Column(String(254))
    is_active = Column(Boolean, default=True)
    
    chat_rooms = relationship(
        'ChatRoom',
        secondary=room_participants,
        lazy='selectin'
    )

class Message(Base):
    """Mirror of Django Message model."""
    __tablename__ = 'chat_app_message'
    __table_args__ = {'schema': 'public'}
    
    id = Column(String(36), primary_key=True)
    room_id = Column(String(36), ForeignKey('chat_app_chatroom.id'))
    sender_id = Column(Integer, ForeignKey('auth_user.id'))
    content = Column(String)
    message_type = Column(String(20), default='TEXT')
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow)
```

---

## Step 3: Add Membership Verification Service

Create `fastapi_chat/room_service.py`:

```python
"""
Room membership verification service.
Acts as source of truth for who can access what rooms.
"""
from sqlalchemy.orm import SelectableAlchemy
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from models import ChatRoom, CustomUser, Message
import logging

logger = logging.getLogger(__name__)

class RoomService:
    """Service for room operations and verification."""
    
    @staticmethod
    async def is_user_in_room(
        session: AsyncSession,
        user_id: int,
        room_id: str
    ) -> bool:
        """
        Verify if a user is a member of a room.
        
        This is "Database is Truth" - the authoritative check.
        
        Args:
            session: Database session
            user_id: User ID from JWT
            room_id: Room ID from request
            
        Returns:
            True if user is a member, False otherwise
        """
        try:
            query = select(ChatRoom).where(
                ChatRoom.id == room_id,
                ChatRoom.participants.any(CustomUser.id == user_id)
            )
            
            result = await session.execute(query)
            room = result.scalars().first()
            
            is_member = room is not None
            logger.info(
                f"{'✓' if is_member else '✗'} User {user_id} "
                f"{'is' if is_member else 'is NOT'} in room {room_id}"
            )
            
            return is_member
            
        except Exception as e:
            logger.error(f"✗ Error checking room membership: {e}")
            # Default to deny on error for security
            return False
    
    @staticmethod
    async def get_room_members(
        session: AsyncSession,
        room_id: str
    ) -> list:
        """Get all members of a room from database."""
        try:
            query = select(ChatRoom).where(ChatRoom.id == room_id)
            result = await session.execute(query)
            room = result.scalars().first()
            
            if not room:
                return []
            
            return [
                {"id": p.id, "username": p.username, "email": p.email}
                for p in room.participants
            ]
        except Exception as e:
            logger.error(f"Error fetching room members: {e}")
            return []
    
    @staticmethod
    async def save_message(
        session: AsyncSession,
        message_id: str,
        room_id: str,
        sender_id: int,
        content: str,
        message_type: str = 'TEXT'
    ) -> bool:
        """
        Save a message to the database.
        
        Args:
            session: Database session
            message_id: Unique message ID
            room_id: Room ID
            sender_id: User ID of sender
            content: Message content
            message_type: Type of message (TEXT, AI_RESPONSE, etc.)
            
        Returns:
            True if saved successfully
        """
        try:
            message = Message(
                id=message_id,
                room_id=room_id,
                sender_id=sender_id,
                content=content,
                message_type=message_type
            )
            session.add(message)
            await session.commit()
            logger.info(f"✓ Message {message_id} saved to database")
            return True
        except Exception as e:
            logger.error(f"✗ Error saving message: {e}")
            await session.rollback()
            return False

# Global service instance
room_service = RoomService()
```

---

## Step 4: Update FastAPI WebSocket Endpoint

Update `fastapi_chat/main.py`:

```python
# Add imports at the top:
from db import AsyncSessionLocal, init_db, close_db
from room_service import room_service
from models import ChatRoom, CustomUser, Message
import uuid

# Modify lifespan to include database init:
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    global redis_client
    
    # Initialize database
    await init_db()
    
    try:
        redis_client = await redis.from_url(...)
        ...
    except Exception as e:
        logger.error(f"Failed to connect to Redis: {e}")
        redis_client = None
    
    yield
    
    # Shutdown
    await close_db()  # Add this
    if redis_client:
        await redis_client.close()

# Update WebSocket endpoint:
@app.websocket("/ws/chat/{room_id}")
async def websocket_endpoint(websocket: WebSocket, room_id: str, token: str = Query(...)):
    """WebSocket endpoint with room membership verification."""
    
    # ────── Step 1: Verify JWT ──────
    try:
        payload = verify_token(token)
        user_id = payload.get('user_id')
        username = payload.get('username')
        email = payload.get('email')
        
        if not user_id or not username:
            await websocket.close(code=4001, reason="Invalid token claims")
            return
    except Exception as e:
        await websocket.close(code=4001, reason=f"Token verification failed: {str(e)}")
        return
    
    # ────── Step 2: Verify Room Membership ──────
    async with AsyncSessionLocal() as session:
        is_member = await room_service.is_user_in_room(
            session,
            user_id,
            room_id
        )
    
    if not is_member:
        await websocket.close(
            code=4003,
            reason="User is not a member of this room"
        )
        logger.warning(
            f"✗ Unauthorized room access attempt: User {user_id} "
            f"to room {room_id}"
        )
        return
    
    # ────── Step 3: Connect to Room ──────
    connection = await manager.connect(websocket, room_id, user_id, username, email)
    
    try:
        while True:
            data = await websocket.receive_text()
            message_data = json.loads(data)
            message_type = message_data.get('type', 'text_message')
            
            # Validate message
            try:
                validated_message = MessageIn(
                    text=message_data.get('text', ''),
                    room_id=room_id,
                    type=message_type,
                    timestamp=message_data.get('timestamp')
                )
            except ValidationError as e:
                error_response = ErrorMessage(
                    message="Validation failed",
                    error_code="VALIDATION_ERROR"
                )
                await manager.send_personal(websocket, error_response.dict())
                continue
            
            # Handle different message types
            if validated_message.type == 'text_message':
                await handle_text_message(
                    manager, room_id, user_id, username,
                    validated_message.text
                )
            elif validated_message.type == 'ai_request':
                await handle_ai_request(
                    manager, room_id, user_id, username,
                    validated_message.text
                )
            elif validated_message.type == 'typing':
                typing_indicator = TypingIndicator(
                    type='typing',
                    room_id=room_id,
                    user_id=user_id,
                    username=username
                )
                await manager.broadcast_to_room(room_id, typing_indicator.dict(), exclude_user_id=user_id)
    
    except WebSocketDisconnect:
        manager.disconnect(room_id, connection)
        user_left = UserLeftEvent(user_id=user_id, username=username)
        await manager.broadcast_to_room(room_id, user_left.dict())
    
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        manager.disconnect(room_id, connection)

# Update message handlers to save to database:
async def handle_text_message(
    manager: ConnectionManager,
    room_id: str,
    user_id: int,
    username: str,
    content: str,
):
    """Handle text messages with persistence."""
    message_id = str(uuid.uuid4())
    
    # Broadcast immediately
    message_response = MessageOut(
        type="text_message",
        room_id=room_id,
        user_id=user_id,
        username=username,
        text=content,
        message_id=message_id,
        timestamp=datetime.utcnow().isoformat()
    )
    await manager.broadcast_to_room(room_id, message_response.dict())
    logger.info(f"✓ Text message {message_id} broadcast to {room_id}")
    
    # Save to database
    async with AsyncSessionLocal() as session:
        await room_service.save_message(
            session,
            message_id,
            room_id,
            user_id,
            content,
            'TEXT'
        )
```

---

## Step 5: Update requirements.txt

Add:
```txt
sqlalchemy==2.0.23
asyncpg==0.29.0
```

---

## Step 6: Update .env

Make sure DATABASE_URL uses async driver:
```bash
DATABASE_URL=postgresql+asyncpg://chat_user:chat_password@postgres:5432/chat_db
```

---

## Testing the Implementation

1. **Test 1: Valid User in Valid Room**
   ```bash
   # User 1 (in room "projects") connects to room "projects"
   # Result: ✓ Connection accepted
   ```

2. **Test 2: Valid User in Wrong Room**
   ```bash
   # User 1 (in room "projects") tries to connect to room "accounting"
   # Result: ✗ Connection rejected (4003)
   ```

3. **Test 3: Invalid Token**
   ```bash
   # Any user with invalid JWT
   # Result: ✗ Connection rejected (4001)
   ```

4. **Test 4: Message Persistence**
   ```bash
   # Send message and check PostgreSQL
   # Result: ✓ Message saved in Message table
   ```

---

## Security Checklist After Implementation

- ✅ JWT verified before room access
- ✅ Room membership verified before connection
- ✅ Only members of a room can send to it
- ✅ Messages saved for audit trail
- ✅ Disconnect properly cleaned up
- ✅ Database is source of truth
- ✅ In-memory only tracks active connections

This completes the **professional-grade, production-ready chat system!**

