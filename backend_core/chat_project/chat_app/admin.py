"""
Admin configuration for chat_app.
"""

from django.contrib import admin
from .models import CustomUser, ChatRoom, Message, AIResponse


@admin.register(CustomUser)
class CustomUserAdmin(admin.ModelAdmin):
    list_display = ('username', 'email', 'is_online', 'created_at')
    search_fields = ('username', 'email')
    list_filter = ('is_online', 'created_at')
    readonly_fields = ('created_at', 'updated_at', 'last_seen')


@admin.register(ChatRoom)
class ChatRoomAdmin(admin.ModelAdmin):
    list_display = ('name', 'room_type', 'creator', 'is_active', 'created_at')
    search_fields = ('name', 'creator__username')
    list_filter = ('room_type', 'is_active', 'created_at')
    readonly_fields = ('created_at', 'updated_at')


@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ('sender', 'room', 'message_type', 'is_read', 'created_at')
    search_fields = ('sender__username', 'room__name', 'content')
    list_filter = ('message_type', 'is_read', 'created_at')
    readonly_fields = ('created_at', 'updated_at')


@admin.register(AIResponse)
class AIResponseAdmin(admin.ModelAdmin):
    list_display = ('id', 'model_used', 'tokens_used', 'created_at')
    search_fields = ('message__id',)
    list_filter = ('model_used', 'created_at')
    readonly_fields = ('created_at',)
