# System Architecture

This project is a real-time chat application built with a modern, scalable stack.

## Tech Stack
- **Frontend**: [Flutter](https://flutter.dev) (Dart)
- **Backend**: [Django](https://www.djangoproject.com/) & [Django REST Framework](https://www.django-rest-framework.org/) (Python)
- **Real-time**: [Django Channels](https://channels.readthedocs.io/) (WebSockets)
- **Database**: [PostgreSQL](https://www.postgresql.org/)
- **Caching/Persistence**: [Hive](https://docs.hivedb.dev/) (Local storage for Flutter)
- **Containerization**: [Docker](https://www.docker.com/) & Docker Compose

## Core Components

### 1. Backend (backend_core)
The backend handles authentication, room management, friend requests, and real-time message broadcasting.
- **REST API**: Standard CRUD operations for users, rooms, and friends.
- **Consumers**: WebSocket handlers in `consumers.py` for real-time events.
- **Models**: `User`, `Room`, `Message`, `Friendship`.

### 2. Frontend (flutter)
The mobile app follows a clean architecture pattern with state management provided by `Provider`.
- **Services**: Low-level logic for APIs (`ApiService`) and WebSockets (`ChatService`).
- **Providers**: State management layer (`AuthProvider`, `ChatProvider`, `RoomProvider`, `FriendProvider`).
- **Models**: Data structures mapping to JSON responses.
- **Widgets/Screens**: UI layer built with standard Flutter widgets.

## Data Flow
1. **Auth**: User logs in -> JWT received -> Stored in Hive -> Used in `AuthInterceptor`.
2. **Chat List**: App loads rooms from `RoomProvider` -> Sorts by `last_message_timestamp`.
3. **Messaging**: WebSocket connection established -> Messages sent via Socket -> Server broadcasts to group -> Clients update local state and Hive cache.
4. **Offline Support**: Hive caches messages and room info for instant loading and offline viewing.
