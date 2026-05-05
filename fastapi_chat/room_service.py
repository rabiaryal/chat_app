"""
Room Service: Core business logic for room operations.

Implements the "Database is Truth" principle:
- All membership checks query the database
- Messages are persisted to database for audit trail
- Authorization happens before any state changes
"""

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from models import ChatRoom, CustomUser, Message, FriendRequest
import logging
import uuid
from datetime import datetime

logger = logging.getLogger(__name__)


class RoomService:
    """
    Service layer for room operations.
    Queries database to verify membership and persist messages.
    """
    
    @staticmethod
    async def verify_room_membership(
        session: AsyncSession,
        user_id: int,
        room_id: str
    ) -> bool:
        """
        Verify if a user is a member of a room.
        
        This is the **Database is Truth** check.
        Called by WebSocket endpoint before allowing connection.
        
        Args:
            session: Database session
            user_id: User ID from JWT token
            room_id: Room ID from connection request
            
        Returns:
            True if user is a member, False otherwise
            
        Flow:
            1. Query ChatRoom by ID
            2. Check if user_id is in participants
            3. Return membership status
        """
        try:
            # Query: Get room and check if user is in participants
            query = select(ChatRoom).where(ChatRoom.id == room_id)
            result = await session.execute(query)
            room = result.scalars().first()
            
            if not room:
                logger.warning(f"✗ Room not found: {room_id}")
                return False
            
            if not room.is_active:
                logger.warning(f"✗ Room is inactive: {room_id}")
                return False
            
            # Check if user is in participants list
            is_member = any(p.id == user_id for p in room.participants)
            
            if is_member:
                logger.info(f"✓ User {user_id} is member of room {room_id}")
            else:
                logger.warning(
                    f"✗ User {user_id} is NOT member of room {room_id}. "
                    f"Room has {len(room.participants)} members."
                )
            
            return is_member
            
        except Exception as e:
            logger.error(f"✗ Error verifying room membership: {e}")
            # Fail closed (deny access) if database error
            return False
    
    @staticmethod
    async def get_room_members(
        session: AsyncSession,
        room_id: str
    ) -> list:
        """
        Get all members of a room.
        
        Used to get active participants for broadcasts.
        
        Args:
            session: Database session
            room_id: Room ID
            
        Returns:
            List of dicts with id, username, email
        """
        try:
            query = select(ChatRoom).where(ChatRoom.id == room_id)
            result = await session.execute(query)
            room = result.scalars().first()
            
            if not room:
                return []
            
            members = [
                {
                    "id": p.id,
                    "username": p.username,
                    "email": p.email,
                    "is_online": p.is_online
                }
                for p in room.participants
            ]
            
            logger.info(f"✓ Retrieved {len(members)} members for room {room_id}")
            return members
            
        except Exception as e:
            logger.error(f"Error fetching room members: {e}")
            return []
    
    @staticmethod
    async def save_message(
        session: AsyncSession,
        room_id: str,
        sender_id: int,
        content: str,
        message_type: str = 'TEXT'
    ) -> bool:
        """
        Save a message to the database.
        
        Called after broadcasting to ensure persistence.
        
        Args:
            session: Database session
            room_id: Room ID
            sender_id: User ID of sender
            content: Message text
            message_type: Type of message (TEXT, AI_RESPONSE, etc.)
            
        Returns:
            True if saved successfully, False otherwise
        """
        try:
            message = Message(
                id=str(uuid.uuid4()),
                room_id=room_id,
                sender_id=sender_id,
                content=content,
                message_type=message_type,
                created_at=datetime.utcnow()
            )
            
            session.add(message)
            await session.commit()
            
            logger.info(
                f"✓ Message saved: {message.id} from user {sender_id} "
                f"to room {room_id}"
            )
            return True
            
        except Exception as e:
            logger.error(f"✗ Error saving message: {e}")
            await session.rollback()
            return False
    
    @staticmethod
    async def get_room_info(
        session: AsyncSession,
        room_id: str
    ) -> dict:
        """
        Get detailed information about a room.
        
        Args:
            session: Database session
            room_id: Room ID
            
        Returns:
            Dict with room info or None if not found
        """
        try:
            query = select(ChatRoom).where(ChatRoom.id == room_id)
            result = await session.execute(query)
            room = result.scalars().first()
            
            if not room:
                return None
            
            return {
                "id": room.id,
                "name": room.name,
                "description": room.description,
                "room_type": room.room_type,
                "is_active": room.is_active,
                "creator_id": room.creator_id,
                "participants_count": len(room.participants),
                "created_at": room.created_at.isoformat() if room.created_at else None,
                "updated_at": room.updated_at.isoformat() if room.updated_at else None,
            }
            
        except Exception as e:
            logger.error(f"Error fetching room info: {e}")
            return None
    
    @staticmethod
    async def mark_message_read(
        session: AsyncSession,
        message_id: str
    ) -> bool:
        """
        Mark a message as read in the database.
        
        Args:
            session: Database session
            message_id: Message ID
            
        Returns:
            True if updated successfully
        """
        try:
            query = select(Message).where(Message.id == message_id)
            result = await session.execute(query)
            message = result.scalars().first()
            
            if message:
                message.is_read = True
                message.updated_at = datetime.utcnow()
                await session.commit()
                logger.info(f"✓ Message {message_id} marked as read")
                return True
            
            return False
            
        except Exception as e:
            logger.error(f"Error marking message as read: {e}")
            await session.rollback()
            return False


# Global instance
room_service = RoomService()


class FriendService:
    """Service layer for friendship operations."""

    @staticmethod
    async def get_incoming_requests(session: AsyncSession, user_id: int) -> list:
        """Get all incoming friend requests for a user."""
        try:
            query = select(FriendRequest).where(FriendRequest.to_user_id == user_id, FriendRequest.status == 'PENDING')
            result = await session.execute(query)
            requests = result.scalars().all()
            return requests
        except Exception as e:
            logger.error(f"✗ Error getting incoming friend requests: {e}")
            return []

    @staticmethod
    async def get_outgoing_requests(session: AsyncSession, user_id: int) -> list:
        """Get all outgoing friend requests for a user."""
        try:
            query = select(FriendRequest).where(FriendRequest.from_user_id == user_id, FriendRequest.status == 'PENDING')
            result = await session.execute(query)
            requests = result.scalars().all()
            return requests
        except Exception as e:
            logger.error(f"✗ Error getting outgoing friend requests: {e}")
            return []

# Instantiate service
friend_service = FriendService()
