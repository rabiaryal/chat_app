"""
URL configuration for chat_app - Cleaned up version with only used endpoints.
"""

from django.urls import path
from .views import (
    RegisterView,
    LoginView,
    LogoutView,
    ChangePasswordView,
    UserMeView,
    UserDeleteView,
    UserSearchView,
    SuggestedFriendsView,
    RoomsListView,
    RoomReadView,
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
    PublicKeyUploadView,
    PublicKeyRetrieveView,
    DeviceRegisterView,
    DeviceUnregisterView,
)
from rest_framework_simplejwt.views import (
    TokenRefreshView,
)

urlpatterns = [
    # ============== AUTHENTICATION ==============
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/login/', LoginView.as_view(), name='login'),
    path('auth/logout/', LogoutView.as_view(), name='logout'),
    path('auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/change-password/', ChangePasswordView.as_view(), name='change_password'),
    
    # ============== USER MANAGEMENT ==============
    path('user/me/', UserMeView.as_view(), name='user_me'),
    path('user/delete/', UserDeleteView.as_view(), name='user_delete'),
    path('user/search/', UserSearchView.as_view(), name='user_search'),
    path('user/suggested/', SuggestedFriendsView.as_view(), name='user_suggested'),
    path('users/suggested/', SuggestedFriendsView.as_view(), name='users_suggested'),
    
    # ============== ROOMS & MESSAGES ==============
    path('rooms/', RoomsListView.as_view(), name='rooms_list'),
    path('rooms/create-group/', GroupCreateView.as_view(), name='group_create'),
    path('rooms/direct/<int:friend_id>/', GetOrCreateRoomView.as_view(), name='get_or_create_room'),
    path('rooms/<str:room_id>/read/', RoomReadView.as_view(), name='room_read'),
    path('rooms/<str:room_id>/messages/', RoomMessagesView.as_view(), name='room_messages'),
    path('rooms/<str:room_id>/members/', RoomMembersView.as_view(), name='room_members'),
    path('rooms/<str:room_id>/members/<int:user_id>/', RoomMembersView.as_view(), name='room_member_remove'),
    path('chat/initialize/', GetOrCreateRoomView.as_view(), name='chat_initialize'),
    
    # ============== FRIENDSHIP ==============
    path('friendship/request/', FriendshipRequestView.as_view(), name='friendship_request'),
    path('friendship/accept/', FriendshipAcceptView.as_view(), name='friendship_accept'),
    path('friendship/reject/', FriendshipRejectView.as_view(), name='friendship_reject'),
    path('friendship/requests/incoming/', IncomingFriendshipRequestsView.as_view(), name='friendship_requests_incoming'),
    path('friendship/requests/outgoing/', OutgoingFriendshipRequestsView.as_view(), name='friendship_requests_outgoing'),
    path('friends/', FriendshipListView.as_view(), name='friends_list'),
    path('friends/<int:friend_id>/', FriendshipDeleteView.as_view(), name='unfriend'),

    # ============== E2EE KEY MANAGEMENT ==============
    path('keys/upload/', PublicKeyUploadView.as_view(), name='public_key_upload'),
    path('keys/<int:user_id>/', PublicKeyRetrieveView.as_view(), name='public_key_retrieve'),

    # ============== PUSH NOTIFICATIONS ==============
    path('devices/register/', DeviceRegisterView.as_view(), name='device_register'),
    path('devices/unregister/', DeviceUnregisterView.as_view(), name='device_unregister'),
]
