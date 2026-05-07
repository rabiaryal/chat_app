"""
URL configuration for chat_app.
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    CustomTokenObtainPairView,
    RegisterView,
    LoginView,
    LogoutView,
    ChangePasswordView,
    CustomTokenRefreshView,
    UserMeView,
    UserDeleteView,
    UserSearchView,
    SuggestedFriendsView,
    RoomsListView,
    RoomDetailView,
    RoomMessagesView,
    RoomMembersView,
    GroupCreateView,
    GetOrCreateRoomView,
    FriendshipRequestView,
    FriendshipAcceptView,
    FriendshipRejectView,
    FriendshipListView,
    IncomingFriendshipRequestsView,
    OutgoingFriendshipRequestsView,
    FriendshipDeleteView,
    GetOrInitChatView,
    HealthCheckView,
    RoomInfoView,
    PublicKeyUploadView,
    PublicKeyRetrieveView,
    UserViewSet,
    ChatRoomViewSet,
    MessageViewSet
)

router = DefaultRouter()
router.register(r'users', UserViewSet)
router.register(r'chat-rooms', ChatRoomViewSet)
router.register(r'messages', MessageViewSet)

urlpatterns = [
    # API Routes
    path('', include(router.urls)),
    
    # Authentication Endpoints
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/login/', LoginView.as_view(), name='login'),
    path('auth/logout/', LogoutView.as_view(), name='logout'),
    path('auth/change-password/', ChangePasswordView.as_view(), name='change_password'),
    path('auth/token/refresh/', CustomTokenRefreshView.as_view(), name='token_refresh'),
    
    # User Endpoints
    path('user/me/', UserMeView.as_view(), name='user_me'),
    path('user/delete/', UserDeleteView.as_view(), name='user_delete'),
    path('user/search/', UserSearchView.as_view(), name='user_search'),
    path('user/suggested/', SuggestedFriendsView.as_view(), name='user_suggested'),
    
    # Room Endpoints
    path('room/', GetOrCreateRoomView.as_view(), name='get_or_create_room'),
    path('rooms/', RoomsListView.as_view(), name='rooms_list'),
    path('rooms/create-group/', GroupCreateView.as_view(), name='group_create'),
    path('rooms/<str:room_id>/', RoomDetailView.as_view(), name='room_detail'),
    path('rooms/<str:room_id>/messages/', RoomMessagesView.as_view(), name='room_messages'),
    path('rooms/<str:room_id>/members/', RoomMembersView.as_view(), name='room_members'),
    path('rooms/<str:room_id>/members/<int:user_id>/', RoomMembersView.as_view(), name='room_member_detail'),
    
    # Friendship Endpoints
    path('friendship/request/', FriendshipRequestView.as_view(), name='friendship_request'),
    path('friendship/accept/', FriendshipAcceptView.as_view(), name='friendship_accept'),
    path('friendship/reject/', FriendshipRejectView.as_view(), name='friendship_reject'),
    path('friendship/requests/<int:friendship_id>/accept/', FriendshipAcceptView.as_view(), name='friendship_accept_by_id'),
    path('friendship/requests/<int:friendship_id>/reject/', FriendshipRejectView.as_view(), name='friendship_reject_by_id'),
    path('friendship/requests/incoming/', IncomingFriendshipRequestsView.as_view(), name='friendship_requests_incoming'),
    path('friendship/requests/outgoing/', OutgoingFriendshipRequestsView.as_view(), name='friendship_requests_outgoing'),
    path('friends/', FriendshipListView.as_view(), name='friends_list'),
    path('friends/<int:friend_id>/', FriendshipDeleteView.as_view(), name='unfriend'),

    # Utility endpoints
    path('health/', HealthCheckView.as_view(), name='health_check'),
    path('rooms/<str:room_id>/info/', RoomInfoView.as_view(), name='room_info'),
    
    # Chat Initialization (Lazy Room Creation)
    path('chat/initialize/', GetOrInitChatView.as_view(), name='get_or_init_chat'),

    # E2EE Key Management
    path('keys/upload/', PublicKeyUploadView.as_view(), name='public_key_upload'),
    path('keys/<int:user_id>/', PublicKeyRetrieveView.as_view(), name='public_key_retrieve'),
]
