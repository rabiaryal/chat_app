import 'package:flutter/material.dart';
import '../../features/auth/models/user.dart';
import '../../screens/chat/friends_list_screen.dart';

class DashboardBottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final Color primaryColor;
  final User? currentUser;

  const DashboardBottomNav({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.primaryColor,
    required this.currentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex > 2 ? 0 : selectedIndex, // Highlight chats if 'Add' is tapped
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      showUnselectedLabels: true,
      onTap: (index) {
        if (index == 3) {
          // Add Friend tab (Now in the bottom right corner)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FriendsListScreen()),
          );
        } else {
          onItemSelected(index);
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chats'),
        BottomNavigationBarItem(icon: Icon(Icons.call_outlined), label: 'Calls'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Contacts'),
        // Bottom Right: Add Icon (Instead of Profile)
        BottomNavigationBarItem(icon: Icon(Icons.person_add), label: 'Add'),
      ],
    );
  }
}
