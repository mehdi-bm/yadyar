import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../widgets/app_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.75, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        onEnd: onFinished,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.scale(scale: value, child: child),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 104),
              const SizedBox(height: 20),
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'همه‌چیز، مرتب و در دسترس',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
