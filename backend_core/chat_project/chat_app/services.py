"""
Service helpers for chat and friendship workflows.
"""

import uuid

from django.db import transaction

from .models import ChatRoom, Friendship, Message


class ChatService:
    @staticmethod
    def dm_room_id(user1_id, user2_id):
        low_id, high_id = sorted([int(user1_id), int(user2_id)])
        return f'dm_{low_id}_{high_id}'

    @staticmethod
    def get_or_create_dm_room(user1, user2):
        room_id = ChatService.dm_room_id(user1.id, user2.id)

        with transaction.atomic():
            room, created = ChatRoom.objects.get_or_create(
                id=room_id,
                defaults={
                    'name': f'{user1.username} & {user2.username}',
                    'description': f'Direct message between {user1.username} and {user2.username}',
                    'room_type': ChatRoom.RoomType.DM,
                    'creator': user1,
                },
            )
            room.participants.add(user1, user2)

        return room, created

    @staticmethod
    def create_group_room(creator, name, description='', participant_ids=None):
        participant_ids = participant_ids or []

        with transaction.atomic():
            room = ChatRoom.objects.create(
                id=str(uuid.uuid4()),
                name=name,
                description=description,
                room_type=ChatRoom.RoomType.GROUP,
                creator=creator,
            )
            room.participants.add(creator)

            return room, participant_ids

    @staticmethod
    def accept_friendship(friendship, accepted_by_user):
        with transaction.atomic():
            friendship.status = Friendship.Status.ACCEPTED
            friendship.save(update_fields=['status', 'updated_at'])

            room, _ = ChatService.get_or_create_dm_room(friendship.from_user, friendship.to_user)

            Message.objects.create(
                id=str(uuid.uuid4()),
                room=room,
                sender=accepted_by_user,
                content=f'You are now friends! Say hi to {accepted_by_user.username} 👋',
                message_type=Message.MessageType.TEXT,
                is_read=False,
            )

        return room