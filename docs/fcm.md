# Push Notifications (FCM)

The application uses **Firebase Cloud Messaging (FCM)** to deliver push notifications for new messages when the app is in the background or closed.

## Frontend Setup
- **Service**: `lib/services/notification_service.dart`.
- **Initialization**: Requests permissions and obtains a device token.
- **Listeners**:
  - `onMessage`: Handles notifications when the app is in the foreground.
  - `onMessageOpenedApp`: Handles user interaction with a notification.
  - `onBackgroundMessage`: Handles notifications when the app is closed.

## Device Registration
1. Upon login/startup, the app gets the FCM token.
2. It sends the token to the backend via `/api/v1/devices/register/`.
3. The backend associates this token with the user's session.

## Backend Integration
- **Mechanism**: When a `Message` is saved in the database, a post-save signal or the consumer triggers a notification.
- **Targeting**: The server looks up all registered device tokens for the room's participants (excluding the sender) and sends the payload via Firebase Admin SDK.

## Key Files
- **Backend**: `chat_app/push_notifications.py` (assumed helper).
- **Frontend**: `lib/services/notification_service.dart`.
