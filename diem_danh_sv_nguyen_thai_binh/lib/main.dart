import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/token_storage.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final storage = TokenStorage();
  runApp(MultiProvider(
    providers: [
      Provider<ApiService>(create: (_) => ApiService(storage)),
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider(storage)..restore()),
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
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (!auth.ready) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}
