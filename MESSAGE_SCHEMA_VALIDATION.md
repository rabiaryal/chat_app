# FastAPI Message Schema Validation

## Overview

This document describes the **Message Schema Validation** system implemented for the FastAPI WebSocket server. All incoming WebSocket messages are validated using Pydantic models to ensure data integrity, consistency, and type safety.

**Key Benefits:**
- ✅ Type-safe message handling with Pydantic validation
- ✅ Clear error reporting with validation failure reasons
- ✅ Automatic data serialization to JSON
- ✅ Discriminated union types for different message kinds
- ✅ Timestamp auto-generation and normalization
- ✅ Request/response schema consistency

---

## Architecture

### Files

```
fastapi_chat/
├── schemas.py          # Pydantic models and validators
├── main.py            # WebSocket endpoint using schemas
├── config.py          # Configuration
└── requirements.txt   # Dependencies (includes pydantic==2.5.0)
```

### Schema Structure

```
Incoming Messages (MessageIn)
    ├── text: str                    # Message content (1-5000 chars)
    ├── room_id: str                 # Chat room identifier
    ├── type: Literal[...]           # Message type
    └── timestamp: Optional[datetime] # Auto-generated if missing

Outgoing Messages (MessageOut + others)
    ├── User Message (text_message)
    ├── AI Response (ai_response)
    ├── Typing Indicator (typing/stop_typing)
    ├── Join/Leave Events
    └── Error Messages
```

---

## Pydantic Models (schemas.py)

### 1. **MessageIn** - Incoming Message Validation

**Purpose:** Validates all incoming WebSocket messages

**Fields:**
```python
class MessageIn(BaseModel):
    text: str                                              # Min 1, Max 5000
    room_id: str                                           # Non-empty
    type: Literal["text_message", "ai_request", 
                  "typing", "stop_typing"]                # One of these types
    timestamp: Optional[datetime]                         # Auto-UTC if None
```

**Validators:**
- `text_not_empty()`: Strips whitespace, rejects empty strings
- `room_id_valid()`: Ensures room_id is non-empty
- `set_timestamp()`: Auto-generates UTC timestamp if missing

**Example:**
```json
{
  "text": "Hello everyone!",
  "room_id": "room-123",
  "type": "text_message",
  "timestamp": "2024-01-01T12:00:00"
}
```

---

### 2. **MessageOut** - Outgoing Message Response

**Purpose:** Validated response format for text messages

**Fields:**
```python
class MessageOut(BaseModel):
    type: str                    # Message type identifier
    room_id: str                 # Chat room identifier
    user_id: int                 # Sender user ID
    username: str                # Sender username
    text: str                    # Message content
    message_id: str              # Unique message identifier
    timestamp: datetime          # Message timestamp
```

**Example Response:**
```json
{
  "type": "text_message",
  "room_id": "room-123",
  "user_id": 1,
  "username": "john",
  "text": "Hello everyone!",
  "message_id": "room-123_1_1704067200.123",
  "timestamp": "2024-01-01T12:00:00"
}
```

---

### 3. **TypingIndicator** - Typing Status

**Purpose:** Notifies users when someone is typing

**Fields:**
```python
class TypingIndicator(BaseModel):
    type: Literal["typing", "stop_typing"]
    room_id: str                 # Chat room identifier
    user_id: int                 # User typing
    username: str                # Username typing
    timestamp: Optional[datetime] # Auto-generated if None
```

**Example:**
```json
{
  "type": "typing",
  "room_id": "room-123",
  "user_id": 1,
  "username": "john",
  "timestamp": "2024-01-01T12:00:00"
}
```

---

### 4. **AIRequest** - AI Assistance Request

**Purpose:** Request AI response in chat room

**Fields:**
```python
class AIRequest(BaseModel):
    type: Literal["ai_request"]   # Fixed type
    room_id: str                  # Chat room identifier
    text: str                     # Question for AI (1-5000 chars)
    timestamp: Optional[datetime] # Auto-generated if None
```

**Example:**
```json
{
  "type": "ai_request",
  "room_id": "room-123",
  "text": "What is the weather like?",
  "timestamp": "2024-01-01T12:00:00"
}
```

---

### 5. **AIResponse** - AI Assistant Response

**Purpose:** Validated response format for AI replies

**Fields:**
```python
class AIResponse(BaseModel):
    type: Literal["ai_response"]  # Fixed type
    room_id: str                  # Chat room identifier
    text: str                     # AI response text
    message_id: str               # Unique message identifier
    timestamp: datetime           # Response timestamp
```

**Example:**
```json
{
  "type": "ai_response",
  "room_id": "room-123",
  "text": "The weather is sunny today.",
  "message_id": "room-123_ai_1704067200.123",
  "timestamp": "2024-01-01T12:00:00"
}
```

---

### 6. **ErrorMessage** - Error Response

**Purpose:** Communicate validation and runtime errors

**Fields:**
```python
class ErrorMessage(BaseModel):
    type: Literal["error"]                # Fixed type
    message: str                          # Error description
    error_code: Optional[str]             # Error code (e.g., "INVALID_JSON")
    timestamp: datetime                   # Error timestamp
```

**Example:**
```json
{
  "type": "error",
  "message": "Message validation failed: 1 error(s)",
  "error_code": "VALIDATION_ERROR",
  "timestamp": "2024-01-01T12:00:00"
}
```

**Common Error Codes:**
- `INVALID_JSON` - Request body is not valid JSON
- `VALIDATION_ERROR` - Message fields fail validation
- `AI_RESPONSE_ERROR` - AI generation failed
- `MISSING_TOKEN` - JWT token not provided
- `INVALID_TOKEN` - JWT token invalid or expired

---

### 7. **RoomUsersUpdate** - Room User List

**Purpose:** Notifies client of users in room

**Fields:**
```python
class RoomUsersUpdate(BaseModel):
    type: Literal["room_users"]  # Fixed type
    room_id: str                 # Chat room identifier
    users: list                  # List of user dicts
    users_count: int             # Total users in room
    timestamp: datetime          # Update timestamp
```

**Example:**
```json
{
  "type": "room_users",
  "room_id": "room-123",
  "users": [
    {"user_id": 1, "username": "john"},
    {"user_id": 2, "username": "jane"}
  ],
  "users_count": 2,
  "timestamp": "2024-01-01T12:00:00"
}
```

---

### 8. **UserJoinedEvent** - User Joined Room

**Purpose:** Notifies when user joins chat room

**Fields:**
```python
class UserJoinedEvent(BaseModel):
    type: Literal["user_joined"]  # Fixed type
    user_id: int                  # User who joined
    username: str                 # Username
    email: Optional[str]          # User email
    timestamp: datetime           # Join timestamp
```

---

### 9. **UserLeftEvent** - User Left Room

**Purpose:** Notifies when user leaves chat room

**Fields:**
```python
class UserLeftEvent(BaseModel):
    type: Literal["user_left"]   # Fixed type
    user_id: int                 # User who left
    username: str                # Username
    timestamp: datetime          # Leave timestamp
```

---

## Validation Flow in WebSocket Endpoint

### Step 1: Receive Raw Message
```python
data = await websocket.receive_text()
```

### Step 2: Parse JSON
```python
try:
    message_data = json.loads(data)
except json.JSONDecodeError as e:
    # Return INVALID_JSON error
    error_response = ErrorMessage(
        message="Invalid JSON format",
        error_code="INVALID_JSON"
    )
    await manager.send_personal(websocket, error_response.dict())
    continue
```

### Step 3: Validate with Pydantic MessageIn
```python
try:
    validated_message = MessageIn(
        text=message_data.get('text', ''),
        room_id=room_id,
        type=message_type,
        timestamp=message_data.get('timestamp')
    )
    logger.info(f"✓ Message validated from @{username}")
except ValidationError as e:
    # Return VALIDATION_ERROR with details
    error_response = ErrorMessage(
        message=f"Message validation failed: {e.error_count()} error(s)",
        error_code="VALIDATION_ERROR"
    )
    await manager.send_personal(websocket, error_response.dict())
    logger.warning(f"Validation error: {e.json()[:200]}")
    continue
```

### Step 4: Process Valid Message
```python
if validated_message.type == 'text_message':
    await handle_text_message(
        manager, room_id, user_id, username,
        validated_message.text,
        validated_message.timestamp
    )
```

### Step 5: Return Validated Response
Messages are converted to response models and broadcasted:
```python
message = MessageOut(
    type="text_message",
    room_id=room_id,
    user_id=user_id,
    username=username,
    text=content,
    message_id=message_id,
    timestamp=timestamp
)

# Broadcast as dict
await manager.broadcast_to_room(room_id, message.dict())
```

---

## Implementation in main.py

### Import Schemas
```python
from schemas import (
    MessageIn, MessageOut, TypingIndicator, AIRequest, AIResponse,
    ErrorMessage, RoomUsersUpdate, UserJoinedEvent, UserLeftEvent
)
from pydantic import ValidationError
```

### Updated WebSocket Endpoint
The WebSocket endpoint now:
1. Validates all incoming messages with `MessageIn`
2. Returns typed error messages with `ErrorMessage`
3. Sends validated responses as `MessageOut`, `AIResponse`, `TypingIndicator`, etc.
4. Logs validation errors for debugging

### Updated Message Handlers
- `handle_text_message()`: Creates `MessageOut` response
- `handle_ai_request()`: Creates `AIResponse` response
- Disconnect handler: Creates `UserLeftEvent` message

---

## Type Safety Benefits

### Before (Raw Dictionaries)
```python
# Untyped dictionary - no validation
message = {
    "type": "text_message",
    "room_id": room_id,
    "user_id": user_id,
    "username": username,
    "content": content,  # Field name inconsistency!
    "message_id": message_id,
    "timestamp": datetime.utcnow().isoformat()
}
# ❌ Easy to miss errors, no IDE autocompletion
```

### After (Pydantic Models)
```python
# Typed and validated
message = MessageOut(
    type="text_message",
    room_id=room_id,
    user_id=user_id,
    username=username,
    text=content,  # Type-checked field name
    message_id=message_id,
    timestamp=timestamp
)
# ✅ IDE autocomplete, type checking, validation
```

---

## Error Handling Examples

### Scenario 1: Empty Message
**Incoming:**
```json
{
  "text": "",
  "room_id": "room-123",
  "type": "text_message"
}
```

**Validation Error:**
```
ValidationError: text
  string should have at least 1 character [type=string_too_short, input_value='', input_type=str]
```

**Response Sent to Client:**
```json
{
  "type": "error",
  "message": "Message validation failed: 1 error(s)",
  "error_code": "VALIDATION_ERROR",
  "timestamp": "2024-01-01T12:00:00"
}
```

### Scenario 2: Text Too Long
**Incoming:**
```json
{
  "text": "[10,000 character string]",
  "room_id": "room-123",
  "type": "text_message"
}
```

**Validation Error:**
```
ValidationError: text
  String should have at most 5000 characters [type=string_too_long]
```

### Scenario 3: Invalid JSON
**Incoming:**
```
{invalid json}
```

**Response Sent to Client:**
```json
{
  "type": "error",
  "message": "Invalid JSON format",
  "error_code": "INVALID_JSON",
  "timestamp": "2024-01-01T12:00:00"
}
```

---

## Testing the Schema Validation

### Test Case 1: Valid Message
```bash
# Send via WebSocket
{
  "text": "Hello world!",
  "room_id": "room-123",
  "type": "text_message"
}

# Expected Response
{
  "type": "text_message",
  "room_id": "room-123",
  "user_id": 1,
  "username": "john",
  "text": "Hello world!",
  "message_id": "room-123_1_1704067200.123",
  "timestamp": "2024-01-01T12:00:00"
}
```

### Test Case 2: Invalid Message (Empty Text)
```bash
# Send via WebSocket
{
  "text": "   ",
  "room_id": "room-123",
  "type": "text_message"
}

# Expected Response
{
  "type": "error",
  "message": "Message validation failed: 1 error(s)",
  "error_code": "VALIDATION_ERROR",
  "timestamp": "2024-01-01T12:00:00"
}
```

### Test Case 3: Auto-Generate Timestamp
```bash
# Send via WebSocket (no timestamp)
{
  "text": "Hello!",
  "room_id": "room-123",
  "type": "text_message"
}

# Expected Response (timestamp auto-generated)
{
  "type": "text_message",
  "room_id": "room-123",
  "user_id": 1,
  "username": "john",
  "text": "Hello!",
  "message_id": "room-123_1_1704067200.123",
  "timestamp": "2024-01-01T12:00:15"  # Auto-generated
}
```

---

## Logging

Validation events are logged with clear status indicators:

```log
✓ Message validated from @john (text_message): Hello everyone!...
✗ Validation error from alice: {"text": "string should have at least 1 character"}
✗ Invalid JSON from bob: Expecting value: line 1 column 1 (char 0)
✓ Published to Redis room:room-123 by @john (ID: room-123_1_1704067200.123)
```

---

## Production Considerations

### 1. **Message Size Limits**
- Max text length: 5,000 characters
- Adjust `max_length` parameter in `MessageIn` model if needed

### 2. **Timestamp Handling**
- Client timestamps are accepted but validated
- Server always uses UTC for consistency
- Automatic timezone handling via Pydantic

### 3. **Error Code Documentation**
Maintain a registry of error codes for client developers:
- `INVALID_JSON` - Client sent malformed JSON
- `VALIDATION_ERROR` - Message fields failed validation
- `AI_RESPONSE_ERROR` - AI service unavailable
- `UNAUTHORIZED` - JWT token invalid

### 4. **Monitoring**
Track validation metrics:
- Invalid messages per user
- Validation error types (top 5)
- Average validation time

### 5. **API Documentation**
Include schema examples in OpenAPI docs:
```python
@app.websocket("/ws/chat/{room_id}")
async def websocket_endpoint(websocket: WebSocket, room_id: str, token: str = Query(...)):
    """
    WebSocket endpoint with schema validation.
    
    Incoming: Validate with MessageIn
    Outgoing: Return MessageOut, AIResponse, ErrorMessage, etc.
    """
```

---

## Future Enhancements

1. **Extended Validators**
   - Profanity filtering
   - Link detection
   - Emoji validation

2. **Custom Error Messages**
   - Localized error messages
   - User-friendly validation feedback

3. **Rate Limiting**
   - Per-user message rate limits
   - Per-room rate limits

4. **Message Encryption**
   - End-to-end encryption using schema
   - Signed message verification

5. **Message Versioning**
   - Schema versioning support
   - Backward compatibility handling

---

## Summary

The **Message Schema Validation** system provides:

✅ **Type Safety** through Pydantic models (MessageIn, MessageOut, etc.)
✅ **Validation** with custom validators (text_not_empty, room_id_valid)
✅ **Error Handling** with clear error codes and messages
✅ **Timestamp Management** with automatic UTC generation
✅ **Serialization** to JSON for WebSocket broadcasting
✅ **Logging** with status indicators for debugging
✅ **IDE Support** with autocomplete and type checking

This ensures all messages flowing through the chat application maintain strict data integrity and consistency across the entire system.
