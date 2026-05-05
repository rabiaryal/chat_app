"""
Models for the chat application.
"""

from django.db import models
from django.contrib.auth.models import AbstractUser
from django.utils.translation import gettext_lazy as _


class CustomUser(AbstractUser):
    """
    Custom user model extending Django's AbstractUser.
    """
    email = models.EmailField(_('email address'), unique=True)
    phone_number = models.CharField(max_length=20, blank=True, null=True)
    avatar = models.ImageField(upload_to='avatars/', blank=True, null=True)
    bio = models.TextField(blank=True, null=True)
    is_online = models.BooleanField(default=False)
    last_seen = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _('user')
        verbose_name_plural = _('users')

    def __str__(self):
        return f"{self.username} ({self.email})"


class ChatRoom(models.Model):
    """
    Model for chat rooms/conversations.
    """
    ROOM_TYPES = (
        ('DM', 'Direct Message'),
        ('GROUP', 'Group Chat'),
    )

    id = models.CharField(max_length=36, primary_key=True)
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    room_type = models.CharField(max_length=10, choices=ROOM_TYPES, default='DM')
    participants = models.ManyToManyField(CustomUser, related_name='chat_rooms')
    creator = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='created_rooms')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-updated_at']

    def __str__(self):
        return f"{self.name} ({self.room_type})"


class Message(models.Model):
    """
    Model for individual messages in chat rooms.
    """
    MESSAGE_TYPES = (
        ('TEXT', 'Text Message'),
        ('IMAGE', 'Image'),
        ('FILE', 'File'),
        ('AI_RESPONSE', 'AI Response'),
    )

    id = models.CharField(max_length=36, primary_key=True)
    room = models.ForeignKey(ChatRoom, on_delete=models.CASCADE, related_name='messages')
    sender = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='sent_messages')
    content = models.TextField()
    message_type = models.CharField(max_length=20, choices=MESSAGE_TYPES, default='TEXT')
    file = models.FileField(upload_to='messages/', blank=True, null=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f"Message from {self.sender} in {self.room}"


class Friendship(models.Model):
    """
    Model for managing friendship requests and relationships between users.
    Implements a Request → Accept → Chat flow.
    """
    STATUS_CHOICES = (
        ('PENDING', 'Pending'),
        ('ACCEPTED', 'Accepted'),
        ('BLOCKED', 'Blocked'),
        ('REJECTED', 'Rejected'),
    )

    from_user = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name='friendship_requests_sent'
    )
    to_user = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name='friendship_requests_received'
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('from_user', 'to_user')
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.from_user} → {self.to_user} ({self.status})"


class AIResponse(models.Model):
    """
    Model for storing AI chatbot responses.
    """
    id = models.CharField(max_length=36, primary_key=True)
    message = models.OneToOneField(Message, on_delete=models.CASCADE, related_name='ai_response')
    prompt = models.TextField()
    response_text = models.TextField()
    model_used = models.CharField(max_length=50, default='gpt-3.5-turbo')
    tokens_used = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"AI Response to message {self.message.id}"
