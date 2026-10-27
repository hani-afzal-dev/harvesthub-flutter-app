import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'core/app_logger.dart';
import 'core/background_task.dart';
import 'core/crash_reporter.dart';
import 'firebase_options.dart';
import 'models/push_target.dart';
import 'models/user_model.dart';
import 'providers/push_providers.dart';
import 'screens/auth/login_screen.dart';
import 'screens/common/role_selection_screen.dart';
import 'screens/common/splash_screen.dart';
import 'screens/customer/customer_shell.dart';
import 'screens/farmer/farmer_shell.dart';
import 'screens/admin/admin_shell.dart';
import 'services/push_token_service.dart';
import 'widgets/account_status_guard.dart';
import 'widgets/in_app_notification_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e, stack) {
    debugPrint('Startup failed: $e');
    debugPrint(stack.toString());
    runApp(const StartupErrorApp());
    return;
  }

  runInBackground('Crash reporting setup failed', CrashReporter.init);

  final container = ProviderContainer();

  try {
    final oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'] ?? '';
    if (oneSignalAppId.isNotEmpty) {
      OneSignal.initialize(oneSignalAppId);
      PushTokenService().listenForChanges();

      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        event.notification.display();
      });

      OneSignal.Notifications.addClickListener((event) {
        final target = PushTarget.fromData(event.notification.additionalData);
        if (target != null) {
          container.read(pendingPushTargetProvider.notifier).state = target;
        }
      });
    }
  } catch (e, stack) {
    AppLogger.error('Push setup failed', e, stack);
  }

  runApp(UncontrolledProviderScope(
      container: container, child: const HarvestHubApp()));
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF6F8F3),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 48, color: Color(0xFF3B6D11)),
                  const SizedBox(height: 16),
                  const Text(
                    'HarvestHub could not start',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF22301A)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Something went wrong while starting the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7A5E)),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: main,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3B6D11),
                      minimumSize: const Size(160, 48),
                    ),
                    child: const Text('Try again'),
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

class HarvestHubApp extends StatelessWidget {
  const HarvestHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HarvestHub',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)
      ],
      builder: (context, child) {
        return InAppNotificationOverlay(
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3B6D11),
        scaffoldBackgroundColor: const Color(0xFFF6F8F3),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF22301A),
          contentTextStyle: const TextStyle(fontSize: 14, color: Colors.white),
          actionTextColor: const Color(0xFFB9D98F),
          insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          elevation: 6,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titleTextStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF22301A)),
          contentTextStyle: const TextStyle(
              fontSize: 14, height: 1.45, color: Color(0xFF4C5943)),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          showDragHandle: false,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF3B6D11),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
            minimumSize: const Size(48, 44),
          ),
        ),
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: Color(0xFF3B6D11)),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/roles': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return RoleSelectionScreen(notice: args is String ? args : null);
        },
        '/login': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return LoginScreen(role: args is UserRole ? args : UserRole.customer);
        },
        '/home': (_) => const AccountStatusGuard(child: CustomerShell()),
        '/farmer-home': (_) => const AccountStatusGuard(child: FarmerShell()),
        '/admin-home': (_) => const AdminShell(),
      },
    );
  }
}
