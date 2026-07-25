import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/notification_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  static const preferenceKey = 'onboarding_complete';
  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPageData(
      icon: Icons.note_alt_outlined,
      title: 'یادداشت و یادآور',
      description:
          'فکرها و کارهایتان را ثبت کنید و برای زمان مناسب، یادآور بسازید.',
    ),
    _OnboardingPageData(
      icon: Icons.dashboard_customize_outlined,
      title: 'قبض و خرید، کنار هم',
      description:
          'سررسید قبض‌ها را از دست ندهید و لیست خرید خانواده را همیشه آماده داشته باشید.',
    ),
    _OnboardingPageData(
      icon: Icons.notifications_active_outlined,
      title: 'یادآوری در زمان مناسب',
      description:
          'برای نمایش یادآورها در زمان تعیین‌شده، اجازه ارسال اعلان را فعال کنید.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool requestPermission}) async {
    if (requestPermission) {
      await NotificationService.instance.requestPermissionOnFirstLaunch();
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(OnboardingScreen.preferenceKey, true);
    if (mounted) widget.onComplete();
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLast = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => _finish(requestPermission: false),
                child: const Text('رد کردن'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 136,
                          height: 136,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page.icon,
                            size: 72,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.7,
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: index == _page ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: index == _page
                        ? scheme.primary
                        : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: isLast
                    ? FilledButton.icon(
                        onPressed: () => _finish(requestPermission: true),
                        icon: const Icon(Icons.notifications_outlined),
                        label: const Text('فعال‌سازی اعلان و شروع'),
                      )
                    : FilledButton(
                        onPressed: _next,
                        child: const Text('ادامه'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
