# System Architecture

This project uses a **hybrid layered architecture** with **MVVM-inspired state management** on Flutter.

It is best described as:

- **Frontend**: Layered + Provider (MVVM style)
- **Backend**: Django modular monolith (MVT + DRF + Channels)
- **Realtime**: WebSocket event-driven messaging

## Architecture Style Used

## Flutter App: MVVM-Inspired Layered Architecture

The Flutter side is not strict Clean Architecture. It follows a practical MVVM-style split:

- **View**:
	- `screens/` and `widgets/`
	- Responsible for rendering UI and user interactions.
- **ViewModel / State Layer**:
	- `providers/` (`AuthProvider`, `RoomProvider`, `ChatProvider`, `FriendProvider`)
	- Holds UI state, orchestrates user flows, notifies UI via `ChangeNotifier`.
- **Model + Data Layer**:
	- `models/` define data contracts.
	- `services/` (`ApiService`, `ChatService`, `NotificationService`) handle REST, WebSocket, FCM, and persistence interactions.
	- Local persistence (`Hive`) supports token/session and offline-friendly UX.

So if you want a short label: **Provider-based MVVM (layered)**.

## Backend: Django Modular Monolith

The backend is a single Django project composed of app modules:

- **REST Layer (DRF)**: HTTP endpoints for auth, users, friends, rooms, messages, devices.
- **Realtime Layer (Channels)**: WebSocket consumers for live chat events.
- **Domain/Data Layer**: Django models + services + serializers.

This is not microservices; it is a **modular monolith**.

## High-Level Request Flow

1. UI action happens in a `screen`.
2. `Provider` (ViewModel) handles intent and state.
3. `Provider` calls `Service` (`ApiService` or `ChatService`).
4. Service talks to Django via REST or WebSocket.
5. Response/event is mapped into `Model`.
6. Provider updates state and notifies listeners.
7. UI rebuilds from updated state.

## Key Cross-Cutting Patterns

- **Centralized API constants** for endpoint standardization.
- **Dio interceptor** for JWT injection and token refresh.
- **Hive** for local token/cache persistence.
- **Firebase Messaging** for push notifications.

## Practical Classification

If someone asks "What architecture is this project using?" you can answer:

"It uses a **hybrid layered architecture** with **Provider-based MVVM** on Flutter, backed by a **Django modular monolith** using DRF + Channels."
