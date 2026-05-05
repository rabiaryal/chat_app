"""
Serializers for the chat application.
"""

from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model
from .models import ChatRoom, Message, AIResponse, Friendship

User = get_user_model()


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """
    Custom token serializer that includes user information.
    """
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token['email'] = user.email
        token['username'] = user.username
        token['user_id'] = user.id
        return token


class UserSerializer(serializers.ModelSerializer):
    """
    Serializer for user information.
    """
    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'first_name', 'last_name', 'avatar', 'bio', 'is_online', 'last_seen')
        read_only_fields = ('id', 'last_seen')


class UserRegistrationSerializer(serializers.ModelSerializer):
    """
    Serializer for user registration.
    """
    password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ('username', 'email', 'password', 'password_confirm', 'first_name', 'last_name')

    def validate(self, data):
        if data['password'] != data.pop('password_confirm'):
            raise serializers.ValidationError({'password': 'Passwords do not match'})
        if User.objects.filter(email=data['email']).exists():
            raise serializers.ValidationError({'email': 'Email already exists'})
        return data

    def create(self, validated_data):
        user = User.objects.create_user(**validated_data)
        return user


class MessageSerializer(serializers.ModelSerializer):
    """
    Serializer for messages.
    """
    sender_username = serializers.CharField(source='sender.username', read_only=True)
    ai_response = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = ('id', 'room', 'sender', 'sender_username', 'content', 'message_type', 'file', 'is_read', 'created_at', 'ai_response')
        read_only_fields = ('id', 'created_at')

    def get_ai_response(self, obj):
        if hasattr(obj, 'ai_response'):
            return {
                'response_text': obj.ai_response.response_text,
                'model_used': obj.ai_response.model_used,
            }
        return None


class ChatRoomSerializer(serializers.ModelSerializer):
    """
    Serializer for chat rooms.
    """
    participants_count = serializers.SerializerMethodField()
    creator_username = serializers.CharField(source='creator.username', read_only=True)

    class Meta:
        model = ChatRoom
        fields = ('id', 'name', 'description', 'room_type', 'participants_count', 'creator', 'creator_username', 'is_active', 'created_at', 'updated_at')
        read_only_fields = ('id', 'created_at', 'updated_at')

    def get_participants_count(self, obj):
        return obj.participants.count()


class ChatRoomDetailSerializer(ChatRoomSerializer):
    """
    Detailed serializer for chat rooms including messages.
    """
    participants = UserSerializer(many=True, read_only=True)
    messages = MessageSerializer(many=True, read_only=True)

    class Meta:
        model = ChatRoom
        fields = ChatRoomSerializer.Meta.fields + ('participants', 'messages')


class FriendshipSerializer(serializers.ModelSerializer):
    """
    Serializer for friendship relationships.
    """
    from_user_data = UserSerializer(source='from_user', read_only=True)
    to_user_data = UserSerializer(source='to_user', read_only=True)

    class Meta:
        model = Friendship
        fields = ('id', 'from_user', 'to_user', 'from_user_data', 'to_user_data', 'status', 'created_at', 'updated_at')
        read_only_fields = ('id', 'created_at', 'updated_at')


class FriendshipListSerializer(serializers.ModelSerializer):
    """
    Simplified serializer for listing friendships.
    """
    friend = serializers.SerializerMethodField()

    class Meta:
        model = Friendship
        fields = ('id', 'friend', 'status', 'created_at')

    def get_friend(self, obj):
        """Return the other user in the friendship."""
        request_user = self.context.get('request').user if self.context.get('request') else None
        if request_user == obj.from_user:
            return UserSerializer(obj.to_user).data
        return UserSerializer(obj.from_user).data
