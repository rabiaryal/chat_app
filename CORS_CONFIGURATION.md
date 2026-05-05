# CORS Configuration Documentation

## Overview

CORS (Cross-Origin Resource Sharing) is configured to allow communication between:
1. **Flutter Mobile App** - on Android device via wireless connection
2. **Django Backend** - REST API server (port 8000)
3. **FastAPI Service** - WebSocket and AI service (port 8081)
4. **Web Frontend** - local development (port 3000)
5. **Inter-Service Communication** - between Django and FastAPI

---

## Allowed Origins

### Flutter Mobile App
```
http://192.168.1.65:8000  (Django)
http://192.168.1.65:8081  (FastAPI)
```

### Local Development
```
http://localhost:3000     (Web frontend)
http://localhost:8000     (Django dev server)
http://localhost:8081     (FastAPI dev server)
http://localhost:8080     (Mobile emulator)

http://127.0.0.1:3000
http://127.0.0.1:8000
http://127.0.0.1:8081
http://127.0.0.1:8080
```

### Docker Inter-Service Communication
```
http://django:8000        (Django container)
http://fastapi:8081       (FastAPI container)
```

---

## Django CORS Configuration

**File:** `backend_core/chat_project/chat_project/settings.py`

```python
CORS_ALLOWED_ORIGINS = [
    'http://localhost:3000',
    'http://localhost:8000',
    'http://localhost:8081',
    'http://localhost:8080',
    'http://127.0.0.1:3000',
    'http://127.0.0.1:8000',
    'http://127.0.0.1:8081',
    'http://127.0.0.1:8080',
    'http://192.168.1.65:8000',
    'http://192.168.1.65:8081',
    'http://192.168.1.65:3000',
    'http://django:8000',
    'http://fastapi:8081',
]

CORS_ALLOW_CREDENTIALS = True
CORS_ALLOW_METHODS = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS']
CORS_ALLOW_HEADERS = ['Accept', 'Accept-Language', 'Content-Type', 'Authorization', 'Origin']
```

**Middleware Order:**
```python
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'corsheaders.middleware.CorsMiddleware',  # ← Must be first
    'django.middleware.common.CommonMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]
```

---

## FastAPI CORS Configuration

**File:** `fastapi_chat/config.py`

```python
class Settings(BaseSettings):
    CORS_ALLOWED_ORIGINS_STR: str = decouple_config(
        'CORS_ALLOWED_ORIGINS',
        default='http://localhost:3000,http://localhost:8000,http://localhost:8081,http://localhost:8080,http://127.0.0.1:3000,http://127.0.0.1:8000,http://127.0.0.1:8081,http://192.168.1.65:8000,http://192.168.1.65:8081,http://192.168.1.65:3000,http://django:8000,http://fastapi:8081'
    )

CORS_ALLOWED_ORIGINS: List[str] = [
    origin.strip() 
    for origin in settings.CORS_ALLOWED_ORIGINS_STR.split(',')
    if origin.strip()
]
```

**File:** `fastapi_chat/main.py`

```python
from fastapi.middleware.cors import CORSMiddleware
from config import CORS_ALLOWED_ORIGINS

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

---

## Environment Variables (Optional)

You can override CORS settings via environment variables:

**Django:**
```bash
export CORS_ALLOWED_ORIGINS="http://custom.domain:8000,http://another.domain:8081"
```

**FastAPI:**
```bash
export CORS_ALLOWED_ORIGINS="http://custom.domain:8000,http://another.domain:8081"
```

Add to `.env` file:
```
CORS_ALLOWED_ORIGINS=http://custom.domain:8000,http://another.domain:8081
```

---

## How CORS Works in Your Architecture

```
┌──────────────────────────────────────────────────────────┐
│                   Flutter Mobile App                      │
│              (192.168.1.65 via WiFi)                      │
└──────────┬───────────────────────────────────────────────┘
           │
           ├─────────────────────────────────┐
           │                                 │
           ▼                                 ▼
    ┌──────────────────┐            ┌──────────────────┐
    │  Django Backend  │            │  FastAPI Service │
    │  :8000           │            │  :8081           │
    │                  │            │                  │
    │ CORS Enabled ✓   │            │ CORS Enabled ✓   │
    └──────────────────┘            └──────────────────┘
           │                                 │
           │◄────────────CORS✓──────────────►│
           │    Inter-Service Communication   │
           └──────────────────┬──────────────┘
                              │
                    ┌─────────▼────────────┐
                    │  PostgreSQL Database  │
                    │  Redis Cache          │
                    └───────────────────────┘
```

---

## Request Flow Example

### 1. Flutter App Registers User
```
Request:
POST http://192.168.1.65:8000/api/v1/auth/register/
Origin: Flutter App
Headers: Content-Type: application/json

Response Header:
Access-Control-Allow-Origin: http://192.168.1.65:*
Access-Control-Allow-Credentials: true
```

### 2. FastAPI Calls Django
```
Request (from FastAPI container):
GET http://django:8000/api/v1/user/me/
Origin: http://fastapi:8081

Response Header:
Access-Control-Allow-Origin: http://django:8000
Access-Control-Allow-Credentials: true
```

### 3. Django Queries Database
```
(No CORS needed - same server)
PostgreSQL Query → Result
```

---

## CORS Preflight Requests

Browsers automatically send preflight requests for certain conditions:

```
Example Preflight (OPTIONS request):
OPTIONS /api/v1/auth/register/
headers:
  Origin: http://192.168.1.65:8000
  Access-Control-Request-Method: POST
  Access-Control-Request-Headers: Content-Type, Authorization

Response:
200 OK
Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
Access-Control-Allow-Headers: Accept, Accept-Language, Content-Type, Authorization, Origin
Access-Control-Allow-Credentials: true
```

---

## Troubleshooting CORS Errors

### Error: "Access to XMLHttpRequest blocked by CORS policy"

**Solution 1:** Check if origin is in CORS_ALLOWED_ORIGINS list
```bash
# View Django CORS configuration
curl -v -X OPTIONS http://192.168.1.65:8000/api/v1/auth/login/ \
  -H "Origin: http://192.168.1.65:8000"

# Check response headers
# Should see: Access-Control-Allow-Origin: http://192.168.1.65:8000
```

**Solution 2:** Verify your machine IP
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

**Solution 3:** Check cors.py configuration in Docker
```bash
docker logs chat_app_django  # Look for CORS errors
docker logs chat_app_fastapi
```

### Error: "Credentials mode is 'include'"

**Solution:** Ensure CORS_ALLOW_CREDENTIALS = True
```python
# Django
CORS_ALLOW_CREDENTIALS = True

# FastAPI
app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,  # ← Set to True
)
```

---

## Testing CORS Configuration

### Test Django CORS
```bash
# Simple request
curl -X GET http://192.168.1.65:8000/api/v1/user/me/ \
  -H "Authorization: Bearer <token>" \
  -H "Origin: http://192.168.1.65:8000"

# Check CORS headers in response
curl -i -X OPTIONS http://192.168.1.65:8000/api/v1/auth/login/ \
  -H "Origin: http://192.168.1.65:8000" \
  -H "Access-Control-Request-Method: POST"
```

### Test FastAPI CORS
```bash
# Simple request
curl -X GET http://192.168.1.65:8081/health/ \
  -H "Origin: http://192.168.1.65:8081"

# Check CORS headers
curl -i -X OPTIONS http://192.168.1.65:8081/ws \
  -H "Origin: http://192.168.1.65:8081"
```

---

## Production CORS Security

For production deployments, be more restrictive:

```python
# Django (Production)
CORS_ALLOWED_ORIGINS = [
    'https://yourdomain.com',
    'https://app.yourdomain.com',
    'https://www.yourdomain.com',
]

# FastAPI (Production)
CORS_ALLOWED_ORIGINS = [
    'https://yourdomain.com',
    'https://app.yourdomain.com',
]
```

---

## Docker Compose Setup

**Key Points:**
1. Django service can reach FastAPI via `http://fastapi:8081`
2. FastAPI service can reach Django via `http://django:8000`
3. Both allow CORS from each other internally
4. Both allow CORS from Flutter app's IP (192.168.1.65)

**Network Configuration:**
```yaml
services:
  django:
    networks:
      - chat_network
  fastapi:
    networks:
      - chat_network
  postgres:
    networks:
      - chat_network

networks:
  chat_network:
    driver: bridge
```

---

## Summary

✅ **CORS is configured for:**
- Flutter mobile app via wireless connection
- Local development on multiple ports
- Docker inter-service communication
- Proper credential handling
- All HTTP methods (GET, POST, PUT, PATCH, DELETE)
- Required headers (Authorization, Content-Type, etc.)

✅ **Best Practices Implemented:**
- CORS middleware placed first in Django
- Credentials allowed for authenticated requests
- OPTIONS preflight requests handled automatically
- Error responses logged for debugging
- Environment variable overrides for flexibility
