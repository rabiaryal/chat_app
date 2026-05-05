# Chat App - Production-Ready Django + FastAPI + Flutter System

A comprehensive hybrid backend architecture for a real-time Flutter chat application with centralized JWT authentication, WebSocket support, and AI chatbot integration.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Client Layer                     │
│  (Dart - HTTP + WebSocket Services)                          │
└────────────────┬──────────────────────────────┬──────────────┘
                 │                              │
           API Calls (REST)              WebSocket (Real-time)
                 │                              │
        ┌────────▼─────────┐           ┌──────────▼──────────┐
        │   Django 8000     │           │  FastAPI 8081       │
        │  (Auth + REST)    │           │  (WebSocket + AI)   │
        │  - Login/Register │           │  - Chat Rooms       │
        │  - User Profiles  │           │  - Real-time Msg    │
        │  - JWT Issuer     │           │  - AI Responses     │
        │  - REST APIs      │           │  - Stream Messages  │
        └────────┬──────────┘           └──────────┬──────────┘
                 │                              │
                 │         Shared JWT           │
                 │      (Verification)          │
                 │                              │
        ┌────────▼──────────────────────▼───────┐
        │    PostgreSQL Database (5432)          │
        │  - Users + Chat Rooms + Messages       │
        └──────────────────────────────────────┘
                           │
        ┌──────────────────▼──────────────────┐
        │      Redis Cache (6379)              │
        │  - Sessions + Temporary Data         │
        └──────────────────────────────────────┘
```

## Project Structure

```
chat_app/
├── docker-compose.yml           # Docker orchestration
├── .env.example                 # Environment variables template
├── init-db.sql                  # Database initialization
│
├── backend_core/                # Django Backend Service
│   ├── Dockerfile               # Django Docker image
│   ├── requirements.txt          # Python dependencies
│   └── chat_project/
│       ├── manage.py             # Django management script
│       ├── chat_project/
│       │   ├── settings.py       # Django settings (JWT, DB, etc.)
│       │   ├── urls.py           # URL routing
│       │   ├── wsgi.py           # WSGI application
│       │   └── asgi.py           # ASGI application
│       └── chat_app/
│           ├── models.py         # User, ChatRoom, Message models
│           ├── serializers.py    # DRF serializers with JWT
│           ├── views.py          # ViewSets and endpoints
│           ├── urls.py           # App URL routing
│           └── admin.py          # Django admin configuration
│
├── fastapi_chat/                # FastAPI WebSocket Service
│   ├── Dockerfile               # FastAPI Docker image
│   ├── requirements.txt          # Python dependencies
│   ├── main.py                  # FastAPI application
│   ├── config.py                # FastAPI configuration
│   ├── jwt_utils.py             # JWT validation (shared with Django)
│   └── ai_utils.py              # AI response generation
│
└── flutter/lib/services/        # Flutter Client Services
    ├── api_service.dart         # HTTP service for Django API
    ├── websocket_service.dart   # WebSocket service for FastAPI
    └── chat_service_example.dart # Integration examples
```

## Key Features

### 1. **Centralized JWT Authentication**
- Django issues JWT tokens
- FastAPI validates using shared `SECRET_KEY`
- No database ping-pong between services
- Token refresh mechanism included

### 2. **Real-Time WebSocket Chat**
- FastAPI WebSocket endpoint at `/ws/chat/{room_id}`
- Token validation via query parameter
- Connection management and broadcasting
- Typing indicators and user status

### 3. **AI Chatbot Integration**
- Placeholder for AI service integration
- Async streaming responses
- Conversation context management
- Compatible with OpenAI, Cohere, Anthropic, etc.

### 4. **Database Architecture**
- **PostgreSQL** for persistent data
- Shared database between Django and FastAPI
- Redis for caching and sessions
- Custom user model with extended fields

### 5. **Production-Ready**
- Docker Compose orchestration
- Health checks for all services
- Error handling and logging
- CORS configuration
- Scalable architecture

## Quick Start

### Prerequisites
- Docker & Docker Compose
- Python 3.11+ (for local development)
- Flutter SDK (for mobile app)

### Setup with Docker Compose

1. **Clone the repository**
```bash
cd /Applications/development/flutter_dev/chat_app
```

2. **Create .env file from template**
```bash
cp .env.example .env
```

3. **Update .env with your configuration**
```bash
# Generate a secure SECRET_KEY
openssl rand -hex 32
```

4. **Start all services**
```bash
docker-compose up -d
```

5. **Access services**
- Django Admin: http://localhost:8000/admin
- Django API: http://localhost:8000/api/v1/
- FastAPI Docs: http://localhost:8081/docs (when development ready)
- PostgreSQL: localhost:5432

### Setup for Local Development

#### Django Backend

```bash
cd backend_core/chat_project

# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r ../requirements.txt

# Create .env file
cp ../../.env.example .env

# Run migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Start development server
python manage.py runserver
```

#### FastAPI Service

```bash
cd fastapi_chat

# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Create .env file
cp ../.env.example .env

# Start development server
python -m uvicorn main:app --reload --port 8081
```

#### Flutter Client

```bash
cd flutter

# Get dependencies
flutter pub get

# Run the app
flutter run

# Run on web
flutter run -d web
```

## API Documentation

### Django REST API

#### Authentication

**Register User**
```bash
POST /api/v1/auth/register/
Content-Type: application/json

{
  "username": "john_doe",
  "email": "john@example.com",
  "password": "securepassword123",
  "password_confirm": "securepassword123",
  "first_name": "John",
  "last_name": "Doe"
}
```

**Login**
```bash
POST /api/v1/auth/login/
Content-Type: application/json

{
  "username": "john_doe",
  "password": "securepassword123"
}

Response:
{
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "user_id": 1,
  "username": "john_doe",
  "email": "john@example.com"
}
```

**Refresh Token**
```bash
POST /api/v1/auth/refresh/
Content-Type: application/json

{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

#### User Endpoints

**Get Current User**
```bash
GET /api/v1/users/me/
Authorization: Bearer <access_token>
```

**List Users** (for friend discovery)
```bash
GET /api/v1/users/list_users/
Authorization: Bearer <access_token>
```

**Update Profile**
```bash
PUT /api/v1/users/profile_update/
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "bio": "Hello, I'm John!",
  "first_name": "John",
  "last_name": "Doe"
}
```

#### Chat Room Endpoints

**Create Chat Room**
```bash
POST /api/v1/chat-rooms/
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "name": "General Chat",
  "description": "General discussion",
  "room_type": "GROUP",
  "participants": [1, 2, 3]
}
```

**List Chat Rooms**
```bash
GET /api/v1/chat-rooms/
Authorization: Bearer <access_token>
```

**Get Chat Room Details**
```bash
GET /api/v1/chat-rooms/{room_id}/
Authorization: Bearer <access_token>
```

**Add Participant**
```bash
POST /api/v1/chat-rooms/{room_id}/add_participant/
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "user_id": 5
}
```

### FastAPI WebSocket API

**Connect to Chat Room**
```
ws://localhost:8081/ws/chat/{room_id}?token={jwt_token}
```

**Send Text Message**
```json
{
  "type": "text_message",
  "content": "Hello everyone!"
}
```

**Request AI Response**
```json
{
  "type": "ai_request",
  "content": "What is the weather like?"
}
```

**Send Typing Indicator**
```json
{
  "type": "typing"
}
```

**Incoming Message Types**
```json
{
  "type": "text_message",
  "room_id": "room123",
  "user_id": 1,
  "username": "john_doe",
  "content": "Hello!",
  "message_id": "msg_123",
  "timestamp": "2024-04-30T12:00:00"
}
```

## JWT Validation Across Services

### How It Works

1. **Django Issues Token** (at `/api/v1/auth/login/`)
   - Signs with `SECRET_KEY`
   - Includes user info: `user_id`, `username`, `email`
   - Returns `access` and `refresh` tokens

2. **FastAPI Validates Token** (in WebSocket middleware)
   - Receives token in query parameter: `?token=...`
   - Decodes using same `SECRET_KEY`
   - Extracts user info without database call
   - Rejects if expired or invalid

3. **Both Share Configuration**
   - `SECRET_KEY` in `.env`
   - `JWT_ALGORITHM` (HS256)
   - `JWT_EXPIRATION_HOURS`

### Token Structure

```
Header: {
  "typ": "JWT",
  "alg": "HS256"
}

Payload: {
  "user_id": 1,
  "email": "john@example.com",
  "username": "john_doe",
  "exp": 1698765432,
  "iat": 1698679032,
  "jti": "unique-id",
  "token_type": "access"
}

Signature: HMACSHA256(header.payload, SECRET_KEY)
```

## Environment Variables

```env
# Security
SECRET_KEY=your-super-secret-key-change-this-in-production
DEBUG=False  # Set to True only in development

# Database
DATABASE_URL=postgresql://chat_user:chat_password@postgres:5432/chat_db
DB_NAME=chat_db
DB_USER=chat_user
DB_PASSWORD=chat_password
DB_HOST=postgres
DB_PORT=5432

# JWT
JWT_ALGORITHM=HS256
JWT_EXPIRATION_HOURS=24

# Service Configuration
DJANGO_PORT=8000
FASTAPI_PORT=8081
POSTGRES_PORT=5432

# CORS
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8081

# Redis
REDIS_URL=redis://redis:6379/0

# Superuser
DJANGO_SUPERUSER_USERNAME=admin
DJANGO_SUPERUSER_EMAIL=admin@example.com
DJANGO_SUPERUSER_PASSWORD=admin123456
```

## Troubleshooting

### JWT Token Validation Fails in FastAPI

**Problem**: WebSocket connects but token validation fails

**Solution**:
1. Ensure `SECRET_KEY` is identical in both `.env` files
2. Check token expiration: `exp` claim in JWT payload
3. Verify `JWT_ALGORITHM` matches (should be HS256)
4. Token must be passed as query parameter: `?token=...`

### Database Connection Issues

**Problem**: Services can't connect to PostgreSQL

**Solution**:
1. Check `docker-compose ps` to ensure postgres is running
2. Verify database credentials in `.env`
3. Wait for postgres health check: `docker-compose logs postgres`
4. Reset database: `docker-compose down -v && docker-compose up`

### WebSocket Connection Refused

**Problem**: Flutter can't connect to FastAPI WebSocket

**Solution**:
1. Ensure FastAPI is running: `docker-compose logs fastapi`
2. Check firewall allows port 8081
3. For local FLutter app, update `baseUrl` to your machine IP
4. Verify token is passed in query parameter
5. Check CORS configuration in `fastapi_chat/config.py`

## Next Steps

1. **Get Django Login Working**
   - Test registration and login endpoints
   - Verify JWT token generation
   - Test with Postman or curl

2. **Test WebSocket Connection**
   - Connect using generated JWT
   - Send test messages
   - Verify message broadcasting

3. **Integrate Flutter**
   - Update API URLs to match your deployment
   - Implement login UI
   - Build chat room UI
   - Test message sending/receiving

4. **Add AI Integration**
   - Replace placeholder in `ai_utils.py`
   - Integrate with OpenAI, Cohere, etc.
   - Test streaming responses

## Production Deployment

### Before Going Live

- [ ] Change all default passwords
- [ ] Generate secure `SECRET_KEY`
- [ ] Set `DEBUG=False`
- [ ] Configure proper `ALLOWED_HOSTS`
- [ ] Set up HTTPS/TLS certificates
- [ ] Configure production database
- [ ] Set up Redis cluster
- [ ] Configure proper CORS origins
- [ ] Set up logging and monitoring
- [ ] Configure backup strategy

### Deployment Options

- **AWS ECS**: Use Docker images with CloudFormation
- **Kubernetes**: Create deployments for each service
- **Heroku**: Deploy Django and FastAPI separately
- **DigitalOcean**: Use App Platform or manually with VPS
- **Railway.app**: Simple push-to-deploy solution

## Contributing

1. Create feature branches
2. Follow PEP 8 style guide
3. Write tests for new features
4. Submit pull requests

## License

See [LICENSE](LICENSE) file for details.

## Support & Questions

For issues and questions:
1. Check existing documentation
2. Review service logs: `docker-compose logs <service>`
3. Test with provided example services
4. Consult Django and FastAPI documentation

---

**Built with ❤️ using Django, FastAPI, and Flutter**
