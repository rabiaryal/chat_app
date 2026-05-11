import os
import sys

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'chat_project.settings')

import django
django.setup()

from django.contrib.auth import get_user_model
from fcm_django.models import FCMDevice
from firebase_admin.messaging import Message

User = get_user_model()
user = User.objects.first()
print('user', getattr(user, 'id', None))

d, created = FCMDevice.objects.update_or_create(
    registration_id='TEST_REG_ID_123',
    defaults={
        'user': user,
        'active': True,
        'type': 'android',
    },
)
print('device', d.id, 'created?' , created)

try:
    msg = Message(data={'event': 'test', 'msg': 'hello'})
    res = d.send_message(msg)
    print('send_result', res)
except Exception as exc:
    import traceback
    traceback.print_exc()
    print('send_error', exc)
