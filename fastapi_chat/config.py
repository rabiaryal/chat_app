"""
Configuration for FastAPI Chatbot Service.
"""

import os
from pydantic_settings import BaseSettings
from typing import List
from decouple import config as decouple_config


class Settings(BaseSettings):
    """Application settings from environment variables."""
    
    # API Configuration
    APP_NAME: str = "FastAPI Chat Service"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = decouple_config('FASTAPI_DEBUG', default=True, cast=bool)
    
    # Server Configuration
    HOST: str = "0.0.0.0"
    PORT: int = 8081
    RELOAD: bool = decouple_config('DEBUG', default=True, cast=bool)
    
    # JWT Configuration
    SECRET_KEY: str = decouple_config('SECRET_KEY', default='django-insecure-change-me-in-production')
    JWT_ALGORITHM: str = decouple_config('JWT_ALGORITHM', default='HS256')
    JWT_EXPIRATION_HOURS: int = decouple_config('JWT_EXPIRATION_HOURS', default=24, cast=int)
    
    # Database Configuration
    DATABASE_URL: str = decouple_config('DATABASE_URL', default='postgresql://chat_user:chat_password@localhost:5432/chat_db')
    
    # Redis Configuration
    REDIS_URL: str = decouple_config('REDIS_URL', default='redis://localhost:6379/0')
    
    # CORS Configuration - allow Flutter, local dev, and inter-service communication
    CORS_ALLOWED_ORIGINS_STR: str = decouple_config(
        'CORS_ALLOWED_ORIGINS',
        default='http://localhost:3000,http://localhost:8000,http://localhost:8081,http://localhost:8080,http://127.0.0.1:3000,http://127.0.0.1:8000,http://127.0.0.1:8081,http://192.168.1.65:8000,http://192.168.1.65:8081,http://192.168.1.65:3000,http://django:8000,http://fastapi:8081'
    )
    
    # Service URLs
    DJANGO_SERVICE_URL: str = decouple_config('DJANGO_SERVICE_URL', default='http://django:8000')
    FASTAPI_SERVICE_URL: str = decouple_config('FASTAPI_SERVICE_URL', default='http://fastapi:8081')
    
    class Config:
        env_file = '.env'
        case_sensitive = True


# Initialize settings
settings = Settings()

# Parse CORS origins to list for use in FastAPI
CORS_ALLOWED_ORIGINS: List[str] = [
    origin.strip() 
    for origin in settings.CORS_ALLOWED_ORIGINS_STR.split(',')
    if origin.strip()
]

# Log CORS configuration for debugging
print(f"FastAPI CORS Allowed Origins: {CORS_ALLOWED_ORIGINS}")
