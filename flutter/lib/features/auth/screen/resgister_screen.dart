import 'package:chat_app/features/auth/provider/auth_provider.dart';
import 'package:chat_app/utils/error_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class RegisterPage extends ConsumerStatefulWidget {
  final VoidCallback onSwitchToLogin;

  const RegisterPage({required this.onSwitchToLogin});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  final ValueNotifier<bool> _obscurePassword = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _obscureConfirmPassword = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _obscurePassword.dispose();
    _obscureConfirmPassword.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final authNotifier = ref.read(authProvider.notifier);

    if (_usernameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _confirmPasswordController.text.trim().isEmpty) {
      ErrorHandler.handle(context, 'Please fill in all fields');
      return;
    }

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      ErrorHandler.handle(context, 'Passwords do not match');
      return;
    }

    if (_passwordController.text.trim().length < 8) {
      ErrorHandler.handle(context, 'Password must be at least 8 characters');
      return;
    }

    final success = await authNotifier.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ErrorHandler.showSuccess(
        context,
        'Registration successful! Welcome to Chat App.',
      );
      // Navigate to suggested friends
      context.go('/suggested-friends');
    } else {
      ErrorHandler.handle(
        context,
        ref.read(authProvider).error ?? 'Registration failed',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticating =
        ref.watch(authProvider.select((state) => state.isAuthenticating));

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 60.h),
          Icon(
            Icons.chat_bubble_outline,
            size: 80.sp,
            color: Theme.of(context).primaryColor,
          ),
          SizedBox(height: 24.h),
          Text(
            'Create Account',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 28.sp,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.h),
          Text(
            'Join us and start chatting',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 16.sp,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 36.h),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'Username',
              hintText: 'Choose a username',
              prefixIcon: Icon(Icons.person_outline, size: 20.sp),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            enabled: !isAuthenticating,
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email',
              prefixIcon: Icon(Icons.email_outlined, size: 20.sp),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            enabled: !isAuthenticating,
          ),
          SizedBox(height: 16.h),
          ValueListenableBuilder<bool>(
            valueListenable: _obscurePassword,
            builder: (context, obscure, _) => TextField(
              controller: _passwordController,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'At least 8 characters',
                prefixIcon: Icon(Icons.lock_outline, size: 20.sp),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility : Icons.visibility_off,
                    size: 20.sp,
                  ),
                  onPressed: () {
                    _obscurePassword.value = !_obscurePassword.value;
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              enabled: !isAuthenticating,
            ),
          ),
          SizedBox(height: 16.h),
          ValueListenableBuilder<bool>(
            valueListenable: _obscureConfirmPassword,
            builder: (context, obscureConfirm, _) => TextField(
              controller: _confirmPasswordController,
              obscureText: obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                hintText: 'Re-enter your password',
                prefixIcon: Icon(Icons.lock_outline, size: 20.sp),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirm ? Icons.visibility : Icons.visibility_off,
                    size: 20.sp,
                  ),
                  onPressed: () {
                    _obscureConfirmPassword.value =
                        !_obscureConfirmPassword.value;
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              enabled: !isAuthenticating,
            ),
          ),
          SizedBox(height: 32.h),
          ElevatedButton(
            onPressed: isAuthenticating ? null : _register,
            child: isAuthenticating
                ? SizedBox(
                    height: 20.h,
                    width: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.w,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text('Create Account', style: TextStyle(fontSize: 16.sp)),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account? ',
                  style: TextStyle(fontSize: 14.sp)),
              TextButton(
                onPressed: isAuthenticating ? null : widget.onSwitchToLogin,
                child: Text('Sign In', style: TextStyle(fontSize: 14.sp)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
