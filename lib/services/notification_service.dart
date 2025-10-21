// lib/services/notification_service.dart

import 'dart:convert';
import 'dart:io'; // Necessário para Platform
import 'package:flutter/foundation.dart'; // Necessário para kIsWeb
// import 'package:firebase_messaging/firebase_messaging.dart'; // COMENTADO
import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // COMENTADO
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:dc_app/config/api_config.dart';
import 'package:dc_app/main.dart';
import 'package:dc_app/screens/ocorrencia_details_screen.dart'; // Import da tela de detalhes
import 'package:dc_app/services/auth_service.dart';

// ESTA FUNÇÃO PRECISA SER DE NÍVEL SUPERIOR (FORA DE QUALQUER CLASSE)
// COMENTADO: Firebase background handler
// @pragma('vm:entry-point')
// Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   final logger = Logger();
//   logger.i("💥 [BACKGROUND] Notificação em Background Recebida: ${message.messageId}");
//   logger.d("💥 [BACKGROUND] Dados da notificação: ${message.data}");
//   // Se precisar de alguma inicialização extra em background (ex: Firebase.initializeApp()), faça aqui.
// }

// COMENTADO: Classe NotificationService - depende do Firebase
// class NotificationService {
//   final FirebaseMessaging _fcm = FirebaseMessaging.instance;
//   final _logger = Logger();
//   final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
//   FlutterLocalNotificationsPlugin();

//   Future<void> initNotifications() async {
//     // Solicitar permissão ao usuário (iOS e Android 13+)
//     await _requestPermissions();

//     // Inicializar as notificações locais
//     await _initLocalNotifications();

//     // Obter o token FCM
//     final fcmToken = await getFCMToken();
//     if (fcmToken != null) {
//       _logger.i("🔑 SEU TOKEN FCM É: $fcmToken");
//       // Tenta enviar o token para o backend logo após obtê-lo (se o usuário já estiver logado)
//       await sendTokenToServer(fcmToken);
//     }

//     // Configurar os handlers para receber as mensagens
//     _setupMessageHandlers();

//     // Lidar com a notificação que abriu o App do estado TERMINADO
//     checkForInitialMessage();
//   }

//   Future<void> _initLocalNotifications() async {
//     const AndroidInitializationSettings androidSettings =
//     AndroidInitializationSettings('@mipmap/ic_launcher'); // Usa o ícone padrão do app

//     const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();

//     const InitializationSettings settings = InitializationSettings(
//       android: androidSettings,
//       iOS: iosSettings,
//     );

//     await _localNotificationsPlugin.initialize(
//       settings,
//       onDidReceiveNotificationResponse: (details) {
//         final payload = details.payload;
//         _logger.d("Toque na notificação local com payload: $payload");
//         if (payload != null && payload.isNotEmpty) {
//           _handleNavigation(payload);
//         }
//       },
//     );
//   }

//   Future<void> _requestPermissions() async {
//     NotificationSettings settings = await _fcm.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//     );

//     if (settings.authorizationStatus == AuthorizationStatus.authorized) {
//       _logger.i('💡 Permissão de notificação concedida pelo usuário.');
//     } else {
//       _logger.e('❌ Permissão de notificação negada pelo usuário.');
//     }
//   }

//   Future<String?> getFCMToken() async {
//     try {
//       String? token = await _fcm.getToken();
//       return token;
//     } catch (e) {
//       _logger.e("Erro ao obter token FCM", error: e);
//       return null;
//     }
//   }

//   Future<void> sendTokenToServer(String fcmToken) async {
//     // Não executa mais a lógica de mock
//     final authToken = AuthService.token;
//     final userId = AuthService.userId;
//     if (authToken == null || userId == null) {
//       _logger.w("Usuário não autenticado, não é possível enviar token FCM.");
//       return; // Sai se não houver token de autenticação ou ID do usuário
//     }

//     // Endpoint baseado no código original do AuthService
//     final url = Uri.parse('${ApiConfig.baseUrl}/dispositivo/registrar/token/');
//     _logger.i("Enviando token FCM para o backend: $fcmToken");
//     _logger.d("URL do Endpoint: $url");

//     int? deviceType;
//     if (kIsWeb) {
//       deviceType = 3; // Exemplo para Web
//     } else if (Platform.isAndroid) {
//       deviceType = 1; // Android
//     } else if (Platform.isIOS) {
//       deviceType = 2; // iOS
//     }

//     try {
//       final response = await http.post(
//         url,
//         headers: {
//           'Content-Type': 'application/json; charset=UTF-8',
//           'Authorization': 'Token $authToken',
//         },
//         body: json.encode({
//           'token': fcmToken,
//           'usuario': userId,
//           'tipo': deviceType,
//         }),
//       );

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         _logger.i("Token FCM do usuário $userId registrado com sucesso no backend.");
//       } else {
//         _logger.e(
//           "Falha ao registrar o token FCM no backend. Status: ${response.statusCode}",
//           error: response.body,
//         );
//       }
//     } catch (e) {
//       _logger.e("Erro de conexão ao tentar enviar o token FCM para o backend.", error: e);
//     }
//   }

//   void _setupMessageHandlers() {
//     // Criar um canal de notificação para Android (Obrigatório)
//     const AndroidNotificationChannel channel = AndroidNotificationChannel(
//       'high_importance_channel', // id
//       'Notificações Importantes', // title
//       description: 'Este canal é usado para notificações importantes.', // description
//       importance: Importance.max,
//     );
//     _localNotificationsPlugin
//         .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//         ?.createNotificationChannel(channel);


//     // Mensagem recebida com o App em PRIMEIRO PLANO
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       _logger.i('📲 [FOREGROUND] Notificação em Primeiro Plano Recebida!');

//       final notification = message.notification;
//       final android = message.notification?.android;

//       if (notification != null && android != null) {
//         _logger.d('📲 [FOREGROUND] Título: ${notification.title}');
//         _logger.d('📲 [FOREGROUND] Corpo: ${notification.body}');

//         _localNotificationsPlugin.show(
//           notification.hashCode,
//           notification.title,
//           notification.body,
//           NotificationDetails(
//             android: AndroidNotificationDetails(
//               channel.id,
//               channel.name,
//               channelDescription: channel.description,
//               icon: '@mipmap/ic_launcher', // Certifique-se que este ícone existe
//               importance: Importance.max,
//               priority: Priority.high,
//             ),
//             iOS: const DarwinNotificationDetails(),
//           ),
//           // Passa o ID da ocorrência para navegação quando o usuário tocar
//           payload: message.data['ocorrenciaId']?.toString() ?? message.data['ticketId']?.toString() ?? '',
//         );
//       }
//     });

//     // O usuário TOCA na notificação e abre o App (que estava em BACKGROUND)
//     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//       _logger.i("📡 [ABERTURA] O App foi aberto a partir de uma notificação em background!");
//       _logger.d("📡 [ABERTURA] Dados da notificação: ${message.data}");
//       _handleNavigation(message.data['ocorrenciaId']?.toString() ?? message.data['ticketId']?.toString());
//     });
//   }

//   Future<void> checkForInitialMessage() async {
//     RemoteMessage? initialMessage = await _fcm.getInitialMessage();
//     if (initialMessage != null) {
//       _logger.i("📡 [ABERTURA] O App foi aberto a partir de uma notificação com o App FECHADO!");
//       _logger.d("📡 [ABERTURA] Dados da notificação: ${initialMessage.data}");
//       _handleNavigation(initialMessage.data['ocorrenciaId']?.toString() ?? initialMessage.data['ticketId']?.toString());
//     }
//   }

//   // Função centralizada para navegação
//   void _handleNavigation(String? ocorrenciaId) {
//     if (ocorrenciaId != null && ocorrenciaId.isNotEmpty && navigatorKey.currentState != null) {
//       try {
//         final id = int.parse(ocorrenciaId);
//         navigatorKey.currentState!.push(
//           MaterialPageRoute(builder: (context) => OcorrenciaDetailsScreen(ocorrenciaId: id)),
//         );
//       } catch (e) {
//         _logger.e("❌ Erro ao converter ocorrenciaId para inteiro: $ocorrenciaId", error: e);
//       }
//     } else {
//       _logger.w("Não foi possível navegar: ID da ocorrência nulo, vazio ou navigatorKey indisponível.");
//     }
//   }
// }