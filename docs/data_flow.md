# Data Flow

This document explains how data moves through the Flutter app and Django backend in this project. It focuses on the real runtime flow: startup, authentication, chat loading, realtime messaging, push notifications, and logout/session cleanup.

## 1. High-Level Flow

At a high level, the app follows this path:

1. The app boots in Flutter and initializes Firebase, Hive, and dependency objects.
2. `AuthProvider` and the router decide whether the user can go to chat screens or must go to auth screens.
3. `ApiService` handles REST calls to Django.
4. `ChatService` and `SocketService` handle realtime WebSocket traffic.
5. `NotificationService` handles FCM token registration, permission state, and push token cleanup.
6. UI screens read state from providers and rebuild when providers notify listeners.

In short:

`UI -> Provider -> Service -> Backend -> Service -> Provider -> UI`

The app is built to be offline-first where possible, so cached local data is shown immediately while fresh data is loaded in the background.

## 2. Startup Flow

The startup sequence begins in `flutter/lib/main.dart`.

### What happens on app launch

1. `WidgetsFlutterBinding.ensureInitialized()` is called.
2. `Firebase.initializeApp()` runs.
3. Hive is initialized with `Hive.initFlutter()`.
4. Two boxes are opened early:
	- `settings`
	- `chat_box`
5. `HiveTokenStorage` is initialized.
6. `MyApp` is created with the token storage instance.
7. `ApiService`, `NotificationService`, `AuthProvider`, and `ChatService` are constructed.
8. `SocketService` is configured with an unauthorized callback that can force session cleanup.
9. Notification initialization starts.
10. Auth initialization starts in the background.

### Why startup is arranged this way

- Firebase must be ready before push messaging can work.
- Hive must be ready before router auth checks can read the local token.
- The router can make an immediate decision based on local state, so the UI does not hang on a splash screen.
- Session validation runs in the background so the user sees the app immediately.

## 3. Authentication and Session Flow

Authentication is coordinated by `AuthProvider` and `HiveTokenStorage`.

### Login flow

1. The user submits credentials from the auth screen.
2. `AuthProvider.login()` calls `ApiService.login()`.
3. `ApiService` sends a REST request to Django.
4. The backend returns tokens and user data.
5. The token manager stores the access and refresh tokens in Hive.
6. `AuthProvider` stores the authenticated user and marks the user as authenticated.
7. `NotificationService.syncToken()` runs in the background so the device token is registered after login.
8. The router sees the authenticated state and navigates to chat screens.

### Session restore flow

1. On startup, `AuthProvider.initialize()` checks `HiveTokenStorage.hasAccessToken()`.
2. If a token exists, the UI is allowed to proceed immediately.
3. `AuthProvider` then validates the session in the background.
4. If the session is valid, the current user is loaded and notification token sync is attempted.
5. If the session is expired, local tokens are cleared and the user is redirected to auth.

### Logout flow

1. The user taps logout.
2. `AuthProvider.logout()` captures the current user and refresh token.
3. Local tokens are cleared immediately through `forceLogout()`.
4. The UI is updated immediately through `clearAuth()`.
5. User-scoped local cache data is cleared.
6. Backend logout and FCM cleanup continue in the background.

### Why this matters

The router depends on local token presence. If tokens are cleared too late, the app can briefly route back into chat screens. That is why logout now clears tokens before doing background cleanup.

## 4. Router Flow

The router in `flutter/lib/constants/router.dart` is one of the main decision points in the app.

### Redirect logic

The router checks two signals:

- `HiveTokenStorage.instance.hasAccessToken()`
- `AuthProvider.isAuthenticated`

### Redirect behavior

- If a local session exists, the app can go to `/chat-list` immediately.
- If the user is not authenticated, protected routes redirect to `/auth`.
- The splash screen is only a lightweight loading surface, not a blocking auth gate.

This design gives the app a fast startup while still allowing background validation.

## 5. Chat List and Dashboard Flow

The chat dashboard is intentionally offline-friendly.

### Data source order

1. Cached local data is read first.
2. The UI renders cached rooms and friends immediately.
3. Network refresh runs in the background.
4. New data replaces or updates the local cache.
5. The UI rebuilds once providers notify listeners.

### What the user sees

- If cache exists, the dashboard appears immediately.
- If cache does not exist, the screen shows a visible loading state.
- If a background refresh is in progress, a small progress indicator can appear without blocking the UI.

This prevents the blank dashboard hang that would otherwise happen when the app waits for the network before painting anything.

## 6. Chat Screen Flow

The chat screen uses both local cache and realtime updates.

### Load order for messages

1. The screen opens with a `roomId` and chat metadata.
2. Cached messages are loaded from Hive or the message persistence service.
3. The message list is shown immediately.
4. `ChatProvider` fetches newer messages from the backend.
5. `SocketService` listens for new realtime events.
6. Incoming messages are persisted first, then emitted to the UI.

### Realtime message flow

1. A user sends a message from the chat screen.
2. The message goes through the socket or API layer.
3. The backend stores the message.
4. The backend broadcasts updates to participants.
5. The client receives the event through WebSocket.
6. The message is written to local storage.
7. The provider notifies the screen.
8. The UI updates immediately.

### Pull-to-refresh

The chat screen supports refresh to fetch the latest server state directly.

That is important for:

- missed socket events
- reconnect scenarios
- group membership changes
- message ordering corrections

## 7. Message Persistence Flow

The app stores data locally so it can render content before the network finishes.

### Storage responsibilities

- `HiveTokenStorage` stores auth tokens and derives the current user id.
- `ChatPersistenceService` stores messages.
- `FriendPersistenceService` stores friend list data.
- Other cache services store user-scoped room data.

### Why user-scoped storage matters

The current user id is used as a namespace so one account does not read another account's cache on the same device.

### Message persistence order

1. Message event arrives.
2. The message is stored locally first.
3. The provider receives the event or refreshes from cache.
4. The UI uses the local copy for display.

This makes the app resilient to reconnects and slow networks.

## 7.1 Unseen / Seen (Read Receipts)

This project implements a lightweight "seen/unseen" mechanism so users can tell whether messages have been read. Below is the complete flow and considerations implemented in the codebase.

Client-side behavior

1. New messages are created with an unread state (server `is_read` = false).
2. When a recipient opens a room or the chat list, the client may mark messages as read:
	- The UI typically marks messages as read when the messages are visible to the user (for example, when the chat screen is opened and the messages are scrolled into view).
	- The client calls the server read endpoint (e.g. `ApiConstant.readRoom(roomId)`), or uses the socket read event where available.
	- To keep UX snappy, the client may optimistically update the local messages (set them as `isRead = true`) and persist that change in Hive via the `ChatPersistenceService`.
3. After the server confirms the read operation, the client persists any authoritative changes and notifies `ChatProvider` so the UI updates (unread badges, per-room unread counts, and message state).
4. If the app is offline, the client records the read intent locally and queues the read request to be sent when network connectivity is restored. The local store is the source for immediate UI state.

Server-side behavior

1. The backend endpoint that marks a room as read updates the `Message` rows (or the per-user read-tracking row if implemented) so subsequent queries return `is_read = true` for messages matching the criteria.
2. The backend then broadcasts a read event via Channels/WebSocket to other room participants so their clients can update the message state and unread counts in near-real-time.
3. The server-side implementation in this repo currently uses a global `is_read` flag on messages in simpler flows (see the Django `Message` model). For production-grade read receipts you typically need a per-user read status table so each recipient has their own read marker.

Data flow summary (read event)

- UI detects the user has viewed the message(s) → calls client read handler.
- Client optimistically updates local persistence and UI (Hive write via `ChatPersistenceService`).
- Client sends REST (or socket) read request to backend (`/rooms/<roomId>/read/`).
- Backend updates DB and broadcasts a read event to the room via Channels.
- Other clients receive the read event and update their local stores and UI.

How unread counts are computed

- The chat list and room summaries derive unread counts from messages where `is_read` is false for the current user. In this repository you can trace the logic across `ChatController`, `ChatPersistenceService`, and `ChatProvider` which aggregate unread messages per room.
- When a local optimistic mark-as-read happens, the UI uses the local store to drop the badge immediately; the server confirmation is used to ensure eventual consistency.

Edge cases & important notes

- Race conditions: marking read and incoming new messages can race. The client persists events in timestamp order and uses the backend timestamp as authority when available.
- Multi-device: If the same account is logged in on multiple devices, marking messages read on one device should propagate to others via server broadcast.
- Offline behavior: optimistic marking improves perceived responsiveness but requires reconciliation on reconnection (server wins when timestamps differ).
- Privacy/E2EE: in an E2EE design you may not send plaintext read receipts to the server; design must consider privacy and encryption constraints.

Files to review for implementation

- `flutter/lib/services/storage/chat_persistence_service.dart` — message persistence and local updates.
- `flutter/lib/providers/chat_provider.dart` — high-level operations that handle mark-as-read and refresh flows.
- `flutter/lib/services/api_service.dart` and `flutter/lib/constants/api_constant.dart` — REST endpoints including the room read route.
- `backend_core/chat_project/chat_app/views.py` — server endpoints and WebSocket handlers that update message read state and broadcast read events.


## 8. Notification Flow

Push notification handling is managed by `NotificationService`.

### What the service does

1. Initializes Firebase Messaging.
2. Reads the local notification preference.
3. Requests permission when notifications are enabled.
4. Registers the device token with the backend.
5. Refreshes backend token registration when FCM rotates the token.
6. Deletes or unregisters the token on logout.

### Current notification data path

1. Flutter creates a device token through Firebase Messaging.
2. `NotificationService.syncToken()` sends that token to Django.
3. Django stores the token in `FCMDevice`.
4. When the backend sends a push event, it targets all active devices for the recipient.
5. The app receives the push and can refresh local state.

### Why notifications may fail

Typical failure points are:

- Firebase was not initialized successfully.
- The user denied notification permission.
- The token was never registered with the backend.
- The backend device record is inactive.
- The app is logged out, so the token gets unregistered.

### Profile toggle behavior

The profile screen now owns the user-facing enable/disable control. When disabled:

- the preference is stored locally,
- Firebase auto-init is turned off,
- the backend token is unregistered,
- the local FCM token is deleted.

When enabled again:

- the app requests permission,
- the preference is updated,
- the token is re-registered if permission is granted.

## 9. Backend Push Flow

The backend push path is in the Django app.

### Device registration

1. Flutter sends `registration_id` and platform type to `/api/v1/devices/register/`.
2. Django creates or updates an `FCMDevice` record.
3. The device is marked active for that user.

### Message push

1. A chat message is created on the backend.
2. The consumer or message handler calls `send_new_message_push()`.
3. The helper finds all active devices for room participants except the sender.
4. Firebase sends a data-only payload to those devices.
5. The client uses the event to refresh or update the conversation.

### Logout cleanup

1. Flutter calls the unregister endpoint.
2. Django marks the device inactive.
3. Future pushes skip that device.

## 10. Group Membership Updates

Group membership changes also flow through the system as messages.

### Flow

1. A user adds or removes a member from a group.
2. Django creates a readable system message for the membership change.
3. Flutter refreshes the conversation after the action completes.
4. The refreshed messages include the system event.
5. The chat UI shows the update in the conversation history.

This keeps the membership change visible in the same timeline as the rest of the conversation.

## 11. Error and Session Expiry Flow

The app has a few explicit failure paths.

### Session expired

If the backend says the session is invalid:

1. The unauthorized handler is triggered.
2. `AuthProvider.handleSessionExpired()` clears local auth state.
3. Local scoped data is cleaned up.
4. The router redirects the user to auth.

### Notification sync failure

If token sync fails:

- the app logs the failure,
- the UI is not blocked,
- the user can continue using the app,
- the next login or enable action can retry registration.

## 12. End-to-End Summary

The project uses a layered flow:

- UI screens collect input and render state.
- Providers own screen state and orchestration.
- Services handle REST, WebSocket, Hive, and Firebase Messaging.
- Django stores the source of truth.
- Hive keeps a local cache so the app can show data immediately.

The most important design choice is that the app does not wait for the network before showing useful UI. It loads cached state first, validates in the background, and keeps realtime and push channels in sync with the backend.
