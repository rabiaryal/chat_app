import 'package:flutter/material.dart';
import '../main.dart';

enum SnackbarType { success, error, info, warning }

class SnackbarUtils {
  static void show(
    BuildContext context,
    String message, {
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final colorScheme = _getColors(type);

    final messenger = MyApp.messengerKey.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getIcon(type),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: duration,
        elevation: 4,
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white70,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message, type: SnackbarType.success);
  }

  static void showError(BuildContext context, String message) {
    show(context, message, type: SnackbarType.error);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, message, type: SnackbarType.info);
  }

  static void showWarning(BuildContext context, String message) {
    show(context, message, type: SnackbarType.warning);
  }

  static _SnackbarColors _getColors(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return _SnackbarColors(backgroundColor: const Color(0xFF2ECC71));
      case SnackbarType.error:
        return _SnackbarColors(backgroundColor: const Color(0xFFE74C3C));
      case SnackbarType.warning:
        return _SnackbarColors(backgroundColor: const Color(0xFFF39C12));
      case SnackbarType.info:
        return _SnackbarColors(
            backgroundColor: const Color(0xFF6C5CE7)); // Brand Purple
    }
  }

  static IconData _getIcon(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return Icons.check_circle_outline;
      case SnackbarType.error:
        return Icons.error_outline;
      case SnackbarType.warning:
        return Icons.warning_amber_outlined;
      case SnackbarType.info:
        return Icons.info_outline;
    }
  }
}

class _SnackbarColors {
  final Color backgroundColor;
  _SnackbarColors({required this.backgroundColor});
}
