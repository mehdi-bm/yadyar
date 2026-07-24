import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.task_alt_rounded,
                size: 64,
                color: scheme.onPrimaryContainer,
              ),
            ),
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
    );
  }
}
