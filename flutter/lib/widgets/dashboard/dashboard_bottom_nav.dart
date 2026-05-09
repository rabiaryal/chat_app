import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../screens/user_profile_screen.dart';

class DashboardBottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final Color primaryColor;
  final User? currentUser;
  final VoidCallback onLogout;

  const DashboardBottomNav({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.primaryColor,
    required this.currentUser,
    required this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      showUnselectedLabels: true,
      onTap: (index) {
        if (index == 3) {
          // Profile tab
          if (currentUser != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(
                  user: currentUser!,
                  onLogout: onLogout,
                  isCurrentUser: true,
                ),
              ),
            );
          }
        } else {
          onItemSelected(index);
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chats'),
        BottomNavigationBarItem(icon: Icon(Icons.call_outlined), label: 'Calls'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Contacts'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
