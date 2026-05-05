"""
Pydantic models for message validation in FastAPI WebSocket.
"""

from pydantic import BaseModel, Field, validator
from typing import Optional, Literal
from datetime import datetime
import uuid


class MessageIn(BaseModel):
    """
    Message schema for incoming WebSocket messages.
    
    Validates:
    - text: Message content (non-empty string)
    - room_id: Chat room identifier
    - type: Message type (text_message, ai_request, typing, etc.)
    - timestamp: Message timestamp
    """
    
    text: str = Field(..., min_length=1, max_length=5000, description="Message content")
    room_id: str = Field(..., min_length=1, description="Chat room ID")
    type: Literal["text_message", "ai_request", "typing", "stop_typing"] = Field(
        default="text_message",
        description="Type of message"
    )
    timestamp: Optional[datetime] = Field(
        default_factory=datetime.utcnow,
        description="Message timestamp (auto-generated if not provided)"
    )
    
    class Config:
        json_schema_extra = {
            "example": {
                "text": "Hello everyone!",
                "room_id": "room-123",
                "type": "text_message",
                "timestamp": "2024-01-01T12:00:00"
            }
        }
    
    @validator('text')
    def text_not_empty(cls, v):
        """Ensure text is not just whitespace."""
        if not v or v.strip() == '':
            raise ValueError('Message text cannot be empty or whitespace')
        return v.strip()
    
    @validator('room_id')
    def room_id_valid(cls, v):
        """Validate room_id format."""
        if not v or v.strip() == '':
            raise ValueError('Room ID cannot be empty')
        return v.strip()
    
    @validator('timestamp', pre=True, always=True)
    def set_timestamp(cls, v):
        """Ensure timestamp is set and in valid format."""
        if v is None:
            return datetime.utcnow()
        if isinstance(v, str):
            try:
                return datetime.fromisoformat(v.replace('Z', '+00:00'))
            except ValueError:
                return datetime.utcnow()
        return v


class MessageOut(BaseModel):
    """
    Message schema for outgoing WebSocket messages.
    
    Response format that includes metadata.
    """
    
    type: str = Field(description="Message type")
    room_id: str = Field(description="Chat room ID")
    user_id: int = Field(description="User ID who sent the message")
    username: str = Field(description="Username who sent the message")
    text: str = Field(description="Message content")
    message_id: str = Field(description="Unique message identifier")
    timestamp: datetime = Field(description="Message timestamp")
    
    class Config:
        json_schema_extra = {
            "example": {
                "type": "text_message",
                "room_id": "room-123",
                "user_id": 1,
                "username": "john",
                "text": "Hello everyone!",
                "message_id": "room-123_1_1704067200.123",
                "timestamp": "2024-01-01T12:00:00"
            }
        }


class TypingIndicator(BaseModel):
    """
    Schema for typing indicator messages.
    """
    
    type: Literal["typing", "stop_typing"] = Field(description="Typing event type")
    room_id: str = Field(description="Chat room ID")
    user_id: int = Field(description="User ID typing")
    username: str = Field(description="Username typing")
    timestamp: Optional[datetime] = Field(
        default_factory=datetime.utcnow,
        description="Event timestamp"
    )
    
    class Config:
        json_schema_extra = {
            "example": {
                "type": "typing",
                "room_id": "room-123",
                "user_id": 1,
                "username": "john",
                "timestamp": "2024-01-01T12:00:00"
            }
        }


class AIRequest(BaseModel):
    """
    Schema for AI request messages.
    """
    
    type: Literal["ai_request"] = Field(default="ai_request")
    room_id: str = Field(description="Chat room ID")
    text: str = Field(..., min_length=1, max_length=5000, description="Question for AI")
    timestamp: Optional[datetime] = Field(
        default_factory=datetime.utcnow,
        description="Request timestamp"
    )
    
    class Config:
        json_schema_extra = {
            "example": {
                "type": "ai_request",
                "room_id": "room-123",
                "text": "What is the weather like?",
                "timestamp": "2024-01-01T12:00:00"
            }
        }


class AIResponse(BaseModel):
    """
    Schema for AI response messages.
    """
    
    type: Literal["ai_response"] = Field(default="ai_response")
    room_id: str = Field(description="Chat room ID")
    text: str = Field(description="AI response text")
    message_id: str = Field(description="Unique message identifier")
    timestamp: datetime = Field(description="Response timestamp")
    
    class Config:
        json_schema_extra = {
            "example": {
                "type": "ai_response",
                "room_id": "room-123",
                "text": "The weather is sunny today.",
                "message_id": "room-123_ai_1704067200.123",
                "timestamp": "2024-01-01T12:00:00"
            }
        }


class ErrorMessage(BaseModel):
    """
    Schema for error messages.
    """
    
    type: Literal["error"] = Field(default="error")
    message: str = Field(description="Error message")
    error_code: Optional[str] = Field(default=None, description="Error code")
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        json_schema_extra = {
            "example": {
                "type": "error",
                "message": "Invalid message format",
                "error_code": "INVALID_MESSAGE",
                "timestamp": "2024-01-01T12:00:00"
            }
        }


class RoomUsersUpdate(BaseModel):
    """
    Schema for room users update message.
    """
    
    type: Literal["room_users"] = Field(default="room_users")
    room_id: str = Field(description="Chat room ID")
    users: list = Field(description="List of users in room")
    users_count: int = Field(description="Total users in room")
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        json_schema_extra = {
            "example": {
                "type": "room_users",
                "room_id": "room-123",
                "users": [
                    {"user_id": 1, "username": "john"},
                    {"user_id": 2, "username": "jane"}
                ],
                "users_count": 2,
                "timestamp": "2024-01-01T12:00:00"
            }
        }


class UserJoinedEvent(BaseModel):
    """
    Schema for user joined event.
    """
    
    type: Literal["user_joined"] = Field(default="user_joined")
    user_id: int = Field(description="User ID")
    username: str = Field(description="Username")
    email: Optional[str] = Field(default=None)
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        json_schema_extra = {
            "example": {
                "type": "user_joined",
                "user_id": 1,
                "username": "john",
                "email": "john@example.com",
                "timestamp": "2024-01-01T12:00:00"
            }
        }


class UserLeftEvent(BaseModel):
    """
    Schema for user left event.
    """
    
    type: Literal["user_left"] = Field(default="user_left")
    user_id: int = Field(description="User ID")
    username: str = Field(description="Username")
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        json_schema_extra = {
            "example": {
                "type": "user_left",
                "user_id": 1,
                "username": "john",
                "timestamp": "2024-01-01T12:00:00"
            }
        }


class FriendRequestOut(BaseModel):
    """Schema for outgoing friend request data."""
    id: int
    from_user_id: int
    from_username: str
    to_user_id: int
    to_username: str
    status: str
    created_at: datetime
    responded_at: Optional[datetime] = None

    class Config:
        orm_mode = True


# Discriminated union for all message types
from typing import Union, Annotated
from pydantic import Discriminator

MessageType = Annotated[
    Union[
        MessageOut,
        AIResponse,
        TypingIndicator,
        ErrorMessage,
        RoomUsersUpdate,
        UserJoinedEvent,
        UserLeftEvent,
        FriendRequestOut
    ],
    Discriminator('type')
]
