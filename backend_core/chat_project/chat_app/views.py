"""
Views for the chat application.
"""

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from rest_framework_simplejwt.tokens import RefreshToken
from drf_spectacular.utils import extend_schema
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import make_password
from django.db import models
from .models import ChatRoom, Message, Friendship, UserPublicKey
from .serializers import (
    CustomTokenObtainPairSerializer,
    UserSerializer,
    UserRegistrationSerializer,
    ChatRoomSerializer,
    ChatRoomDetailSerializer,
    MessageSerializer,
    FriendshipSerializer,
    FriendshipListSerializer,
    LoginSerializer,
    LogoutSerializer,
    ChangePasswordSerializer,
    TokenResponseSerializer,
    UserPublicKeySerializer,
)

User = get_user_model()


class CustomTokenObtainPairView(TokenObtainPairView):
    """
    Custom token obtain pair view that includes additional user information.
    """
    serializer_class = CustomTokenObtainPairSerializer
    permission_classes = [AllowAny]


class RegisterView(APIView):
    """
    Register a new user and return access/refresh tokens.
    POST: {username, email, password, password_confirm, first_name?, last_name?}
    Returns: {user, access, refresh}
    """
    serializer_class = UserRegistrationSerializer
    permission_classes = [AllowAny]

    @extend_schema(
        request=UserRegistrationSerializer,
        responses={201: TokenResponseSerializer},
        description='Register a new user account'
    )
    def post(self, request):
        serializer = UserRegistrationSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            
            # Generate tokens for the new user
            refresh = RefreshToken.for_user(user)
            
            return Response(
                {
                    'message': 'User registered successfully',
                    'user': {
                        'id': user.id,
                        'username': user.username,
                        'email': user.email,
                        'first_name': user.first_name,
                        'last_name': user.last_name,
                    },
                    'access': str(refresh.access_token),
                    'refresh': str(refresh),
                },
                status=status.HTTP_201_CREATED
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class LoginView(APIView):
    """
    Login and return access/refresh tokens.
    POST: {username, password}
    Returns: {user, access, refresh}
    """
    serializer_class = LoginSerializer
    permission_classes = [AllowAny]

    @extend_schema(
        request=LoginSerializer,
        responses={200: TokenResponseSerializer},
        description='Login with username and password to get tokens'
    )
    def post(self, request):
        username = request.data.get('username')
        password = request.data.get('password')
        
        if not username or not password:
            return Response(
                {'error': 'Username and password are required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            return Response(
                {'error': 'Invalid credentials'},
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        # Check password
        if not user.check_password(password):
            return Response(
                {'error': 'Invalid credentials'},
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        # Generate tokens
        refresh = RefreshToken.for_user(user)
        
        return Response(
            {
                'message': 'Login successful',
                'user': {
                    'id': user.id,
                    'username': user.username,
                    'email': user.email,
                    'first_name': user.first_name,
                    'last_name': user.last_name,
                },
                'access': str(refresh.access_token),
                'refresh': str(refresh),
            },
            status=status.HTTP_200_OK
        )


class LogoutView(APIView):
    """
    Logout and invalidate refresh token.
    POST: {refresh} (optional - if not provided, just clears the token)
    Returns: {message}
    """
    serializer_class = LogoutSerializer
    permission_classes = [IsAuthenticated]

    @extend_schema(
        request=LogoutSerializer,
        responses={200: TokenResponseSerializer},
        description='Logout and blacklist refresh token'
    )
    def post(self, request):
        try:
            refresh_token = request.data.get('refresh')
            
            # Try to blacklist the token if provided
            if refresh_token:
                try:
                    token = RefreshToken(refresh_token)
                    token.blacklist()
                    print(f'✓ Refresh token blacklisted for user {request.user.username}')
                except Exception as token_error:
                    # Token might be expired or invalid, but that's ok
                    print(f'⚠ Token blacklist failed (token may be expired): {token_error}')
            else:
                print(f'⚠ No refresh token provided, but logout allowed (user: {request.user.username})')
            
            return Response(
                {'message': 'Logout successful'},
                status=status.HTTP_200_OK
            )
        except Exception as e:
            # Even if something fails, we allow logout
            print(f'✗ Logout error: {e}')
            return Response(
                {'message': 'Logout successful (partial)'},
                status=status.HTTP_200_OK
            )


class ChangePasswordView(APIView):
    """
    Change user password.
    POST: {old_password, new_password, new_password_confirm}
    Returns: {message}
    """
    serializer_class = ChangePasswordSerializer
    permission_classes = [IsAuthenticated]

    @extend_schema(
        request=ChangePasswordSerializer,
        responses={200: TokenResponseSerializer},
        description='Change the current user password'
    )
    def post(self, request):
        user = request.user
        old_password = request.data.get('old_password')
        new_password = request.data.get('new_password')
        new_password_confirm = request.data.get('new_password_confirm')
        
        # Validate required fields
        if not all([old_password, new_password, new_password_confirm]):
            return Response(
                {'error': 'All fields are required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Verify old password
        if not user.check_password(old_password):
            return Response(
                {'error': 'Old password is incorrect'},
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        # Check passwords match
        if new_password != new_password_confirm:
            return Response(
                {'error': 'New passwords do not match'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Validate password strength
        if len(new_password) < 8:
            return Response(
                {'error': 'Password must be at least 8 characters'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Update password
        user.set_password(new_password)
        user.save()
        
        return Response(
            {'message': 'Password changed successfully'},
            status=status.HTTP_200_OK
        )


class CustomTokenRefreshView(TokenRefreshView):
    """
    Refresh access token using refresh token.
    POST: {refresh}
    Returns: {access}
    """
    permission_classes = [AllowAny]


class UserMeView(APIView):
    """
    Get current user profile information.
    GET: Returns user details
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """
        Retrieve current user information.
        """
        user = request.user
        data = {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'is_online': getattr(user, 'is_online', False),
            'last_seen': getattr(user, 'last_seen', None),
        }
        return Response(data, status=status.HTTP_200_OK)


class UserDeleteView(APIView):
    """
    Delete user account and all associated data.
    DELETE: Requires authentication
    """
    permission_classes = [IsAuthenticated]

    def delete(self, request):
        """
        Delete the current user's account and all associated data.
        """
        try:
            user = request.user
            username = user.username
            
            # Delete user (this will cascade delete related data like messages, chat rooms, etc.)
            user.delete()
            
            return Response(
                {
                    'message': f'User account "{username}" has been deleted successfully',
                    'user': username
                },
                status=status.HTTP_200_OK
            )
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )


class SuggestedFriendsView(APIView):
    """
    Get suggested friends (users who are not friends and have no pending requests).
    Supports pagination with ?page=1&limit=5
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            page = int(request.query_params.get('page', 1))
            limit = int(request.query_params.get('limit', 5))
        except ValueError:
            page = 1
            limit = 5
            
        page = max(1, page)
        limit = max(1, min(limit, 50))
        offset = (page - 1) * limit

        # Get IDs of users who are already friends or have pending requests
        from django.db.models import Q
        friendships = Friendship.objects.filter(
            Q(from_user=request.user) | Q(to_user=request.user)
        )
        
        exclude_ids = set([request.user.id])
        for f in friendships:
            exclude_ids.add(f.from_user_id)
            exclude_ids.add(f.to_user_id)
            
        # Get random users not in exclude list
        # We slice from offset to offset+limit
        users = User.objects.exclude(id__in=exclude_ids).order_by('?')[offset:offset+limit]
        
        results = [
            {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'is_online': getattr(user, 'is_online', False),
            }
            for user in users
        ]
        
        return Response(
            {
                'results': results, 
                'count': len(results),
                'page': page,
                'limit': limit
            },
            status=status.HTTP_200_OK
        )


class UserSearchView(APIView):
    """
    Search for users by username.
    Returns top 5 matching results.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """
        Search users by username query parameter.
        Query param: ?search=<username> or ?q=<username>
        """
        search_query = request.query_params.get('search') or request.query_params.get('q')
        
        if not search_query or len(search_query) < 1:
            return Response(
                {'error': 'Please provide a search query (min 1 character)'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Search for users by username (case-insensitive, partial match)
        users = User.objects.filter(
            username__icontains=search_query
        ).exclude(
            id=request.user.id  # Exclude current user
        )[:5]  # Limit to 5 results
        
        if not users.exists():
            return Response(
                {'results': [], 'count': 0},
                status=status.HTTP_200_OK
            )
        
        results = [
            {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'is_online': getattr(user, 'is_online', False),
            }
            for user in users
        ]
        
        return Response(
            {'results': results, 'count': len(results)},
            status=status.HTTP_200_OK
        )


class RoomsListView(APIView):
    """
    List all chat rooms the current user is in.
    GET: Returns list of rooms
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """
        Get all chat rooms for the current user.
        """
        rooms = ChatRoom.objects.filter(participants=request.user).prefetch_related('participants')
        
        results = [
            {
                'id': room.id,
                'name': room.name,
                'description': room.description,
                'room_type': room.room_type,
                'creator_id': room.creator.id,
                'creator_username': room.creator.username,
                'participants_count': room.participants.count(),
                'is_active': room.is_active,
                'created_at': room.created_at,
                'updated_at': room.updated_at,
            }
            for room in rooms
        ]
        
        return Response(
            {'results': results, 'count': len(results)},
            status=status.HTTP_200_OK
        )

    def post(self, request):
        """
        Create a new chat room (direct message or group).
        """
        name = request.data.get('name')
        room_type = request.data.get('room_type', 'DM')  # 'DM' or 'GROUP'
        description = request.data.get('description', '')
        participant_ids = request.data.get('participant_ids', [])
        
        # Validate required fields
        if not name:
            return Response(
                {'error': 'Room name is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if room_type not in ['DM', 'GROUP']:
            return Response(
                {'error': 'room_type must be either "DM" or "GROUP"'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            import uuid
            room = ChatRoom.objects.create(
                id=str(uuid.uuid4()),
                name=name,
                description=description,
                room_type=room_type,
                creator=request.user,
            )
            
            # Add creator as participant
            room.participants.add(request.user)
            
            # Add other participants
            if participant_ids:
                participants = User.objects.filter(id__in=participant_ids)
                room.participants.add(*participants)
            
            return Response(
                {
                    'message': 'Room created successfully',
                    'room': {
                        'id': room.id,
                        'name': room.name,
                        'description': room.description,
                        'room_type': room.room_type,
                        'creator_id': room.creator.id,
                        'participants_count': room.participants.count(),
                    }
                },
                status=status.HTTP_201_CREATED
            )
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )


class GroupCreateView(APIView):
    """
    Create a new group chat.
    POST: { "name": "...", "description": "...", "participant_ids": [1, 2] }
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        name = request.data.get('name')
        description = request.data.get('description', '')
        participant_ids = request.data.get('participant_ids', [])

        if not name:
            return Response(
                {'error': 'Group name is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            import uuid
            room = ChatRoom.objects.create(
                id=str(uuid.uuid4()),
                name=name,
                description=description,
                room_type='GROUP',
                creator=request.user,
            )

            # Add creator as participant
            room.participants.add(request.user)

            # Add other participants
            if participant_ids:
                participants = User.objects.filter(id__in=participant_ids)
                room.participants.add(*participants)

            return Response(
                {
                    'message': 'Group created successfully',
                    'room': {
                        'id': room.id,
                        'name': room.name,
                        'description': room.description,
                        'room_type': room.room_type,
                        'creator_id': room.creator.id,
                        'participants_count': room.participants.count(),
                        'created_at': room.created_at.isoformat(),
                        'updated_at': room.updated_at.isoformat(),
                    }
                },
                status=status.HTTP_201_CREATED
            )
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )


class RoomDetailView(APIView):
    """
    Get room details and member list, or delete a room.
    GET: Returns room details and members
    DELETE: Delete room (creator/admin only)
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, room_id):
        """
        Get room details and member list.
        """
        try:
            room = ChatRoom.objects.get(id=room_id)
            
            # Check if user is part of the room
            if not room.participants.filter(id=request.user.id).exists():
                return Response(
                    {'error': 'You are not a member of this room'},
                    status=status.HTTP_403_FORBIDDEN
                )
            
            participants = [
                {
                    'id': user.id,
                    'username': user.username,
                    'email': user.email,
                    'first_name': user.first_name,
                    'last_name': user.last_name,
                    'is_online': user.is_online,
                }
                for user in room.participants.all()
            ]
            
            return Response(
                {
                    'id': room.id,
                    'name': room.name,
                    'description': room.description,
                    'room_type': room.room_type,
                    'creator_id': room.creator.id,
                    'creator_username': room.creator.username,
                    'participants': participants,
                    'participants_count': room.participants.count(),
                    'is_active': room.is_active,
                    'created_at': room.created_at,
                    'updated_at': room.updated_at,
                },
                status=status.HTTP_200_OK
            )
        except ChatRoom.DoesNotExist:
            return Response(
                {'error': 'Room not found'},
                status=status.HTTP_404_NOT_FOUND
            )


class RoomMessagesView(APIView):
    """Return recent messages for a room."""
    permission_classes = [IsAuthenticated]

    def get(self, request, room_id):
        try:
            room = ChatRoom.objects.get(id=room_id)
        except ChatRoom.DoesNotExist:
            return Response({'error': 'Room not found'}, status=status.HTTP_404_NOT_FOUND)

        if not room.participants.filter(id=request.user.id).exists():
            return Response({'error': 'You are not a member of this room'}, status=status.HTTP_403_FORBIDDEN)

        try:
            limit = int(request.query_params.get('limit', 20))
        except (TypeError, ValueError):
            limit = 20

        limit = max(1, min(limit, 100))

        messages = (
            Message.objects.filter(room=room)
            .select_related('sender', 'room')
            .order_by('-created_at')[:limit]
        )

        serializer = MessageSerializer(messages, many=True)
        return Response(list(reversed(serializer.data)), status=status.HTTP_200_OK)

    def delete(self, request, room_id):
        """
        Delete a room (creator/admin only).
        """
        try:
            room = ChatRoom.objects.get(id=room_id)
            
            # Check if user is the creator
            if room.creator.id != request.user.id:
                return Response(
                    {'error': 'Only room creator can delete the room'},
                    status=status.HTTP_403_FORBIDDEN
                )
            
            room_name = room.name
            room.delete()
            
            return Response(
                {'message': f'Room "{room_name}" deleted successfully'},
                status=status.HTTP_200_OK
            )
        except ChatRoom.DoesNotExist:
            return Response(
                {'error': 'Room not found'},
                status=status.HTTP_404_NOT_FOUND
            )


class RoomMembersView(APIView):
    """
    Add or remove members from a room.
    POST: Add member
    DELETE: Remove member or leave room
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, room_id):
        """
        Add a member to the room.
        """
        try:
            room = ChatRoom.objects.get(id=room_id)
            
            # Check if user is part of the room
            if not room.participants.filter(id=request.user.id).exists():
                return Response(
                    {'error': 'You are not a member of this room'},
                    status=status.HTTP_403_FORBIDDEN
                )
            
            # For group chats, need to be creator or have permission
            if room.room_type == 'GROUP' and room.creator.id != request.user.id:
                return Response(
                    {'error': 'Only group creator can add members'},
                    status=status.HTTP_403_FORBIDDEN
                )
            
            user_id = request.data.get('user_id')
            if not user_id:
                return Response(
                    {'error': 'user_id is required'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            try:
                user_to_add = User.objects.get(id=user_id)
            except User.DoesNotExist:
                return Response(
                    {'error': 'User not found'},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Check if user is already in room
            if room.participants.filter(id=user_id).exists():
                return Response(
                    {'error': 'User is already a member of this room'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            room.participants.add(user_to_add)
            
            return Response(
                {
                    'message': f'User "{user_to_add.username}" added to room',
                    'user': {
                        'id': user_to_add.id,
                        'username': user_to_add.username,
                    }
                },
                status=status.HTTP_200_OK
            )
        except ChatRoom.DoesNotExist:
            return Response(
                {'error': 'Room not found'},
                status=status.HTTP_404_NOT_FOUND
            )

    def delete(self, request, room_id, user_id=None):
        """
        Remove a member from the room or leave room.
        If user_id is provided, remove that user (creator only for groups).
        If not provided, remove current user (leave room).
        """
        try:
            room = ChatRoom.objects.get(id=room_id)
            
            # Determine which user to remove
            if user_id:
                # Remove specific user (creator only for groups)
                if room.room_type == 'GROUP' and room.creator.id != request.user.id:
                    return Response(
                        {'error': 'Only group creator can remove members'},
                        status=status.HTTP_403_FORBIDDEN
                    )
                try:
                    user_to_remove = User.objects.get(id=user_id)
                except User.DoesNotExist:
                    return Response(
                        {'error': 'User not found'},
                        status=status.HTTP_404_NOT_FOUND
                    )
            else:
                # Current user leaving the room
                user_to_remove = request.user
            
            # Check if user is in room
            if not room.participants.filter(id=user_to_remove.id).exists():
                return Response(
                    {'error': 'User is not a member of this room'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            room.participants.remove(user_to_remove)
            
            return Response(
                {
                    'message': f'User "{user_to_remove.username}" removed from room',
                    'user': {
                        'id': user_to_remove.id,
                        'username': user_to_remove.username,
                    }
                },
                status=status.HTTP_200_OK
            )
        except ChatRoom.DoesNotExist:
            return Response(
                {'error': 'Room not found'},
                status=status.HTTP_404_NOT_FOUND
            )



class UserViewSet(viewsets.ModelViewSet):
    """
    ViewSet for user management.
    """
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=['get'])
    def me(self, request):
        """
        Get current user profile.
        """
        serializer = UserSerializer(request.user)
        return Response(serializer.data)

    @action(detail=False, methods=['put', 'patch'])
    def profile_update(self, request):
        """
        Update current user profile.
        """
        serializer = UserSerializer(request.user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['get'])
    def list_users(self, request):
        """
        List all users (for friend discovery).
        """
        users = User.objects.exclude(id=request.user.id)
        serializer = UserSerializer(users, many=True)
        return Response(serializer.data)


class ChatRoomViewSet(viewsets.ModelViewSet):
    """
    ViewSet for chat room management.
    """
    queryset = ChatRoom.objects.all()
    serializer_class = ChatRoomSerializer
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        """
        Return the appropriate serializer based on the action.
        """
        if self.action == 'retrieve':
            return ChatRoomDetailSerializer
        return ChatRoomSerializer

    def get_queryset(self):
        """
        Return chat rooms for the current user.
        """
        return ChatRoom.objects.filter(participants=self.request.user)

    def perform_create(self, serializer):
        """
        Create a new chat room with the current user as creator.
        """
        chat_room = serializer.save(creator=self.request.user)
        chat_room.participants.add(self.request.user)

    @action(detail=True, methods=['post'])
    def add_participant(self, request, pk=None):
        """
        Add a participant to a chat room.
        """
        chat_room = self.get_object()
        user_id = request.data.get('user_id')
        
        try:
            user = User.objects.get(id=user_id)
            chat_room.participants.add(user)
            return Response({'message': 'User added successfully'})
        except User.DoesNotExist:
            return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'])
    def remove_participant(self, request, pk=None):
        """
        Remove a participant from a chat room.
        """
        chat_room = self.get_object()
        user_id = request.data.get('user_id')
        
        try:
            user = User.objects.get(id=user_id)
            chat_room.participants.remove(user)
            return Response({'message': 'User removed successfully'})
        except User.DoesNotExist:
            return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)


class MessageViewSet(viewsets.ModelViewSet):
    """
    ViewSet for message management.
    """
    queryset = Message.objects.all()
    serializer_class = MessageSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        """
        Return messages for chat rooms the user participates in.
        """
        return Message.objects.filter(room__participants=self.request.user)

    def perform_create(self, serializer):
        """
        Create a new message with the current user as sender.
        """
        serializer.save(sender=self.request.user)

    @action(detail=True, methods=['put'])
    def mark_as_read(self, request, pk=None):
        """
        Mark a message as read.
        """
        message = self.get_object()
        message.is_read = True
        message.save()
        return Response({'message': 'Message marked as read'})


# ============================================================================
# CORE: GET OR CREATE ROOM (1-to-1 Direct Messages)
# ============================================================================
class GetOrCreateRoomView(APIView):
    """
    Smart endpoint that finds or creates a 1-to-1 room between two users.
    
    This is the "persistent layer" that ensures:
    1. Database is the source of truth
    2. Two users can only have ONE direct message room
    3. Room IDs are consistent across sessions
    
    Sequence:
    1. Flutter calls: GET /api/room?target_user_id=<user_id>
    2. Django checks: Does room exist in database?
    3. If yes: Return room ID
    4. If no: Create room, return new ID
    5. Flutter connects: WebSocket to Django with room ID
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """
        Check if a room exists between current user and target user.
        
        Query params:
            - target_user_id: The user ID to get/create room with
            
        Returns:
            {
                'room_id': 'uuid-string',
                'created': True/False,
                'room_name': 'username1 & username2'
            }
        """
        target_user_id = request.query_params.get('target_user_id')
        
        if not target_user_id:
            return Response(
                {'error': 'target_user_id query parameter is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        current_user = request.user
        
        # Prevent user from creating room with themselves
        if int(target_user_id) == current_user.id:
            return Response(
                {'error': 'Cannot create room with yourself'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Check if target user exists
        try:
            target_user = User.objects.get(id=target_user_id)
        except User.DoesNotExist:
            return Response(
                {'error': 'Target user not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # **DATABASE IS TRUTH**: Query database for existing room
        # A DM room contains EXACTLY these 2 users
        existing_rooms = ChatRoom.objects.filter(
            room_type='DM',
            participants=current_user
        ).filter(
            participants=target_user
        )
        
        if existing_rooms.exists():
            # Room exists: return it (no creation)
            room = existing_rooms.first()
            return Response(
                {
                    'room_id': room.id,
                    'created': False,
                    'room_name': f"{current_user.username} & {target_user.username}",
                    'message': 'Room already exists'
                },
                status=status.HTTP_200_OK
            )
        
        # Room doesn't exist: create it
        import uuid
        room = ChatRoom.objects.create(
            id=str(uuid.uuid4()),
            name=f"{current_user.username} & {target_user.username}",
            room_type='DM',
            creator=current_user,
            description=f"Direct message between {current_user.username} and {target_user.username}"
        )
        
        # Add both users as participants
        room.participants.add(current_user, target_user)
        
        return Response(
            {
                'room_id': room.id,
                'created': True,
                'room_name': room.name,
                'message': 'Room created successfully'
            },
            status=status.HTTP_201_CREATED
        )

    def post(self, request):
        """
        Alternative POST endpoint to get_or_create room.
        Useful for consistency with RESTful patterns.
        
        Body:
            {
                'target_user_id': <user_id>
            }
        """
        target_user_id = request.data.get('target_user_id')
        
        # Reuse GET logic by creating a query params-like object
        request.query_params = type('obj', (object,), {'get': lambda self, key: target_user_id})()
        return self.get(request)


class FriendshipRequestView(APIView):
    """
    Send a friend request from current user to target user.
    POST: {target_user_id}
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        target_user_id = request.data.get('target_user_id')
        
        if not target_user_id:
            return Response(
                {'error': 'target_user_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        current_user = request.user
        
        # Prevent self-request
        if int(target_user_id) == current_user.id:
            return Response(
                {'error': 'Cannot send friend request to yourself'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Check if target user exists
        try:
            target_user = User.objects.get(id=target_user_id)
        except User.DoesNotExist:
            return Response(
                {'error': 'Target user not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Check if friendship already exists
        existing = Friendship.objects.filter(
            from_user=current_user,
            to_user=target_user
        ).first()
        
        if existing:
            return Response(
                {
                    'message': f'Friendship already exists with status: {existing.status}',
                    'status': existing.status
                },
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Create friendship request
        friendship = Friendship.objects.create(
            from_user=current_user,
            to_user=target_user,
            status='PENDING'
        )
        
        serializer = FriendshipSerializer(friendship)
        return Response(
            {
                'message': 'Friend request sent',
                'friendship': serializer.data
            },
            status=status.HTTP_201_CREATED
        )


class FriendshipAcceptView(APIView):
    """
    Accept a friend request.
    POST: {friendship_id}
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, friendship_id=None):
        friendship_id = friendship_id or request.data.get('friendship_id')
        
        if not friendship_id:
            return Response(
                {'error': 'friendship_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            friendship = Friendship.objects.get(
                id=friendship_id,
                to_user=request.user  # Current user must be the recipient
            )
        except Friendship.DoesNotExist:
            return Response(
                {'error': 'Friendship request not found or you are not the recipient'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        if friendship.status != 'PENDING':
            return Response(
                {'error': f'Friendship request is already {friendship.status.lower()}'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        friendship.status = 'ACCEPTED'
        friendship.save()
        
        serializer = FriendshipSerializer(friendship)
        return Response(
            {
                'message': 'Friend request accepted',
                'friendship': serializer.data
            },
            status=status.HTTP_200_OK
        )


class FriendshipRejectView(APIView):
    """
    Reject a friend request.
    POST: {friendship_id}
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, friendship_id=None):
        friendship_id = friendship_id or request.data.get('friendship_id')

        if not friendship_id:
            return Response(
                {'error': 'friendship_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            friendship = Friendship.objects.get(
                id=friendship_id,
                to_user=request.user
            )
        except Friendship.DoesNotExist:
            return Response(
                {'error': 'Friendship request not found or you are not the recipient'},
                status=status.HTTP_404_NOT_FOUND
            )

        if friendship.status != 'PENDING':
            return Response(
                {'error': f'Friendship request is already {friendship.status.lower()}'},
                status=status.HTTP_400_BAD_REQUEST
            )

        friendship.status = 'REJECTED'
        friendship.save()

        serializer = FriendshipSerializer(friendship)
        return Response(
            {
                'message': 'Friend request rejected',
                'friendship': serializer.data
            },
            status=status.HTTP_200_OK
        )


class FriendshipListView(APIView):
    """
    List all accepted friendships for the current user.
    GET returns list of friends
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        current_user = request.user
        
        # Get friends sent by current user (accepted)
        sent = Friendship.objects.filter(
            from_user=current_user,
            status='ACCEPTED'
        ).select_related('to_user')
        
        # Get friends sent to current user (accepted)
        received = Friendship.objects.filter(
            to_user=current_user,
            status='ACCEPTED'
        ).select_related('from_user')
        
        # Combine and get unique users
        friends_set = set()
        friends_list = []
        
        for friendship in sent:
            if friendship.to_user.id not in friends_set:
                friends_set.add(friendship.to_user.id)
                friends_list.append(friendship.to_user)
        
        for friendship in received:
            if friendship.from_user.id not in friends_set:
                friends_set.add(friendship.from_user.id)
                friends_list.append(friendship.from_user)
                
        # Sort users by is_online (True first), then by last_seen (most recent first)
        import datetime
        from django.utils import timezone
        
        def sort_key(user):
            is_online_sort = 0 if getattr(user, 'is_online', False) else 1
            last_seen = getattr(user, 'last_seen', None)
            if last_seen is None:
                last_seen = timezone.make_aware(datetime.datetime(1970, 1, 1))
            return (is_online_sort, -last_seen.timestamp())

        friends_list.sort(key=sort_key)

        # Pagination
        try:
            page = int(request.query_params.get('page', 1))
            limit = int(request.query_params.get('limit', 10))
        except ValueError:
            page = 1
            limit = 10
            
        page = max(1, page)
        limit = max(1, min(limit, 50))
        offset = (page - 1) * limit
        
        paginated_friends = friends_list[offset:offset+limit]
        friends_data = [UserSerializer(user).data for user in paginated_friends]
        
        return Response(
            {
                'results': friends_data,
                'count': len(friends_list),
                'page': page,
                'limit': limit
            }, 
            status=status.HTTP_200_OK
        )


class IncomingFriendshipRequestsView(APIView):
    """List incoming pending friendship requests for the current user."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        incoming = Friendship.objects.filter(
            to_user=request.user,
            status='PENDING'
        ).select_related('from_user', 'to_user')

        data = [
            {
                'id': f.id,
                'from_user_id': f.from_user_id,
                'from_username': f.from_user.username,
                'to_user_id': f.to_user_id,
                'to_username': f.to_user.username,
                'status': f.status,
                'created_at': f.created_at,
                'responded_at': f.updated_at if f.status != 'PENDING' else None,
            }
            for f in incoming
        ]
        return Response(data, status=status.HTTP_200_OK)


class OutgoingFriendshipRequestsView(APIView):
    """List outgoing pending friendship requests for the current user."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        outgoing = Friendship.objects.filter(
            from_user=request.user,
            status='PENDING'
        ).select_related('from_user', 'to_user')

        data = [
            {
                'id': f.id,
                'from_user_id': f.from_user_id,
                'from_username': f.from_user.username,
                'to_user_id': f.to_user_id,
                'to_username': f.to_user.username,
                'status': f.status,
                'created_at': f.created_at,
                'responded_at': f.updated_at if f.status != 'PENDING' else None,
            }
            for f in outgoing
        ]
        return Response(data, status=status.HTTP_200_OK)


class HealthCheckView(APIView):
    """Health check endpoint for Django service."""
    permission_classes = [AllowAny]

    def get(self, request):
        return Response(
            {
                'status': 'healthy',
                'service': 'django',
                'version': '1.0.0',
            },
            status=status.HTTP_200_OK
        )


class RoomInfoView(APIView):
    """Return room metadata for client diagnostics."""
    permission_classes = [IsAuthenticated]

    def get(self, request, room_id):
        try:
            room = ChatRoom.objects.get(id=room_id)
        except ChatRoom.DoesNotExist:
            return Response({'error': 'Room not found'}, status=status.HTTP_404_NOT_FOUND)

        if not room.participants.filter(id=request.user.id).exists():
            return Response({'error': 'You are not a member of this room'}, status=status.HTTP_403_FORBIDDEN)

        users = [
            {
                'user_id': u.id,
                'username': u.username,
            }
            for u in room.participants.all()
        ]

        return Response(
            {
                'room_id': room.id,
                'active_users': users,
                'user_count': len(users),
            },
            status=status.HTTP_200_OK
        )


class GetOrInitChatView(APIView):
    """
    Lazy room creation endpoint - combines friendship check and room creation.
    
    Flow:
    1. Check if friendship is ACCEPTED
    2. Check if room exists between users
    3. If not, create room
    4. Return room_id + chat history
    
    POST: {target_user_id}
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        target_user_id = request.data.get('target_user_id')
        
        if not target_user_id:
            return Response(
                {'error': 'target_user_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        current_user = request.user
        
        # Prevent self-messaging
        if int(target_user_id) == current_user.id:
            return Response(
                {'error': 'Cannot chat with yourself'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Check if target user exists
        try:
            target_user = User.objects.get(id=target_user_id)
        except User.DoesNotExist:
            return Response(
                {'error': 'Target user not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # ✓ STEP 1: Check friendship status
        friendship = Friendship.objects.filter(
            (models.Q(from_user=current_user, to_user=target_user) |
             models.Q(from_user=target_user, to_user=current_user))
        ).first()
        
        if not friendship or friendship.status != 'ACCEPTED':
            return Response(
                {
                    'error': 'You are not friends yet',
                    'friendship_status': friendship.status if friendship else 'NO_REQUEST'
                },
                status=status.HTTP_403_FORBIDDEN
            )
        
        # ✓ STEP 2: Check if room exists
        existing_rooms = ChatRoom.objects.filter(
            room_type='DM',
            participants=current_user
        ).filter(
            participants=target_user
        )
        
        if existing_rooms.exists():
            room = existing_rooms.first()
            messages = Message.objects.filter(room=room).order_by('-created_at')[:50]
            return Response(
                {
                    'room_id': room.id,
                    'created': False,
                    'room_name': room.name,
                    'messages': MessageSerializer(messages, many=True).data,
                    'message': 'Room already exists'
                },
                status=status.HTTP_200_OK
            )
        
        # ✓ STEP 3: Create room (lazy creation)
        import uuid
        room = ChatRoom.objects.create(
            id=str(uuid.uuid4()),
            name=f"{current_user.username} & {target_user.username}",
            room_type='DM',
            creator=current_user,
            description=f"Direct message between {current_user.username} and {target_user.username}"
        )
        
        room.participants.add(current_user, target_user)
        
        return Response(
            {
                'room_id': room.id,
                'created': True,
                'room_name': room.name,
                'messages': [],
                'message': 'Room created successfully (lazy creation)'
            },
            status=status.HTTP_201_CREATED
        )


class FriendshipDeleteView(APIView):
    """
    Unfriend a user.
    DELETE: /api/v1/friends/<friend_id>/
    """
    permission_classes = [IsAuthenticated]

    def delete(self, request, friend_id):
        current_user = request.user
        
        # Check if target user exists
        try:
            friend = User.objects.get(id=friend_id)
        except User.DoesNotExist:
            return Response(
                {'error': 'User not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Find friendship in either direction
        friendship = Friendship.objects.filter(
            (models.Q(from_user=current_user, to_user=friend) |
             models.Q(from_user=friend, to_user=current_user))
        ).first()
        
        if not friendship:
            return Response(
                {'error': 'Friendship not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Delete friendship
        friendship.delete()
        
        return Response(
            {'message': f'Successfully unfriended {friend.username}'},
            status=status.HTTP_204_NO_CONTENT
        )


class PublicKeyUploadView(APIView):
    """
    Upload or update the user's RSA Public Key.
    POST: { "public_key": "...", "device_id": "..." }
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        public_key_text = request.data.get('public_key')
        device_id = request.data.get('device_id')

        if not public_key_text:
            return Response(
                {'error': 'public_key is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        public_key_obj, created = UserPublicKey.objects.update_or_create(
            user=request.user,
            defaults={
                'public_key': public_key_text,
                'device_id': device_id
            }
        )

        return Response(
            {
                'message': 'Public key uploaded successfully',
                'created': created
            },
            status=status.HTTP_200_OK if not created else status.HTTP_201_CREATED
        )


class PublicKeyRetrieveView(APIView):
    """
    Retrieve another user's RSA Public Key.
    GET: /api/keys/<user_id>/
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, user_id):
        try:
            public_key_obj = UserPublicKey.objects.get(user_id=user_id)
            return Response(
                {
                    'user_id': user_id,
                    'public_key': public_key_obj.public_key,
                    'device_id': public_key_obj.device_id,
                },
                status=status.HTTP_200_OK
            )
        except UserPublicKey.DoesNotExist:
            return Response(
                {'error': 'Public key not found for this user'},
                status=status.HTTP_404_NOT_FOUND
            )
