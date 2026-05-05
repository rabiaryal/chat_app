"""
JWT utilities for FastAPI service.
"""

import jwt
from datetime import datetime, timedelta
from typing import Optional, Dict
from fastapi import Depends, HTTPException, status, WebSocketException
from fastapi.security import HTTPBearer
from config import settings
import json

security = HTTPBearer()


class JWTHandler:
    """Handler for JWT operations compatible with Django's django-rest-framework-simplejwt."""
    
    @staticmethod
    def decode_token(token: str) -> Dict:
        """
        Decode and verify JWT token issued by Django.
        
        Args:
            token: JWT token string
            
        Returns:
            Decoded token payload
            
        Raises:
            HTTPException: If token is invalid or expired
        """
        try:
            payload = jwt.decode(
                token,
                settings.SECRET_KEY,
                algorithms=[settings.JWT_ALGORITHM]
            )
            return payload
        except jwt.ExpiredSignatureError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has expired"
            )
        except jwt.InvalidTokenError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token"
            )
    
    @staticmethod
    def create_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
        """
        Create a JWT token (for testing purposes).
        
        Args:
            data: Data to encode
            expires_delta: Token expiration time
            
        Returns:
            JWT token string
        """
        to_encode = data.copy()
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(hours=settings.JWT_EXPIRATION_HOURS)
        
        to_encode.update({"exp": expire})
        encoded_jwt = jwt.encode(
            to_encode,
            settings.SECRET_KEY,
            algorithm=settings.JWT_ALGORITHM
        )
        return encoded_jwt


async def get_current_user(credentials = Depends(security)) -> Dict:
    """
    Dependency for extracting and validating current user from JWT token.
    
    Args:
        credentials: HTTP Bearer credentials
        
    Returns:
        Decoded token payload containing user info
        
    Raises:
        HTTPException: If token is invalid or expired
    """
    token = credentials.credentials
    payload = JWTHandler.decode_token(token)
    return payload


async def get_token_from_header(token: str) -> Dict:
    """
    Extract and validate token from Authorization header string.
    
    Args:
        token: Token string
        
    Returns:
        Decoded token payload
    """
    return JWTHandler.decode_token(token)


async def get_token_from_query(token: str) -> Dict:
    """
    Extract and validate token from query parameter.
    
    Args:
        token: Token string from query parameter
        
    Returns:
        Decoded token payload
    """
    if not token:
        raise WebSocketException(code=4001, reason="No token provided")
    return JWTHandler.decode_token(token)
