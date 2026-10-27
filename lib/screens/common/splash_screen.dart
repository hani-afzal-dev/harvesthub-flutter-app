import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_logger.dart';
import '../../models/user_model.dart';
import '../../providers/service_providers.dart';
import '../../services/auth_service.dart';
import '../../services/farmer_service.dart';
import '../../services/push_permission.dart';

const Color _pageBg = Color(0xFFF6F8F3);
const Color _brand = Color(0xFF3B6D11);
const Color _brandDark = Color(0xFF2E4A0F);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);

const double _logoSize = 112;
const List<String> _taglines = [
  'Fresh from local farms',
  'Straight from the farmer to you',
  'Order today, pick up today',
  'Support your local growers',
];
const String _unavailableNotice =
    'This account is not available. Please contact support.';
const String _noFarmNotice =
    'Your farm profile is not set up yet. Please contact an administrator.';
const String _offlineNotice =
    'Could not reach HarvestHub. Check your internet connection and log in again.';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  final Stopwatch _clock = Stopwatch()..start();
  Timer? _loaderTimer;
  Timer? _taglineTimer;
  bool _showLoader = false;
  bool _started = false;
  int _taglineIndex = 0;

  @override
  void initState() {
    super.initState();
    _loaderTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showLoader = true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveDestination());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _intro.value = 1;
    } else {
      _intro.forward();
      _taglineTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
        if (mounted) {
          setState(() => _taglineIndex = (_taglineIndex + 1) % _taglines.length);
        }
      });
    }
  }

  @override
  void dispose() {
    _loaderTimer?.cancel();
    _taglineTimer?.cancel();
    _intro.dispose();
    super.dispose();
  }

  String _homeRouteFor(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return '/home';
      case UserRole.admin:
        return '/admin-home';
      case UserRole.farmer:
        return '/farmer-home';
    }
  }

  Future<void> _resolveDestination() async {
    final authService = ref.read(authServiceProvider);
    final firebaseUser = authService.currentUser;
    if (firebaseUser == null) {
      await _go('/roles');
      return;
    }

    final cached = await authService.getCachedUserProfile(firebaseUser.uid);
    if (!mounted) return;
    if (cached != null && cached.isActive) {
      final navigator = Navigator.of(context);
      final farmerService = ref.read(farmerServiceProvider);
      unawaited(ref.read(pushTokenServiceProvider).saveCurrent());
      unawaited(askForPushPermission());
      await _go(_homeRouteFor(cached.role));
      unawaited(
          _verifyInBackground(navigator, authService, farmerService, cached));
      return;
    }

    try {
      final serverFetch = authService.getUserProfile(firebaseUser.uid);
      serverFetch.ignore();
      UserModel? user;
      try {
        user = await serverFetch.timeout(const Duration(milliseconds: 2500));
      } on TimeoutException {
        user = await serverFetch;
      }
      if (!mounted) return;
      if (user == null || !user.isActive) {
        await authService.logout();
        await _go('/roles', arguments: _unavailableNotice);
        return;
      }

      if (user.role == UserRole.farmer) {
        final farmer =
            await ref.read(farmerServiceProvider).getByUserId(user.userId);
        if (!mounted) return;
        if (farmer == null) {
          await authService.logout();
          await _go('/roles', arguments: _noFarmNotice);
          return;
        }
      }

      unawaited(ref.read(pushTokenServiceProvider).saveCurrent());
      unawaited(askForPushPermission());
      await _go(_homeRouteFor(user.role));
    } catch (e, stack) {
      AppLogger.error('Startup routing failed', e, stack);
      await _go('/roles', arguments: _offlineNotice);
    }
  }

  Future<void> _verifyInBackground(
    NavigatorState navigator,
    AuthService authService,
    FarmerService farmerService,
    UserModel cached,
  ) async {
    String? notice;
    try {
      final user = await authService.getUserProfile(cached.userId);
      if (user == null || !user.isActive || user.role != cached.role) {
        notice = _unavailableNotice;
      } else if (user.role == UserRole.farmer) {
        final farmer = await farmerService.getByUserId(user.userId);
        if (farmer == null) notice = _noFarmNotice;
      }
    } catch (e, stack) {
      AppLogger.error('Background profile check failed', e, stack);
      return;
    }
    if (notice == null) return;

    await authService.logout();
    if (!navigator.mounted) return;
    navigator.pushNamedAndRemoveUntil('/roles', (route) => false,
        arguments: notice);
  }

  Future<void> _go(String route, {Object? arguments}) async {
    const minimumVisible = Duration(milliseconds: 450);
    final remaining = minimumVisible - _clock.elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);
    if (!mounted) return;
    _loaderTimer?.cancel();
    Navigator.of(context).pushReplacementNamed(route, arguments: arguments);
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    final textSlide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
            .animate(fade);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _pageBg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _pageBg,
        body: Semantics(
          label: 'HarvestHub is loading',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final centerY = constraints.maxHeight / 2;
              return Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.35),
                          radius: 1.2,
                          colors: [
                            _brand.withValues(alpha: 0.32),
                            _pageBg,
                          ],
                          stops: const [0.0, 0.75],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: centerY - _logoSize * 0.65,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: SizedBox(
                        width: _logoSize * 1.3,
                        height: _logoSize * 1.3,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            FadeTransition(
                              opacity: fade,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      _brand.withValues(alpha: 0.45),
                                      _brand.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            ScaleTransition(
                              scale: Tween<double>(begin: 0.92, end: 1)
                                  .animate(fade),
                              child: Container(
                                width: _logoSize,
                                height: _logoSize,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _brandDark.withValues(alpha: 0.18),
                                      blurRadius: 28,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: Image.asset(
                                    'assets/icon/splash_logo.png',
                                    fit: BoxFit.cover,
                                    excludeFromSemantics: true,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const ColoredBox(
                                      color: _brand,
                                      child: Icon(Icons.eco,
                                          size: 56, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: centerY + _logoSize / 2 + 24,
                    left: 24,
                    right: 24,
                    child: FadeTransition(
                      opacity: fade,
                      child: SlideTransition(
                        position: textSlide,
                        child: Column(
                          children: [
                            const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'HarvestHub',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                  color: _textMain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              child: Text(
                                _taglines[_taglineIndex],
                                key: ValueKey(_taglineIndex),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: _textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.paddingOf(context).bottom + 40,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _showLoader ? 1 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: SizedBox(
                          width: 56,
                          height: 4,
                          child: _showLoader
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: const LinearProgressIndicator(
                                    minHeight: 4,
                                    color: _brand,
                                    backgroundColor: Color(0xFFDDE5D3),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
