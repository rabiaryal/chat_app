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
    RoomsListView,
    RoomDetailView,
    RoomMembersView,
    GetOrCreateRoomView,
    FriendshipRequestView,
    FriendshipAcceptView,
    FriendshipListView,
    GetOrInitChatView,
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
    
    # Room Endpoints
    path('room/', GetOrCreateRoomView.as_view(), name='get_or_create_room'),
    path('rooms/', RoomsListView.as_view(), name='rooms_list'),
    path('rooms/<str:room_id>/', RoomDetailView.as_view(), name='room_detail'),
    path('rooms/<str:room_id>/members/', RoomMembersView.as_view(), name='room_members'),
    path('rooms/<str:room_id>/members/<int:user_id>/', RoomMembersView.as_view(), name='room_member_detail'),
    
    # Friendship Endpoints
    path('friendship/request/', FriendshipRequestView.as_view(), name='friendship_request'),
    path('friendship/accept/', FriendshipAcceptView.as_view(), name='friendship_accept'),
    path('friends/', FriendshipListView.as_view(), name='friends_list'),
    
    # Chat Initialization (Lazy Room Creation)
    path('chat/initialize/', GetOrInitChatView.as_view(), name='get_or_init_chat'),
]
