"""
AI Chatbot utilities and response generation.
"""

import asyncio
from typing import AsyncGenerator
import json
from datetime import datetime


class AIChat:
    """AI Chatbot response handler with async streaming."""
    
    @staticmethod
    async def generate_response(
        user_message: str,
        user_id: int,
        room_id: str,
        model: str = "gpt-3.5-turbo"
    ) -> AsyncGenerator[str, None]:
        """
        Generate AI chatbot response with streaming.
        
        This is a placeholder implementation. In production, replace with actual
        AI service calls (OpenAI, Cohere, Anthropic, etc.).
        
        Args:
            user_message: The user's message
            user_id: ID of the user sending the message
            room_id: ID of the chat room
            model: AI model to use
            
        Yields:
            Streamed response chunks
        """
        # Placeholder: Simulate streaming response
        response_text = f"AI Echo: {user_message}"
        words = response_text.split()
        
        for word in words:
            yield json.dumps({
                "type": "ai_response_chunk",
                "content": word + " ",
                "timestamp": datetime.utcnow().isoformat(),
                "model": model
            }) + "\n"
            # Simulate network latency
            await asyncio.sleep(0.1)
        
        yield json.dumps({
            "type": "ai_response_complete",
            "total_tokens": len(response_text.split()),
            "timestamp": datetime.utcnow().isoformat()
        }) + "\n"
    
    @staticmethod
    async def generate_response_complete(
        user_message: str,
        user_id: int,
        room_id: str,
        model: str = "gpt-3.5-turbo"
    ) -> dict:
        """
        Generate complete AI response (non-streaming).
        
        Args:
            user_message: The user's message
            user_id: ID of the user sending the message
            room_id: ID of the chat room
            model: AI model to use
            
        Returns:
            Dictionary containing the response
        """
        # Placeholder: Return a simple echo response
        response_text = f"AI Response to: {user_message}"
        
        return {
            "response_text": response_text,
            "model_used": model,
            "tokens_used": len(response_text.split()),
            "timestamp": datetime.utcnow().isoformat()
        }
    
    @staticmethod
    def process_message_for_ai(message: str, user_profile: dict) -> str:
        """
        Process user message before sending to AI service.
        
        Args:
            message: Raw user message
            user_profile: User profile information
            
        Returns:
            Processed message ready for AI
        """
        # Add user context, clean up formatting, etc.
        processed = message.strip()
        return processed
    
    @staticmethod
    def format_response(raw_response: str) -> str:
        """
        Format AI response for display.
        
        Args:
            raw_response: Raw response from AI service
            
        Returns:
            Formatted response
        """
        # Add formatting, markdown processing, etc.
        return raw_response.strip()


class ConversationContext:
    """Manage conversation context for better AI responses."""
    
    def __init__(self, max_messages: int = 10):
        """
        Initialize conversation context manager.
        
        Args:
            max_messages: Maximum number of messages to keep in context
        """
        self.max_messages = max_messages
        self.messages = []
    
    def add_message(self, role: str, content: str, user_id: int = None):
        """
        Add a message to the context.
        
        Args:
            role: 'user' or 'assistant'
            content: Message content
            user_id: Optional user ID
        """
        self.messages.append({
            "role": role,
            "content": content,
            "user_id": user_id,
            "timestamp": datetime.utcnow().isoformat()
        })
        
        # Keep only recent messages
        if len(self.messages) > self.max_messages:
            self.messages = self.messages[-self.max_messages:]
    
    def get_context(self) -> list:
        """Get the current conversation context."""
        return self.messages
    
    def clear(self):
        """Clear the conversation context."""
        self.messages = []
