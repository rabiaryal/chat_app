"""
Database connection setup for FastAPI.
Uses the same PostgreSQL database as Django.
Enables async queries for membership verification.
"""

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from config import settings
import logging

logger = logging.getLogger(__name__)

# Declare Base for ORM models
Base = declarative_base()

# Create async engine
# Convert Django's postgresql:// URL to SQLAlchemy's postgresql+asyncpg://
DATABASE_URL_ASYNC = settings.DATABASE_URL.replace(
    'postgresql://',
    'postgresql+asyncpg://'
) if 'postgresql://' in settings.DATABASE_URL else settings.DATABASE_URL

engine = create_async_engine(
    DATABASE_URL_ASYNC,
    pool_size=20,
    max_overflow=10,
    echo=False,
    pool_pre_ping=True,  # Verify connections are alive before using
    connect_args={
        "timeout": 10,
        "command_timeout": 10,
    }
)

# Create async session factory
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)


async def get_db() -> AsyncSession:
    """
    Dependency for getting database session.
    Usage: db = Depends(get_db)
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()


async def init_db():
    """
    Initialize database connection pool and test connectivity.
    Called on FastAPI startup.
    """
    try:
        async with engine.begin() as conn:
            # Test connection by executing a simple query
            await conn.exec_driver_sql("SELECT 1")
        logger.info("✓ Database connection pool initialized successfully")
        return True
    except Exception as e:
        logger.error(f"✗ Failed to initialize database: {e}")
        return False


async def close_db():
    """
    Close database connection pool.
    Called on FastAPI shutdown.
    """
    try:
        await engine.dispose()
        logger.info("✓ Database connection pool closed")
    except Exception as e:
        logger.error(f"✗ Error closing database: {e}")
