import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class FirstTimeSplashScreen extends StatelessWidget {
  const FirstTimeSplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // Centered circular logo like Facebook
            Center(
              child: Container(
                width: 140.w,
                height: 140.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 12.r,
                      offset: Offset(0, 6.h),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: theme.primaryColor,
                      child: Center(
                        child: Icon(
                          Icons.chat_bubble_outline,
                          size: 64.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 24.h),
            Text(
              'Welcome to Chat App',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 24.sp,
              ),
            ),
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.w),
              child: Text(
                'Connect with friends and family. Create groups, chat securely, and share moments.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14.sp,
                ),
              ),
            ),
            const Spacer(),

            // Next button pinned to bottom
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
              child: SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: () {
                    context.go('/auth');
                  },
                  child: Text('Next', style: TextStyle(fontSize: 16.sp)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
