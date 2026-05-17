import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/models/user.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Color primaryColor;
  final User? currentUser;
  final VoidCallback onLogout;

  const ChatAppBar({
    Key? key,
    required this.primaryColor,
    this.currentUser,
    required this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Text(
          'Chats',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
      ),
      centerTitle: false,
      actions: [
        // Top Right: Profile Icon (Navigates to Profile Page)
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: GestureDetector(
            onTap: () {
              if (currentUser != null) {
                context.push('/user-profile', extra: {
                  'user': currentUser!,
                  'isCurrentUser': true,
                });
              }
            },
            child: Center(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: currentUser?.avatar != null
                      ? Image.network(
                          currentUser!.avatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                        )
                      : _buildDefaultAvatar(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return Center(
      child: Text(
        currentUser?.username[0].toUpperCase() ?? 'U',
        style: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);
}
