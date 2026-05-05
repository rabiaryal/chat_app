/// Add Friend Bottom Sheet Widget
import 'package:flutter/material.dart';

class AddFriendBottomSheet extends StatelessWidget {
  final VoidCallback? onSearchTap;
  final VoidCallback? onRequestsTap;

  const AddFriendBottomSheet({
    Key? key,
    this.onSearchTap,
    this.onRequestsTap,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
            margin: EdgeInsets.only(bottom: 24),
          ),
          Text(
            'Find Friends',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 32),
          _buildOption(
            context,
            icon: Icons.search,
            title: 'Search & Add Friends',
            subtitle: 'Find friends by username',
            onTap: () {
              Navigator.pop(context);
              onSearchTap?.call();
            },
          ),
          SizedBox(height: 16),
          _buildOption(
            context,
            icon: Icons.mail_outline,
            title: 'Friend Requests',
            subtitle: 'View pending requests',
            onTap: () {
              Navigator.pop(context);
              onRequestsTap?.call();
            },
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black,
              minimumSize: Size(double.infinity, 48),
            ),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.blue, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function to show the bottom sheet
void showAddFriendBottomSheet(
  BuildContext context, {
  VoidCallback? onSearchTap,
  VoidCallback? onRequestsTap,
}) {
  showModalBottomSheet(
    context: context,
    builder: (context) => AddFriendBottomSheet(
      onSearchTap: onSearchTap,
      onRequestsTap: onRequestsTap,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
  );
}
