# WebSocket Real-Time System

Real-time communication is handled via **Django Channels** on the backend and a persistent WebSocket connection on the frontend.

## Connection
- **Endpoint**: `ws://<host>:<port>/ws/chat/<room_id>/?token=<access_token>`
- **Management**: Handled by `ChatService` in the Flutter app.
- **Persistence**: Includes automatic reconnection logic with exponential backoff.

## Event Types

### Outbound (Client to Server)
- `text_message`: Sending a new message.
- `typing` / `stop_typing`: Notifying others of typing status.
- `mark_read`: Notifying the server that a message has been seen.
- `ai_request`: Triggering an AI assistant response (if enabled).

### Inbound (Server to Client)
- `chat_message`: Receiving a new message.
- `message_read`: Notification that a message was read by the recipient (triggers "double blue check").
- `typing` / `stop_typing`: Receiving status from others.
- `user_joined` / `user_left`: Membership updates.
- `error`: Server-side validation errors (e.g., empty message).

## Seen/Unseen Status
1. Client enters chat and sees unread messages.
2. Client sends `mark_read` event for those message IDs.
3. Server updates `is_read` in PostgreSQL and broadcasts `message_read`.
4. Sender's app receives `message_read` and updates the UI (one grey check -> two blue checks).
