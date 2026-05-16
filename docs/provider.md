# Provider & Dependency Injection (DI) Architecture

This project utilizes the `provider` package for state management and dependency injection. The architecture follows a layered approach where services are injected into providers, and providers are then consumed by the UI.

## 1. Global Provider Setup

All essential services and state providers are registered globally in `main.dart` within the `MultiProvider` widget. This ensures they are available throughout the entire application widget tree.

### The Dependency Chain

The dependencies are initialized and injected in a specific order to ensure that each component has its required dependencies:

1.  **Infrastructure Layer**:
    *   `HiveTokenStorage`: Initialized first to handle persistent JWT tokens.
2.  **Service Layer**:
    *   `ApiService`: Injected with `HiveTokenStorage`. It serves as the central authority for all REST API calls.
    *   `ChatService`: Injected with `ApiService`. Handles WebSocket connections and real-time message streaming.
    *   `NotificationService`: Injected with `ApiService`. Manages push notifications and device registration.
3.  **Provider Layer (Business Logic)**:
    *   `AuthProvider`: Depends on `ApiService` and `NotificationService`. Manages user session, login, and registration.
    *   `RoomProvider`: Depends on `ApiService` and `ChatService`. Manages the list of chat rooms and room-specific actions (e.g., leaving a group).
    *   `ChatProvider`: Depends on `ChatService`. Manages the message history and real-time state for a specific active chat.
    *   `FriendProvider`: Depends on `ApiService`. Manages friend lists, requests, and suggestions.

## 2. Dependency Injection in Practice

### Service Injection
Services are injected through the constructor of the providers in `main.dart`:

```dart
ChangeNotifierProvider(
  create: (_) => RoomProvider(
    apiService: _apiService,
    chatService: _chatService,
  ),
),
```

### UI Consumption
The UI consumes these providers using three primary methods:

*   **`context.read<T>()`**: Used inside functions (like button callbacks) to access a provider without listening for changes.
    ```dart
    onPressed: () => context.read<AuthProvider>().login(...)
    ```
*   **`context.watch<T>()`**: Used inside the `build` method to make the widget rebuild whenever the provider's state changes.
    ```dart
    final authState = context.watch<AuthProvider>();
    ```
*   **`Consumer<T>`**: Used for localized rebuilds to optimize performance by only rebuilding a specific part of the widget tree.

## 3. Functional Error Handling Integration

The providers are designed to work seamlessly with the functional error handling patterns (`fpdart`).

1.  **Service returns `TaskEither`**: The `ApiService` returns a `TaskEither<Failure, T>`.
2.  **Provider executes Task**: The Provider executes the task and handles the result using `.fold()`.
3.  **State Update**: On success, the provider updates its internal state. On failure, it updates an `error` field and notifies listeners.

Example pattern in a Provider:

```dart
Future<void> action() async {
  _isLoading = true;
  notifyListeners();

  final result = await apiService.someCall().run();

  result.fold(
    (failure) => _error = failure.message,
    (successData) => _data = successData,
  );

  _isLoading = false;
  notifyListeners();
}
```

## 4. Detailed Component Breakdown

The application is built around 6 core components that manage the data flow and state.

### Core Services (Infrastructure)

#### 1. ApiService
*   **Role**: The central gateway for all RESTful communication.
*   **Work**:
    *   Manages a `Dio` instance with interceptors for JWT authentication.
    *   Handles token refresh logic automatically when 401 errors occur.
    *   Uses `FunctionalApiHandler` to wrap all responses in `TaskEither` for safe error handling.
    *   Provides methods for auth, friends, room management, and profile updates.

#### 2. ChatService
*   **Role**: Manages real-time communication via WebSockets.
*   **Work**:
    *   Handles the WebSocket connection lifecycle (connect, disconnect, auto-reconnect).
    *   Implements exponential backoff for reconnection attempts.
    *   Parses incoming JSON messages into `ChatMessage` models.
    *   Provides a `Stream<ChatMessage>` that other providers listen to.

### Core Providers (State & Logic)

#### 3. AuthProvider
*   **Role**: Manages the user's identity and session.
*   **Work**:
    *   Handles `login`, `register`, and `logout` flows.
    *   Restores the user session on app startup by checking `HiveTokenStorage`.
    *   Exposes the `currentUser` object and `isAuthenticated` status.
    *   Triggers FCM token registration via `NotificationService` upon successful login.

#### 4. RoomProvider
*   **Role**: Manages the list of available chat rooms.
*   **Work**:
    *   Fetches and caches the list of rooms from the backend.
    *   Tracks unread message counts for each room.
    *   Listens to the `ChatService` stream to update the "last message" and unread count in real-time.
    *   Handles room-level actions like marking a room as read or leaving a group.

#### 5. ChatProvider
*   **Role**: Manages the state of a specific active conversation.
*   **Work**:
    *   Loads message history (first from Hive cache, then from API).
    *   Appends new messages received from the WebSocket stream.
    *   Manages "typing" indicators and "read receipts" for the current room.
    *   Synchronizes local Hive cache with server-side message state.

#### 6. FriendProvider
*   **Role**: Manages social relationships and discovery.
*   **Work**:
    *   Fetches the list of accepted friends and pending requests.
    *   Handles friend request workflows (send, accept, reject, remove).
    *   Provides suggested friends for the discovery discovery feature.
    *   Updates the friendship state across the UI when changes occur.
