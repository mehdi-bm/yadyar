import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/ad_banner_model.dart';
import '../../providers/ad_banner_controller.dart';

/// carousel بنر تبلیغاتی پارسیک؛ اگر تبلیغ فعالی نباشد یا سرویس پیکربندی
/// نشده باشد، هیچ فضایی اشغال نمی‌کند.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key, this.controller});

  final AdBannerController? controller;

  @override
  State<AdBannerWidget> createState() => AdBannerWidgetState();
}

class AdBannerWidgetState extends State<AdBannerWidget>
    with WidgetsBindingObserver {
  late final AdBannerController _controller;
  late final bool _ownsController;
  final PageController _pageController = PageController();
  Timer? _autoSlideTimer;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? AdBannerController();
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addObserver(this);
    _controller.loadInitial();
  }

  Future<void> refresh() => _controller.fetch(force: true);

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _syncAutoSlide();
  }

  void _syncAutoSlide() {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    final shouldRun =
        !_isDragging && _controller.banners.length > 1 && isForeground;
    if (shouldRun) {
      _autoSlideTimer ??= Timer.periodic(
        const Duration(seconds: 4),
        (_) => _advance(),
      );
    } else {
      _autoSlideTimer?.cancel();
      _autoSlideTimer = null;
    }
  }

  void _advance() {
    final banners = _controller.banners;
    if (!_pageController.hasClients || banners.isEmpty) return;
    final next = (_controller.currentIndex + 1) % banners.length;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncAutoSlide();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap(AdBannerModel banner) async {
    final destination = await _controller.handleBannerTap(banner);
    if (destination == null || !mounted) return;
    final launched = await _tryLaunch(destination);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('امکان باز کردن لینک وجود ندارد.')),
      );
    }
  }

  Future<bool> _tryLaunch(Uri uri) async {
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    try {
      if (!await canLaunchUrl(uri)) return false;
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isConfigured) return const SizedBox.shrink();

    if (_controller.initialLoading) {
      return const _AdBannerSkeleton(key: ValueKey('ad_loading_placeholder'));
    }

    if (_controller.errorMessage != null && _controller.banners.isEmpty) {
      return _AdBannerError(
        key: const ValueKey('ad_load_error'),
        message: _controller.errorMessage!,
        onRetry: () => _controller.fetch(force: true),
      );
    }

    final banners = _controller.banners;
    if (banners.isEmpty) return const SizedBox.shrink();

    _syncAutoSlide();
    final safeIndex = _controller.currentIndex.clamp(0, banners.length - 1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: 92,
                child: GestureDetector(
                  onPanDown: (_) {
                    _isDragging = true;
                    _syncAutoSlide();
                  },
                  onPanCancel: () {
                    _isDragging = false;
                    _syncAutoSlide();
                  },
                  onPanEnd: (_) {
                    _isDragging = false;
                    _syncAutoSlide();
                  },
                  child: PageView.builder(
                    key: const ValueKey('ad_banner_page_view'),
                    controller: _pageController,
                    itemCount: banners.length,
                    onPageChanged: _controller.setPageIndex,
                    itemBuilder: (context, index) {
                      final banner = banners[index];
                      return Semantics(
                        label: 'تبلیغ، ${banner.bannerTitle}',
                        button: true,
                        child: GestureDetector(
                          key: ValueKey('ad_banner_${banner.bannerId}'),
                          onTap: () => _handleTap(banner),
                          child: _AdBannerContent(
                            banner: banner,
                            isOpening: _controller.isOpeningLink,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const Positioned(top: -10, right: 14, child: _AdLabel()),
            ],
          ),
          if (banners.length > 1) ...[
            const SizedBox(height: 8),
            _AdIndicator(count: banners.length, index: safeIndex),
          ],
        ],
      ),
    );
  }
}

class _AdBannerContent extends StatelessWidget {
  const _AdBannerContent({required this.banner, required this.isOpening});

  final AdBannerModel banner;
  final bool isOpening;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = [
      banner.campaignTitle,
      banner.sectionName,
    ].where((value) => value.isNotEmpty).join(' • ');

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: Image.network(
                banner.imageUrl.toString(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _AdImageFallback(scheme: scheme),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _AdImageFallback(scheme: scheme, isLoading: true);
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (banner.bannerTitle.isNotEmpty)
                  Text(
                    banner.bannerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isOpening)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            )
          else
            Icon(Icons.open_in_new, size: 20, color: scheme.primary),
        ],
      ),
    );
  }
}

class _AdImageFallback extends StatelessWidget {
  const _AdImageFallback({required this.scheme, this.isLoading = false});

  final ColorScheme scheme;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          isLoading ? Icons.image_outlined : Icons.campaign_outlined,
          color: scheme.onSurfaceVariant,
          size: 28,
        ),
      ),
    );
  }
}

class _AdLabel extends StatelessWidget {
  const _AdLabel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          'تبلیغ',
          style: TextStyle(
            color: scheme.onTertiaryContainer,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AdIndicator extends StatelessWidget {
  const _AdIndicator({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: (active ? scheme.primary : scheme.outlineVariant).withValues(
              alpha: active ? 0.9 : 0.6,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _AdBannerSkeleton extends StatelessWidget {
  const _AdBannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 6),
      child: SizedBox(
        height: 92,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(color: scheme.surfaceContainerHighest),
        ),
      ),
    );
  }
}

class _AdBannerError extends StatelessWidget {
  const _AdBannerError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        margin: EdgeInsets.zero,
        color: scheme.errorContainer.withValues(alpha: 0.4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: scheme.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message, style: TextStyle(color: scheme.onSurface)),
              ),
              TextButton(
                key: const ValueKey('ad_retry_button'),
                onPressed: onRetry,
                child: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
