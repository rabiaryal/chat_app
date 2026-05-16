import 'package:flutter/material.dart';
import 'failure.dart';
import 'snackbar_utils.dart';

class ErrorHandler {
  /// Handles and displays an error message using SnackbarUtils
  static void handle(BuildContext context, dynamic error, {String? title}) {
    String message;
    
    if (error is Failure) {
      message = error.message;
    } else {
      message = error.toString().replaceAll('Exception: ', '');
    }

    if (title != null) {
      message = '$title: $message';
    }

    SnackbarUtils.showError(context, message);
  }

  /// Displays a success message using SnackbarUtils
  static void showSuccess(BuildContext context, String message) {
    SnackbarUtils.showSuccess(context, message);
  }

  /// Displays an info message using SnackbarUtils
  static void showInfo(BuildContext context, String message) {
    SnackbarUtils.showInfo(context, message);
  }
}
