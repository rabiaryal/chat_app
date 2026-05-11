import os
import sys

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'chat_project.settings')

import django
django.setup()

from django.contrib.auth import get_user_model
from fcm_django.models import FCMDevice

User = get_user_model()
user = User.objects.first()
print('user', getattr(user, 'id', None))

d = FCMDevice.objects.create(
    user=user,
    registration_id='TEST_REG_ID_123',
    active=True,
    type='android',
)
print('device created', d.id)

try:
    res = d.send_message(data={'event': 'test', 'msg': 'hello'})
    print('send_result', res)
except Exception as exc:
    import traceback
    traceback.print_exc()
    print('send_error', exc)
