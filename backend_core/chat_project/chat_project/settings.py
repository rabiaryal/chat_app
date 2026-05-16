"""
Django settings for chat_project project.
"""

import os
import logging
from datetime import timedelta
from pathlib import Path
from decouple import config
import firebase_admin
from firebase_admin import credentials

# Build paths inside the project
BASE_DIR = Path(__file__).resolve().parent.parent
logger = logging.getLogger(__name__)

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = config('SECRET_KEY', default='django-insecure-change-me-in-production')

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = config('DEBUG', default=True, cast=bool)

ALLOWED_HOSTS = ['chat.rabiaryal.com.np', 'localhost', '127.0.0.1']

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'channels',
    'rest_framework',
    'rest_framework_simplejwt.token_blacklist',
    'corsheaders',
    'drf_spectacular',
    'fcm_django',
    'chat_app',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'chat_project.urls'
ASGI_APPLICATION = 'chat_project.asgi.application'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'chat_project.wsgi.application'

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DB_NAME', default='chat_db'),
        'USER': config('DB_USER', default='chat_user'),
        'PASSWORD': config('DB_PASSWORD', default='chat_password'),
        'HOST': config('DB_HOST', default='localhost'),
        'PORT': config('DB_PORT', default='5432'),
    }
}

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

# Internationalization
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# Static files
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# REST Framework configuration
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticatedOrReadOnly',
    ),
    'DEFAULT_THROTTLE_CLASSES': (
        'rest_framework.throttling.UserRateThrottle',
    ),
    'DEFAULT_THROTTLE_RATES': {
        'user': '100/minute',
    },
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 10,
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
}

SPECTACULAR_SETTINGS = {
    'TITLE': 'Chat App API',
    'DESCRIPTION': 'API for the Chat App with JWT Authentication',
    'VERSION': '1.0.0',
    'SERVE_INCLUDE_SCHEMA': False,
    'SECURITY': [
        {
            'Bearer': [],
        }
    ],
    'COMPONENTS': {
        'securitySchemes': {
            'Bearer': {
                'type': 'http',
                'scheme': 'bearer',
                'bearerFormat': 'JWT',
                'description': 'JWT access token. Get one from POST /api/v1/auth/login/ with username and password.',
            }
        }
    },
}

# Simple JWT configuration
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(hours=config('JWT_EXPIRATION_HOURS', default=24, cast=int)),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'UPDATE_LAST_LOGIN': False,

    'ALGORITHM': 'HS256',
    'SIGNING_KEY': SECRET_KEY,
    'VERIFYING_KEY': None,
    'AUDIENCE': None,
    'ISSUER': None,
    'JTI_CLAIM': 'jti',
    'TOKEN_TYPE_CLAIM': 'token_type',

    'AUTH_HEADER_TYPES': ('Bearer',),
    'AUTH_HEADER_NAME': 'HTTP_AUTHORIZATION',
    'USER_ID_FIELD': 'id',
    'USER_ID_CLAIM': 'user_id',
    'USER_AUTHENTICATION_RULE': 'rest_framework_simplejwt.authentication.default_user_authentication_rule',

    'AUTH_TOKEN_CLASSES': ('rest_framework_simplejwt.tokens.AccessToken',),
    'TOKEN_USER_CLASS': 'rest_framework_simplejwt.models.TokenUser',

    'JTI_CLAIM': 'jti',
}

# CORS Configuration
# Restrict CORS to production host by default; can be extended via env var
CORS_ALLOWED_ORIGINS = [
    'https://chat.rabiaryal.com.np',
]

# Parse from environment if provided
cors_env = config('CORS_ALLOWED_ORIGINS', default=None)
if cors_env:
    CORS_ALLOWED_ORIGINS.extend([origin.strip() for origin in cors_env.split(',')])

CORS_ALLOW_CREDENTIALS = True
CORS_ALLOW_METHODS = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS']
CORS_ALLOW_HEADERS = ['Accept', 'Accept-Language', 'Content-Type', 'Authorization', 'Origin']

# Channels configuration
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {
            'hosts': [config('REDIS_URL', default='redis://localhost:6379/0')],
        },
    },
}

# Custom User Model
AUTH_USER_MODEL = 'chat_app.CustomUser'

# Firebase Cloud Messaging (FCM) configuration
FCM_ENABLED = config('FCM_ENABLED', default=False, cast=bool)
FIREBASE_CREDENTIALS_FILE = config('FIREBASE_CREDENTIALS_FILE', default='')

FCM_DJANGO_SETTINGS = {
    'DEFAULT_FIREBASE_APP': None,
    'APP_VERBOSE_NAME': 'Firebase Cloud Messaging',
    # Data-only notifications for E2EE-safe push handling
    'ONE_DEVICE_PER_USER': False,
}

if FCM_ENABLED:
    if FIREBASE_CREDENTIALS_FILE:
        try:
            cred_path = Path(FIREBASE_CREDENTIALS_FILE)
            if not cred_path.is_absolute():
                cred_path = BASE_DIR / FIREBASE_CREDENTIALS_FILE

            if cred_path.exists():
                if not firebase_admin._apps:
                    cred = credentials.Certificate(str(cred_path))
                    firebase_admin.initialize_app(cred)
            else:
                logger.warning('FCM enabled but credential file not found at %s', cred_path)
        except Exception as exc:
            logger.exception('Failed to initialize Firebase Admin SDK: %s', exc)
    else:
        logger.warning('FCM_ENABLED=True but FIREBASE_CREDENTIALS_FILE is not set')

# Logging Configuration
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
        'simple': {
            'format': '{levelname} {asctime} {message}',
            'style': '{',
        },
    },
    'filters': {
        'require_debug_false': {
            '()': 'django.utils.log.RequireDebugFalse',
        },
        'require_debug_true': {
            '()': 'django.utils.log.RequireDebugTrue',
        },
    },
    'handlers': {
        'console': {
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
        },
    },
    'root': {
        'handlers': ['console'],
        'level': 'INFO',
    },
}
