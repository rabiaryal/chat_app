-- Initialize database with required roles and permissions
CREATE SCHEMA IF NOT EXISTS public;

-- Grant permissions to the chat user
ALTER SCHEMA public OWNER TO chat_user;

-- Create UUID extension if not exists
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Grant permissions on extensions
GRANT USAGE ON SCHEMA public TO chat_user;
GRANT CREATE ON SCHEMA public TO chat_user;
