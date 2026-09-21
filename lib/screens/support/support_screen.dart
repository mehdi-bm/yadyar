import 'package:flutter/material.dart';

import 'advertising_request_screen.dart';
import 'error_report_screen.dart';

/// نقطه ورود مشترک برای «ارسال گزارش خطا» و «درخواست تبلیغ».
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('پشتیبانی')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                key: const ValueKey('support_error_report_entry'),
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('ارسال گزارش خطا'),
                subtitle: const Text(
                  'مشکلی در برنامه دیدید؟ به ما اطلاع دهید.',
                ),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const ErrorReportScreen()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                key: const ValueKey('support_advertising_request_entry'),
                leading: const Icon(Icons.campaign_outlined),
                title: const Text('درخواست تبلیغ'),
                subtitle: const Text('می‌خواهید در یادیار تبلیغ کنید؟'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const AdvertisingRequestScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
