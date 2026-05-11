# Project Status & Features

This document tracks the current implementation status and features of the Chat App.

## Implemented Features

### 1. Messaging
- [x] Real-time 1-on-1 and Group chats.
- [x] "Seen/Unseen" read receipts (Double blue checkmarks).
- [x] Typing indicators ("X is typing...").
- [x] Message history with Hive caching.
- [x] Automatic scrolling and message sorting.

### 2. User & Friends
- [x] JWT Authentication with automatic token refresh.
- [x] Friend search and request system.
- [x] Suggested friends.
- [x] Profile management (Me vs Friend profiles).
- [x] Online/Offline status indicators.

### 3. Group Chat
- [x] Group creation with multiple participants.
- [x] Dynamic member management (Add/Remove members).
- [x] Group membership synchronization for users added later.

## Pending / Future Work
- [ ] Media sharing (Images, Files).
- [ ] End-to-End Encryption (E2EE) - Initial infrastructure present but needs finalization.
- [ ] Message reactions.
- [ ] User bio/status updates.
- [ ] Voice/Video calls.

## Development Notes
- **Hot Reloading**: Backend supports automatic restart on file changes (via `docker-compose restart django`).
- **Debugging**: Flutter logs use symbols like `✓`, `✗`, `📡`, and `🔐` for easy scanning in the console.
