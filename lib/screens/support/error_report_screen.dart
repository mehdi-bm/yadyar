import 'package:flutter/material.dart';

import '../../config/ads_config.dart';
import '../../services/ads_api_exception.dart';
import '../../services/app_support_gateway.dart';
import '../../services/app_support_service.dart';

class ErrorReportScreen extends StatefulWidget {
  const ErrorReportScreen({super.key, this.gateway});

  final AppSupportGateway? gateway;

  @override
  State<ErrorReportScreen> createState() => _ErrorReportScreenState();
}

class _ErrorReportScreenState extends State<ErrorReportScreen> {
  late final AppSupportGateway _gateway;
  late final bool _ownsGateway;
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _ownsGateway = widget.gateway == null;
    _gateway =
        widget.gateway ??
        AppSupportService(config: AdsConfig.fromEnvironment());
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsGateway) _gateway.close();
    super.dispose();
  }

  String? _validate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'شرح خطا را وارد کنید.';
    if (text.length < 5) return 'شرح خطا باید حداقل ۵ کاراکتر باشد.';
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_gateway.isConfigured) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      await _gateway.submitErrorReport(description: _controller.text.trim());
      if (!mounted) return;
      _controller.clear();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ثبت شد'),
          content: const Text('گزارش شما ثبت شد.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('باشه'),
            ),
          ],
        ),
      );
    } on AdsApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('خطایی در ارتباط با سرور رخ داد؛ دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final configured = _gateway.isConfigured;
    return Scaffold(
      appBar: AppBar(title: const Text('ارسال گزارش خطا')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'لطفاً صفحه‌ای که در آن بودید، کاری که انجام دادید، نتیجه‌ای که '
                      'گرفتید و نتیجه‌ای که انتظار داشتید را توضیح دهید.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!configured)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'ارسال گزارش خطا در حال حاضر در دسترس نیست.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                TextFormField(
                  key: const ValueKey('error_description'),
                  controller: _controller,
                  enabled: configured && !_isSubmitting,
                  maxLength: 4000,
                  maxLines: 8,
                  minLines: 5,
                  validator: _validate,
                  decoration: const InputDecoration(
                    labelText: 'شرح خطا',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const ValueKey('submit_error_report'),
                  onPressed: configured && !_isSubmitting ? _submit : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ارسال گزارش'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
