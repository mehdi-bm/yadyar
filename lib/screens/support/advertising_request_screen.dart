import 'package:flutter/material.dart';

import '../../config/ads_config.dart';
import '../../services/ads_api_exception.dart';
import '../../services/app_support_gateway.dart';
import '../../services/app_support_service.dart';
import '../../utils/phone_input_formatter.dart';

class AdvertisingRequestScreen extends StatefulWidget {
  const AdvertisingRequestScreen({super.key, this.gateway});

  final AppSupportGateway? gateway;

  @override
  State<AdvertisingRequestScreen> createState() =>
      _AdvertisingRequestScreenState();
}

class _AdvertisingRequestScreenState extends State<AdvertisingRequestScreen> {
  late final AppSupportGateway _gateway;
  late final bool _ownsGateway;
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _provinceController = TextEditingController();
  final _cityController = TextEditingController();
  final _detailsController = TextEditingController();
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
    _fullNameController.dispose();
    _phoneController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    _detailsController.dispose();
    if (_ownsGateway) _gateway.close();
    super.dispose();
  }

  String? _validateFullName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'نام و نام خانوادگی را وارد کنید.';
    if (text.length < 3 || text.length > 160) {
      return 'باید بین ۳ تا ۱۶۰ کاراکتر باشد.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final digitCount = phoneDigitCount(value ?? '');
    if (digitCount == 0) return 'شماره تماس را وارد کنید.';
    if (digitCount < 7 || digitCount > 20) return 'شماره تماس معتبر نیست.';
    return null;
  }

  String? _validateProvince(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'استان را وارد کنید.';
    if (text.length < 2 || text.length > 100) {
      return 'باید بین ۲ تا ۱۰۰ کاراکتر باشد.';
    }
    return null;
  }

  String? _validateCity(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'شهر را وارد کنید.';
    if (text.length < 2 || text.length > 100) {
      return 'باید بین ۲ تا ۱۰۰ کاراکتر باشد.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_gateway.isConfigured) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      await _gateway.submitAdvertisingRequest(
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        province: _provinceController.text.trim(),
        city: _cityController.text.trim(),
        details: _detailsController.text.trim(),
      );
      if (!mounted) return;
      _fullNameController.clear();
      _phoneController.clear();
      _provinceController.clear();
      _cityController.clear();
      _detailsController.clear();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ثبت شد'),
          content: const Text(
            'درخواست شما ثبت شد. کارشناسان تبلیغات با شماره ثبت‌شده با شما تماس می‌گیرند.',
          ),
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
      appBar: AppBar(title: const Text('درخواست تبلیغ')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!configured)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'ثبت درخواست تبلیغ در حال حاضر در دسترس نیست.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  TextFormField(
                    key: const ValueKey('advertising_full_name'),
                    controller: _fullNameController,
                    enabled: configured && !_isSubmitting,
                    maxLength: 160,
                    autofillHints: const [AutofillHints.name],
                    validator: _validateFullName,
                    decoration: const InputDecoration(
                      labelText: 'نام و نام خانوادگی',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  TextFormField(
                    key: const ValueKey('advertising_phone'),
                    controller: _phoneController,
                    enabled: configured && !_isSubmitting,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [PhoneNumberInputFormatter()],
                    validator: _validatePhone,
                    decoration: const InputDecoration(
                      labelText: 'شماره تماس',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final province = TextFormField(
                        key: const ValueKey('advertising_province'),
                        controller: _provinceController,
                        enabled: configured && !_isSubmitting,
                        maxLength: 100,
                        validator: _validateProvince,
                        decoration: const InputDecoration(
                          labelText: 'استان',
                          border: OutlineInputBorder(),
                        ),
                      );
                      final city = TextFormField(
                        key: const ValueKey('advertising_city'),
                        controller: _cityController,
                        enabled: configured && !_isSubmitting,
                        maxLength: 100,
                        validator: _validateCity,
                        decoration: const InputDecoration(
                          labelText: 'شهر',
                          border: OutlineInputBorder(),
                        ),
                      );
                      if (constraints.maxWidth < 480) {
                        return Column(children: [province, city]);
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: province),
                          const SizedBox(width: 12),
                          Expanded(child: city),
                        ],
                      );
                    },
                  ),
                  TextFormField(
                    key: const ValueKey('advertising_details'),
                    controller: _detailsController,
                    enabled: configured && !_isSubmitting,
                    maxLength: 4000,
                    maxLines: 5,
                    minLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'توضیحات تکمیلی (اختیاری)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'اطلاعات شما فقط برای پیگیری همین درخواست استفاده می‌شود.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const ValueKey('submit_advertising_request'),
                    onPressed: configured && !_isSubmitting ? _submit : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('ثبت درخواست'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
