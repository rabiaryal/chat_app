# 💬 Chat Application - Hybrid Backend (Django + FastAPI + Flutter)
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
A **production-ready** full-stack chat application with:
- **Django REST API** (Port 8000) - User authentication, JWT tokens, REST endpoints
- **FastAPI WebSocket Service** (Port 8081) - Real-time chat, AI responses, streaming
- **Flutter Mobile/Web Client** - Cross-platform UI with authentication & chat
- **PostgreSQL + Redis** - Persistent storage and caching

## 🎯 Key Highlights

✅ **Centralized JWT Authentication** - Django issues, FastAPI validates with shared SECRET_KEY  
✅ **Real-Time WebSocket Chat** - Async streaming, AI responses, connection management  
✅ **Production Docker Setup** - Fully orchestrated with health checks & auto-restart  
✅ **Scalable Architecture** - Separate services, easy to scale horizontally  
✅ **AI Chatbot Ready** - Streaming responses compatible with OpenAI, Cohere, Anthropic  

---

## 🚀 Quick Start (5 Minutes)

```bash
# 1. Navigate to project
cd /Applications/development/flutter_dev/chat_app

# 2. Create environment file
cp .env.example .env

# 3. Generate SECRET_KEY (recommended)
openssl rand -hex 32 | xargs echo SECRET_KEY= >> .env

# 4. Start all services
docker-compose up -d

# 5. Access services
# - Django: http://localhost:8000/api/v1/auth/login/
# - Admin: http://localhost:8000/admin
# - FastAPI: ws://localhost:8081/ws/chat/{room_id}?token=...
```

**See [QUICKSTART.md](QUICKSTART.md) for detailed setup instructions.**

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 Flutter Client App                           │
│         (Login → Create Room → Real-time Chat)               │
└────────┬─────────────────────────────────┬──────────────────┘
         │                                 │
    REST API (Auth)              WebSocket (Real-time Chat)
         │                                 │
    HTTP POST                           WS://
         │                                 │
┌────────▼─────────┐            ┌─────────▼────────────┐
│  Django 8000     │            │  FastAPI 8081        │
├──────────────────┤            ├──────────────────────┤
│ - Register/Login │            │ - WebSocket Endpoint │
│ - JWT Issuance   │            │ - Message Broadcast  │
│ - User Profiles  │            │ - AI Responses       │
│ - Chat Rooms     │            │ - Typing Indicators  │
└────────┬──────────┘            └──────────┬───────────┘
         │                                 │
         └──────────┬──────────────────────┘
                    │
            Shared JWT Validation
                    │
        ┌───────────▼─────────────┐
        │  PostgreSQL Database    │
        │  - Users               │
        │  - Rooms               │
        │  - Messages            │
        └────────────────────────┘
                    │
        ┌───────────▼─────────────┐
        │   Redis Cache           │
        │  - Sessions             │
        │  - Temp Data            │
        └────────────────────────┘
```

---

## 📁 Project Structure

```
chat_app/
├── docker-compose.yml              # Service orchestration
├── .env.example                    # Configuration template
├── init-db.sql                     # Database initialization
│
├── backend_core/                   # Django Backend (Port 8000)
│   ├── Dockerfile
│   ├── requirements.txt
│   └── chat_project/
│       ├── manage.py
│       ├── chat_project/           # Django project settings
│       │   ├── settings.py         # JWT, DB, middleware config
│       │   ├── urls.py
│       │   └── wsgi.py
│       └── chat_app/               # Main app
│           ├── models.py           # User, ChatRoom, Message
│           ├── serializers.py      # DRF serializers
│           ├── views.py            # REST endpoints
│           └── urls.py
│
├── fastapi_chat/                   # FastAPI Backend (Port 8081)
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── main.py                     # WebSocket app & endpoints
│   ├── config.py                   # Settings & environment
│   ├── jwt_utils.py                # JWT validation
│   └── ai_utils.py                 # AI response generation
│
├── flutter/lib/services/           # Flutter Client Services
│   ├── api_service.dart            # HTTP client for Django
│   ├── websocket_service.dart      # WebSocket client for FastAPI
│   └── chat_service_example.dart   # Integration examples
│
├── QUICKSTART.md                   # 5-minute setup guide
├── IMPLEMENTATION_GUIDE.md         # Complete documentation
├── DJANGO_GUIDE.md                 # Django backend details
├── FASTAPI_GUIDE.md                # FastAPI backend details
└── FLUTTER_GUIDE.md                # Flutter integration guide
```

---

## 🔐 Authentication Flow

### User Registration & Login

```
User → POST /api/v1/auth/register/
Django → Creates CustomUser
       → Returns user data

User → POST /api/v1/auth/login/
Django → Validates credentials
       → Issues JWT tokens (access + refresh)
       → Returns {access, refresh, user_id, username}
```

### WebSocket Connection with JWT

```
Flutter → Extracts access token from local storage
        → Connects to ws://localhost:8081/ws/chat/{room_id}?token={JWT}

FastAPI → Receives WebSocket connection
        → Decodes JWT using shared SECRET_KEY
        → Validates token expiration & signature
        → Broadcasts user as "joined" to room
        → Manages connection lifecycle
```

### Token Validation (No Database Ping-Pong!)

```
FastAPI receives JWT token
        ↓
Decodes using settings.SECRET_KEY (same as Django)
        ↓
Extracts user info: user_id, username, email
        ↓
No database lookup needed! (Stateless)
        ↓
Token expires automatically based on 'exp' claim
```

---

## 🔄 Real-Time Chat Flow

### Sending a Message

```
User types message in Flutter app
        ↓
WebSocket client sends: {"type": "text_message", "content": "..."}
        ↓
FastAPI receives, validates user
        ↓
Broadcasts to all users in room
        ↓
All connected clients receive message
        ↓
Message saved to PostgreSQL (optional)
        ↓
Conversation context updated for AI
```

### AI Response Streaming

```
User sends: {"type": "ai_request", "content": "..."}
        ↓
FastAPI routes to ai_utils.generate_response()
        ↓
AI service streams response chunks
        ↓
FastAPI yields: {"type": "ai_response_chunk", "content": "word"}
        ↓
Flutter UI updates in real-time
        ↓
Final message: {"type": "ai_response_complete", "tokens": 42}
```

---

## 📚 Documentation

### Backend & General
- **[QUICKSTART.md](QUICKSTART.md)** - Get entire system running in 5 minutes
- **[IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)** - Complete system overview
- **[DJANGO_GUIDE.md](DJANGO_GUIDE.md)** - Backend REST API details
- **[FASTAPI_GUIDE.md](FASTAPI_GUIDE.md)** - WebSocket & real-time guide
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture deep dive

### Flutter Client (New!)
- **[QUICKSTART_FLUTTER.md](QUICKSTART_FLUTTER.md)** - Get Flutter app running in 5 minutes ⭐
- **[FLUTTER_ARCHITECTURE.md](FLUTTER_ARCHITECTURE.md)** - Complete Flutter architecture guide
- **[TESTING_GUIDE.md](TESTING_GUIDE.md)** - Unit, widget, and integration testing
- **[EMULATOR_SETUP.md](EMULATOR_SETUP.md)** - Android Emulator configuration (localhost fix)

---

## 🔧 Technology Stack

**Backend**
- Django 4.2 + Django REST Framework
- FastAPI 0.104 + Uvicorn
- PostgreSQL 15
- Redis 7
- JWT (HS256)

**Frontend**
- Flutter 3.x (Dart)
- HTTP package for REST
- WebSocket for real-time

**Infrastructure**
- Docker & Docker Compose
- Health checks & auto-restart
- Environment-based configuration

---

## 🎯 API Endpoints

### Django REST API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/v1/auth/register/` | Register new user |
| POST | `/api/v1/auth/login/` | Get JWT tokens |
| POST | `/api/v1/auth/refresh/` | Refresh access token |
| GET | `/api/v1/users/me/` | Get current user |
| GET | `/api/v1/users/list_users/` | List all users |
| POST | `/api/v1/chat-rooms/` | Create chat room |
| GET | `/api/v1/chat-rooms/` | List user's rooms |
| POST | `/api/v1/messages/` | Send message |

### FastAPI WebSocket

| Protocol | Path | Purpose |
|----------|------|---------|
| WS | `/ws/chat/{room_id}?token=...` | Connect to room |
| GET | `/health` | Health check |
| GET | `/rooms/{room_id}/info` | Get room users |

---

## 🚀 Deployment

### Docker Production
```bash
docker-compose up -d
```

### Environment Variables
```bash
cp .env.example .env
# Generate: openssl rand -hex 32
# Set: SECRET_KEY=...
# Configure: DB, CORS, JWT settings
```

### Health Checks
All services include health checks:
```bash
docker-compose ps  # Check status
```

### Database & Authentication
- Firebase Firestore / Realtime Database
- Firebase Authentication

---

## 📌 API Overview

### Auth
- POST `/auth/signup`
- POST `/auth/login`
- POST `/auth/logout`
- GET `/auth/me`
- PUT `/auth/profile`
- POST `/auth/change-password`
- POST `/auth/reset-password`
- POST `/auth/confirm-password`

### Users
- POST `/users`
- GET `/users/{id}`

### Chats
- POST `/chats`
- GET `/chats`
- DELETE `/chats/{chatId}`

### Messages
- POST `/messages`
- GET `/messages/{chatId}`
- DELETE `/messages/{messageId}`

### Notifications
- GET `/notifications`

### WebSocket
- WS `/ws/chat/{chatId}` → real-time message exchange

---

## 🔐 Security Design

- No direct frontend access to Firebase
- Authentication enforced at backend level
- WebSocket connections validated using auth tokens
- All data access controlled through FastAPI

---

## 🎯 Project Purpose

This project was built as a **portfolio and live demo application** to demonstrate:
- Clean backend architecture
- Secure API and WebSocket integration
- Real-world authentication workflows
- Scalable chat system design

The focus is on clarity, correctness, and real-time communication without overengineering.

---

## 🛠️ Future Improvements

- Group chat support
- Message read receipts
- Media and file sharing
- Push notifications
- Online/offline presence indicators

---

## 📄 License

This project is open-source and intended for learning and demonstration purposes.

