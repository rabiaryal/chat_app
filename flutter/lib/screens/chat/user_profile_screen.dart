/// User Profile Screen - Full Page
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';

class UserProfileScreen extends StatefulWidget {
  final User user;
  final bool isCurrentUser;

  const UserProfileScreen({
    Key? key,
    required this.user,
    this.isCurrentUser = false,
  }) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _notificationsEnabled = true;
  bool _loadingNotifications = false;
  bool _updatingNotifications = false;

  User get user => widget.user;
  bool get isCurrentUser => widget.isCurrentUser;

  @override
  void initState() {
    super.initState();
    if (isCurrentUser) {
      Future.microtask(_loadNotificationState);
    }
  }

  Future<void> _loadNotificationState() async {
    setState(() {
      _loadingNotifications = true;
    });

    final notificationService = context.read<NotificationService>();
    final enabled = await notificationService.isNotificationsEnabled();

    if (!mounted) return;

    setState(() {
      _notificationsEnabled = enabled;
      _loadingNotifications = false;
    });
  }

  Future<void> _toggleNotifications(bool enabled) async {
    if (_updatingNotifications) return;

    setState(() {
      _updatingNotifications = true;
    });

    final notificationService = context.read<NotificationService>();
    final result = await notificationService.setNotificationsEnabled(enabled);

    if (!mounted) return;

    setState(() {
      _notificationsEnabled = result;
      _updatingNotifications = false;
    });

    if (enabled && !result) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification permission was not granted.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header Section
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.only(bottom: 32.h, top: 16.h),
              child: Center(
                child: Column(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 64.r,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 60.r,
                        backgroundColor: Colors.blue[200],
                        child: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: 48.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    // Display Name
                    Text(
                      user.displayName,
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    // Username
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.blue[100],
                      ),
                    ),
                    SizedBox(height: 12.h),
                    // Status Badge
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: (user.isOnline || isCurrentUser)
                            ? Colors.green
                            : Colors.grey,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 4.r,
                            backgroundColor: Colors.white,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            (user.isOnline || isCurrentUser)
                                ? 'Online'
                                : 'Offline',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 32.h),
            // Profile Information Section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Information',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _buildInfoCard(
                    context,
                    icon: Icons.email_outlined,
                    label: 'Email Address',
                    value: user.email,
                  ),
                  if (isCurrentUser) ...[
                    SizedBox(height: 16.h),
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Card(
                      elevation: 0,
                      color: Theme.of(context).cardColor,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: SwitchListTile.adaptive(
                        value: _notificationsEnabled,
                        onChanged:
                            (_loadingNotifications || _updatingNotifications)
                                ? null
                                : _toggleNotifications,
                        secondary: Container(
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(
                            _notificationsEnabled
                                ? Icons.notifications_active_outlined
                                : Icons.notifications_off_outlined,
                            color: Theme.of(context).primaryColor,
                            size: 20.sp,
                          ),
                        ),
                        title: Text(
                          _notificationsEnabled
                              ? 'Push notifications enabled'
                              : 'Push notifications disabled',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _loadingNotifications
                              ? 'Checking notification status...'
                              : (_notificationsEnabled
                                  ? 'Receive alerts for new chats and group updates.'
                                  : 'Mute push notifications on this device.'),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 32.h),
                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showLogoutDialog(context);
                      },
                      icon: Icon(Icons.logout, size: 18.sp),
                      label: Text('Logout', style: TextStyle(fontSize: 16.sp)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AuthProvider>().logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
            ),
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, color: primaryColor, size: 20.sp),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ),
    );
  }
}
