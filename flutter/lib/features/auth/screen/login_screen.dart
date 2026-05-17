import 'package:chat_app/features/auth/provider/auth_provider.dart';
import 'package:chat_app/utils/error_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends ConsumerStatefulWidget {
  final VoidCallback onSwitchToRegister;

  const LoginPage({required this.onSwitchToRegister});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  final ValueNotifier<bool> _obscurePassword = ValueNotifier<bool>(true);
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _obscurePassword.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final authNotifier = ref.read(authProvider.notifier);

    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ErrorHandler.handle(context, 'Please fill in all fields');
      return;
    }

    final success = await authNotifier.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      rememberMe: _rememberMe,
    );

    if (!mounted) return;

    if (success) {
      ErrorHandler.showSuccess(
        context,
        'Welcome back, ${_usernameController.text.trim()}!',
      );
      context.go('/chat-list');
    } else {
      ErrorHandler.handle(
        context,
        ref.read(authProvider).error ?? 'Login failed',
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
            'Welcome Back',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 28.sp,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.h),
          Text(
            'Sign in to continue chatting',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 16.sp,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 48.h),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'Username',
              hintText: 'Enter your username',
              prefixIcon: Icon(Icons.person_outline, size: 20.sp),
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
                hintText: 'Enter your password',
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
          SizedBox(height: 8.h),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _rememberMe,
            onChanged: isAuthenticating
                ? null
                : (value) {
                    setState(() {
                      _rememberMe = value ?? true;
                    });
                  },
            title: Text(
              'Remember me',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Keep me signed in on this device',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
            ),
            activeColor: Theme.of(context).primaryColor,
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: isAuthenticating ? null : _login,
            child: isAuthenticating
                ? SizedBox(
                    height: 20.h,
                    width: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.w,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text('Sign In', style: TextStyle(fontSize: 16.sp)),
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
              Text('Don\'t have an account? ',
                  style: TextStyle(fontSize: 14.sp)),
              TextButton(
                onPressed: isAuthenticating ? null : widget.onSwitchToRegister,
                child: Text('Sign Up', style: TextStyle(fontSize: 14.sp)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
