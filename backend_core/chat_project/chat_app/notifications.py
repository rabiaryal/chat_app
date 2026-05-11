"""Push notification helpers for chat events."""

import logging

from fcm_django.models import FCMDevice
from firebase_admin.messaging import Message

from .models import ChatRoom

logger = logging.getLogger(__name__)


def send_new_message_push(*, room_id: str, sender_id: int, sender_username: str, message_type: str = 'TEXT') -> int:
    """
    Send an E2EE-safe data-only push notification to room participants except sender.
    Returns number of targeted devices.
    """
    try:
        room = ChatRoom.objects.prefetch_related('participants').get(id=room_id)
    except ChatRoom.DoesNotExist:
        return 0

    recipient_ids = list(
        room.participants.exclude(id=sender_id).values_list('id', flat=True)
    )
    if not recipient_ids:
        return 0

    devices = FCMDevice.objects.filter(user_id__in=recipient_ids, active=True)
    if not devices.exists():
        return 0

    payload = {
        'event': 'new_message',
        'room_id': str(room_id),
        'sender_id': str(sender_id),
        'sender_username': sender_username,
        'message_type': message_type,
        # Client should fetch/decrypt content locally for E2EE safety
        'silent': '1',
    }

    try:
        # Construct a firebase Message with data payload and send via fcm-django
        msg = Message(data=payload)
        devices.send_message(msg)
        return devices.count()
    except Exception as exc:
        logger.exception('Failed to send FCM push for room %s: %s', room_id, exc)
        return 0
