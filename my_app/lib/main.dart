// For Sale By Owner
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'constants/app_theme.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'screens/main_shell.dart';

// Supplied at build time via `--dart-define=SENTRY_DSN=…`. When absent
// (e.g. local dev or a build without the secret) Sentry stays off.
const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');

// Marks the build as running against staging / alpha / prod so issues
// can be filtered in Sentry. Defaults to 'production' because the
// release builds that go to Play Store are always that.
const String _sentryEnvironment =
    String.fromEnvironment('SENTRY_ENVIRONMENT', defaultValue: 'production');

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = AuthService();
  await authService.init();
  runApp(FSBOApp(authService: authService));
}

void main() async {
  if (_sentryDsn.isEmpty || kDebugMode) {
    // No DSN configured, or we're in debug — skip Sentry so local
    // development doesn't pollute the dashboard with noise.
    await _bootstrap();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.environment = _sentryEnvironment;
      options.tracesSampleRate = 0.1;
      // Don't send personally-identifying request data by default; the
      // backend already has structured logging for that.
      options.sendDefaultPii = false;
    },
    appRunner: _bootstrap,
  );
}

class FSBOApp extends StatelessWidget {
  final AuthService authService;

  const FSBOApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        Provider(create: (_) => ApiService(() => authService.token)),
      ],
      child: MaterialApp(
        title: 'For Sale By Owner',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const MainShell(),
      ),
    );
  }
}
