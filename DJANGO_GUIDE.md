# Django Backend Implementation Guide

## Overview

The Django backend provides:
- User authentication with JWT tokens
- RESTful API for user and chat management
- Custom user model with extended fields
- PostgreSQL integration
- Redis caching support

## Database Models

### CustomUser Model

```python
class CustomUser(AbstractUser):
    email           # Unique email field
    phone_number    # Optional phone number
    avatar          # User avatar image
    bio             # User bio/description
    is_online       # Online status
    last_seen       # Last activity timestamp
    created_at      # Account creation time
    updated_at      # Last update time
```

### ChatRoom Model

```python
class ChatRoom(AbstractModel):
    id          # Unique identifier
    name        # Room name
    description # Room description
    room_type   # 'DM' or 'GROUP'
    participants # ManyToMany with CustomUser
    creator     # ForeignKey to CustomUser
    is_active   # Room status
    created_at  # Creation timestamp
    updated_at  # Last update timestamp
```

### Message Model

```python
class Message(AbstractModel):
    id          # Unique identifier
    room        # ForeignKey to ChatRoom
    sender      # ForeignKey to CustomUser
    content     # Message text
    message_type # 'TEXT', 'IMAGE', 'FILE', 'AI_RESPONSE'
    file        # Optional file attachment
    is_read     # Read status
    created_at  # Creation timestamp
    updated_at  # Last update timestamp
```

## Settings Configuration

### Key Configurations

**REST Framework**
```python
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticatedOrReadOnly',
    ),
}
```

**Simple JWT**
```python
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(hours=24),
    'ALGORITHM': 'HS256',
    'SIGNING_KEY': SECRET_KEY,
}
```

**Database**
```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'chat_db',
        'USER': 'chat_user',
        'PASSWORD': 'chat_password',
        'HOST': 'postgres',
        'PORT': '5432',
    }
}
```

## Authentication Flow

1. **User Registration**
   - POST to `/api/v1/auth/register/`
   - Validate passwords match
   - Create CustomUser instance
   - Return user data

2. **User Login**
   - POST to `/api/v1/auth/login/`
   - Validate credentials
   - Generate JWT tokens (access + refresh)
   - Return tokens with user info

3. **Token Refresh**
   - POST to `/api/v1/auth/refresh/`
   - Validate refresh token
   - Issue new access token
   - Return new token

## Running Migrations

```bash
# Create migrations
python manage.py makemigrations

# Apply migrations
python manage.py migrate

# Show migration status
python manage.py showmigrations
```

## Admin Interface

Access at `http://localhost:8000/admin`

Register models in admin:
```python
@admin.register(CustomUser)
class CustomUserAdmin(admin.ModelAdmin):
    list_display = ('username', 'email', 'is_online')
    search_fields = ('username', 'email')
```

## API Endpoints

### Authentication
- `POST /api/v1/auth/register/` - Register new user
- `POST /api/v1/auth/login/` - Login and get JWT
- `POST /api/v1/auth/refresh/` - Refresh access token

### Users
- `GET /api/v1/users/me/` - Get current user profile
- `PUT /api/v1/users/profile_update/` - Update profile
- `GET /api/v1/users/list_users/` - List all users

### Chat Rooms
- `GET /api/v1/chat-rooms/` - List user's rooms
- `POST /api/v1/chat-rooms/` - Create new room
- `GET /api/v1/chat-rooms/{id}/` - Get room details
- `POST /api/v1/chat-rooms/{id}/add_participant/` - Add user
- `POST /api/v1/chat-rooms/{id}/remove_participant/` - Remove user

### Messages
- `GET /api/v1/messages/` - List messages (filtered by room)
- `POST /api/v1/messages/` - Send message
- `PUT /api/v1/messages/{id}/mark_as_read/` - Mark as read

## Testing

Create test file: `chat_app/tests.py`

```python
from django.test import TestCase
from rest_framework.test import APIClient
from .models import CustomUser

class AuthenticationTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.register_data = {
            'username': 'testuser',
            'email': 'test@example.com',
            'password': 'testpass123',
            'password_confirm': 'testpass123'
        }
    
    def test_user_registration(self):
        response = self.client.post('/api/v1/auth/register/', self.register_data)
        self.assertEqual(response.status_code, 201)
    
    def test_user_login(self):
        # Create user first
        user = CustomUser.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        
        response = self.client.post('/api/v1/auth/login/', {
            'username': 'testuser',
            'password': 'testpass123'
        })
        self.assertEqual(response.status_code, 200)
        self.assertIn('access', response.data)
```

Run tests:
```bash
python manage.py test
python manage.py test chat_app.tests.AuthenticationTests
```

## Serializers

### Custom Token Serializer

```python
class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token['email'] = user.email
        token['username'] = user.username
        token['user_id'] = user.id
        return token
```

## Permissions

```python
from rest_framework.permissions import BasePermission

class IsRoomMember(BasePermission):
    def has_object_permission(self, request, view, obj):
        return request.user in obj.participants.all()
```

## Signals (Optional)

```python
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver

@receiver(post_save, sender=CustomUser)
def update_user_online_status(sender, instance, created, **kwargs):
    if created:
        # New user created
        pass
```

## Logging

```python
import logging

logger = logging.getLogger(__name__)

logger.info('User registered: {}'.format(user.username))
logger.error('Database connection failed')
```

## Performance Optimization

### Database Optimization

```python
# Use select_related for ForeignKey
messages = Message.objects.select_related('sender', 'room').all()

# Use prefetch_related for ManyToMany
rooms = ChatRoom.objects.prefetch_related('participants').all()

# Use only() to limit fields
users = CustomUser.objects.only('id', 'username', 'email')
```

### Caching

```python
from django.core.cache import cache

# Cache user profile
cache.set(f'user_{user_id}', user_data, timeout=3600)
user_data = cache.get(f'user_{user_id}')
```

## Celery Integration (Optional)

For async tasks:

```python
from celery import shared_task

@shared_task
def send_notification(user_id, message):
    # Send notifications asynchronously
    pass
```

## Security

- Use `HTTPS` in production
- Set `DEBUG=False` in production
- Use strong `SECRET_KEY`
- Implement rate limiting
- Validate all inputs
- Use CSRF protection

## Common Issues

### Migration Conflicts

```bash
# Squash migrations
python manage.py squashmigrations chat_app

# Show migration status
python manage.py showmigrations

# Rollback migration
python manage.py migrate chat_app 0001
```

### Permission Denied Errors

Ensure user has required permissions:
```python
POST /api/v1/chat-rooms/
Content-Type: application/json
Authorization: Bearer <access_token>
```

### Token Expired

Refresh token:
```python
POST /api/v1/auth/refresh/
Content-Type: application/json

{
  "refresh": "<refresh_token>"
}
```

## References

- [Django Documentation](https://docs.djangoproject.com/)
- [Django REST Framework](https://www.django-rest-framework.org/)
- [djangorestframework-simplejwt](https://django-rest-framework-simplejwt.readthedocs.io/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
