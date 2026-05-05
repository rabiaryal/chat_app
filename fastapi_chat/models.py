"""
SQLAlchemy models that mirror Django models.
Used for querying in FastAPI for room membership verification.

These are read-only representations of Django models.
"""

from sqlalchemy import Column, String, Integer, Boolean, DateTime, ForeignKey, Table
from sqlalchemy.orm import relationship
from datetime import datetime
from db import Base


# Association table for M2M relationship between ChatRoom and User
chat_room_participants = Table(
    'chat_app_chatroom_participants',
    Base.metadata,
    Column('chatroom_id', String(36), ForeignKey('chat_app_chatroom.id'), primary_key=True),
    Column('customuser_id', Integer, ForeignKey('auth_user.id'), primary_key=True),
    schema='public'
)


class CustomUser(Base):
    """Mirror of Django CustomUser model (extends AbstractUser)."""
    __tablename__ = 'auth_user'
    __table_args__ = {'schema': 'public'}
    
    id = Column(Integer, primary_key=True)
    username = Column(String(150), unique=True, nullable=False)
    email = Column(String(254), nullable=False)
    first_name = Column(String(150), default='')
    last_name = Column(String(150), default='')
    is_active = Column(Boolean, default=True)
    is_staff = Column(Boolean, default=False)
    is_superuser = Column(Boolean, default=False)
    last_login = Column(DateTime(timezone=True), nullable=True)
    date_joined = Column(DateTime(timezone=True), default=datetime.utcnow)
    
    # Custom fields from CustomUser
    phone_number = Column(String(20), nullable=True)
    avatar = Column(String(255), nullable=True)
    bio = Column(String(500), nullable=True)
    is_online = Column(Boolean, default=False)
    last_seen = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    
    # Relationships
    chat_rooms = relationship(
        'ChatRoom',
        secondary=chat_room_participants,
        lazy='selectin',
        back_populates='participants'
    )
    
    def __repr__(self):
        return f"<CustomUser(id={self.id}, username={self.username})>"


class ChatRoom(Base):
    """Mirror of Django ChatRoom model."""
    __tablename__ = 'chat_app_chatroom'
    __table_args__ = {'schema': 'public'}
    
    id = Column(String(36), primary_key=True)
    name = Column(String(255), nullable=False)
    description = Column(String, nullable=True)
    room_type = Column(String(10), default='DM')  # 'DM' or 'GROUP'
    creator_id = Column(Integer, ForeignKey('auth_user.id'), nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    
    # Relationships
    participants = relationship(
        'CustomUser',
        secondary=chat_room_participants,
        lazy='selectin',
        back_populates='chat_rooms'
    )
    
    messages = relationship(
        'Message',
        lazy='selectin',
        back_populates='room'
    )
    
    def __repr__(self):
        return f"<ChatRoom(id={self.id}, name={self.name}, type={self.room_type})>"


class Message(Base):
    """Mirror of Django Message model."""
    __tablename__ = 'chat_app_message'
    __table_args__ = {'schema': 'public'}
    
    id = Column(String(36), primary_key=True)
    room_id = Column(String(36), ForeignKey('chat_app_chatroom.id'), nullable=False)
    sender_id = Column(Integer, ForeignKey('auth_user.id'), nullable=False)
    content = Column(String, nullable=False)
    message_type = Column(String(20), default='TEXT')  # TEXT, IMAGE, FILE, AI_RESPONSE
    file = Column(String(255), nullable=True)  # File path if any
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    
    # Relationships
    room = relationship(
        'ChatRoom',
        lazy='selectin',
        back_populates='messages'
    )
    
    def __repr__(self):
        return f"<Message(id={self.id}, room_id={self.room_id})>"


class AIResponse(Base):
    """Mirror of Django AIResponse model."""
    __tablename__ = 'chat_app_airesponse'
    __table_args__ = {'schema': 'public'}
    
    id = Column(String(36), primary_key=True)
    message_id = Column(String(36), ForeignKey('chat_app_message.id'), unique=True)
    prompt = Column(String, nullable=False)
    response_text = Column(String, nullable=False)
    model_used = Column(String(50), default='gpt-3.5-turbo')
    tokens_used = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    
    def __repr__(self):
        return f"<AIResponse(id={self.id}, model={self.model_used})>"


class FriendRequest(Base):
    """Mirror of Django FriendRequest model."""
    __tablename__ = 'chat_app_friendrequest'
    __table_args__ = {'schema': 'public'}

    id = Column(Integer, primary_key=True)
    from_user_id = Column(Integer, ForeignKey('auth_user.id'), nullable=False)
    to_user_id = Column(Integer, ForeignKey('auth_user.id'), nullable=False)
    status = Column(String(20), default='PENDING')  # PENDING, ACCEPTED, REJECTED
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    responded_at = Column(DateTime(timezone=True), nullable=True)

    from_user = relationship("CustomUser", foreign_keys=[from_user_id])
    to_user = relationship("CustomUser", foreign_keys=[to_user_id])

    def __repr__(self):
        return f"<FriendRequest(from={self.from_user_id}, to={self.to_user_id}, status={self.status})>"
