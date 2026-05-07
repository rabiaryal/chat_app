import json
import uuid
from urllib.parse import parse_qs

from asgiref.sync import sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer

from .models import ChatRoom, CustomUser, Message


class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.room_id = self.scope["url_route"]["kwargs"]["room_id"]
        self.group_name = f"chat_{self.room_id}"

        user = await self._authenticate_user_from_query()
        if user is None:
            await self.close(code=4001)
            return

        is_member = await self._is_room_member(user.id, self.room_id)
        if not is_member:
            await self.close(code=4003)
            return

        self.user = user

        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

        await self.channel_layer.group_send(
            self.group_name,
            {
                "type": "chat.event",
                "payload": {
                    "type": "user_joined",
                    "user_id": self.user.id,
                    "username": self.user.username,
                },
            },
        )

    async def disconnect(self, close_code):
        if hasattr(self, "group_name"):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

        if hasattr(self, "user"):
            await self.channel_layer.group_send(
                self.group_name,
                {
                    "type": "chat.event",
                    "payload": {
                        "type": "user_left",
                        "user_id": self.user.id,
                        "username": self.user.username,
                    },
                },
            )

    async def receive(self, text_data=None, bytes_data=None):
        if not text_data:
            return

        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            await self.send(
                text_data=json.dumps(
                    {
                        "type": "error",
                        "message": "Invalid JSON format",
                        "error_code": "INVALID_JSON",
                    }
                )
            )
            return

        msg_type = data.get("type", "text_message")

        if msg_type in ["typing", "stop_typing"]:
            await self.channel_layer.group_send(
                self.group_name,
                {
                    "type": "chat.event",
                    "payload": {
                        "type": msg_type,
                        "room_id": self.room_id,
                        "user_id": self.user.id,
                        "username": self.user.username,
                    },
                },
            )
            return

        if msg_type == "secure_message":
            # Relay the secure message payload as is
            recipient_id = data.get("recipient_id")
            encrypted_payload = data.get("encrypted_payload")
            encrypted_key = data.get("encrypted_key")
            iv = data.get("iv")

            payload = {
                "type": "secure_message",
                "room_id": self.room_id,
                "sender_id": self.user.id,
                "sender_username": self.user.username,
                "recipient_id": recipient_id,
                "encrypted_payload": encrypted_payload,
                "encrypted_key": encrypted_key,
                "iv": iv,
                "timestamp": data.get("timestamp") or uuid.uuid4().hex[:8] # Fallback
            }

            await self.channel_layer.group_send(
                self.group_name,
                {
                    "type": "chat.event",
                    "payload": payload,
                },
            )
            return

        text = (data.get("text") or data.get("content") or "").strip()
        if not text:
            await self.send(
                text_data=json.dumps(
                    {
                        "type": "error",
                        "message": "Message text cannot be empty",
                        "error_code": "VALIDATION_ERROR",
                    }
                )
            )
            return

        message_type = "AI_RESPONSE" if msg_type == "ai_request" else "TEXT"
        message_id = f"{self.room_id}_{self.user.id}_{uuid.uuid4().hex[:12]}"

        await self._save_message(self.room_id, self.user.id, text, message_type)

        payload = {
            "type": "text_message" if msg_type == "ai_request" else msg_type,
            "room_id": self.room_id,
            "user_id": self.user.id,
            "username": self.user.username,
            "text": text,
            "message_id": message_id,
        }

        await self.channel_layer.group_send(
            self.group_name,
            {
                "type": "chat.event",
                "payload": payload,
            },
        )

    async def chat_event(self, event):
        await self.send(text_data=json.dumps(event["payload"]))

    @sync_to_async
    def _authenticate_user_from_query(self):
        from rest_framework_simplejwt.tokens import AccessToken
        from rest_framework_simplejwt.exceptions import TokenError

        query_params = parse_qs(self.scope.get("query_string", b"").decode())
        token = query_params.get("token", [None])[0]
        if not token:
            return None

        try:
            payload = AccessToken(token)
        except TokenError:
            return None

        user_id = payload.get("user_id")
        if not user_id:
            return None

        try:
            return CustomUser.objects.get(id=user_id)
        except CustomUser.DoesNotExist:
            return None

    @sync_to_async
    def _is_room_member(self, user_id, room_id):
        try:
            room = ChatRoom.objects.get(id=room_id, is_active=True)
        except ChatRoom.DoesNotExist:
            return False
        return room.participants.filter(id=user_id).exists()

    @sync_to_async
    def _save_message(self, room_id, user_id, content, message_type):
        room = ChatRoom.objects.get(id=room_id)
        sender = CustomUser.objects.get(id=user_id)
        Message.objects.create(
            id=str(uuid.uuid4()),
            room=room,
            sender=sender,
            content=content,
            message_type=message_type,
        )
