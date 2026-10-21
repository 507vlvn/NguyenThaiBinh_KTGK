import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'core/token_storage.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';

// Dùng để đóng các màn hình đang mở và hiện thông báo khi phiên đăng nhập hết hạn.
final _navigatorKey = GlobalKey<NavigatorState>();
final _messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final storage = TokenStorage();
  final auth = AuthProvider(storage)..restore();
  final api = ApiService(storage, onUnauthorized: () async {
    if (!await auth.expireSession()) return;
    _navigatorKey.currentState?.popUntil((r) => r.isFirst);
    _messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.')),
    );
  });
  runApp(MultiProvider(
    providers: [
      Provider<ApiService>.value(value: api),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
    ],
    child: const DiemDanhApp(),
  ));
}

class DiemDanhApp extends StatelessWidget {
  const DiemDanhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Điểm danh SV',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (!auth.ready) return const _SplashScreen();
          return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.how_to_reg_rounded, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text('Điểm danh SV', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
