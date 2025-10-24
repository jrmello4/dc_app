// lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_links/app_links.dart';
import 'package:dc_app/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dc_app/screens/home_screen.dart';
import 'package:dc_app/services/auth_service.dart';
import 'package:dc_app/screens/login_screen.dart';
import 'package:dc_app/screens/reset_password_screen.dart';

// NOVO: Esquema de cores oficial para a Defesa Civil
const ColorScheme globalColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFFE65100), // Laranja escuro (cor principal)
  onPrimary: Colors.white,
  secondary: Color(0xFFF57C00), // Laranja secundário
  onSecondary: Colors.white,
  error: Color(0xFFD32F2F),
  onError: Colors.white,
  surface: Colors.white, // Cor de cartões e diálogos
  onSurface: Color(0xFF212121),
);

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final _logger = Logger();

// Função do Firebase background handler
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  _logger.d("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicialização do Firebase
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  late Future<bool> _isLoggedInFuture;
  // Notification Service
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _isLoggedInFuture = _initializeApp();
    _initDeepLinks();
    // Inicialização de notificações
    _notificationService.initNotifications();
    _notificationService.checkForInitialMessage();
  }

  Future<bool> _initializeApp() async {
    await AuthService.loadAuthData();
    return AuthService.token != null;
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleLink(initialUri);
      _linkSubscription = _appLinks.uriLinkStream.listen((uri) => _handleLink(uri));
    } catch (e) {
      _logger.e('Erro ao iniciar deep links', error: e);
    }
  }

  void _handleLink(Uri uri) {
    if (uri.pathSegments.contains('reset')) {
      try {
        final uidb64 = uri.pathSegments[uri.pathSegments.indexOf('reset') + 1];
        final token = uri.pathSegments[uri.pathSegments.indexOf('reset') + 2];
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => ResetPasswordScreen(uidb64: uidb64, token: token)),
        );
      } catch (e) {
        _logger.e('Erro ao processar o link de redefinição de senha.', error: e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Defesa Civil App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: globalColorScheme,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: AppBarTheme(
          backgroundColor: globalColorScheme.primary,
          foregroundColor: globalColorScheme.onPrimary,
          elevation: 1.0,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: globalColorScheme.primary,
            foregroundColor: globalColorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          color: globalColorScheme.surface,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: globalColorScheme.primary,
              width: 2.0,
            ),
          ),
        ),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: _isLoggedInFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final isLoggedIn = snapshot.data ?? false;
          return isLoggedIn ? const HomeScreen() : const LoginScreen();
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}