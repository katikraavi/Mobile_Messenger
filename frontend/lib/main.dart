import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider_pkg;
// Firebase disabled for now - will be enabled before launch
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'firebase_options.dart';
// import 'package:frontend/core/push_notifications/push_notification_handler.dart';
import 'package:frontend/app.dart';
import 'package:frontend/core/notifications/app_feedback_service.dart';
import 'package:frontend/core/services/app_exception_logger.dart';
import 'package:frontend/core/services/api_client.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:media_kit/media_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppExceptionLogger.log(
      details.exception,
      stackTrace: details.stack,
      context: 'FlutterError.onError',
      fatal: true,
    );
    AppFeedbackService.showError(
      'Something went wrong. Messenger kept the last stable screen when possible.',
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'platform dispatcher',
        context: ErrorDescription('while handling an uncaught asynchronous error'),
      ),
    );
    AppExceptionLogger.log(
      error,
      stackTrace: stackTrace,
      context: 'PlatformDispatcher.onError',
      fatal: true,
    );
    AppFeedbackService.showError(
      'A background error occurred. Messenger restored the last stable state when possible.',
    );
    return true;
  };
  
  // TODO: Firebase messaging will be enabled before launch
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );
  // FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Initialize API client before running app
  await ApiClient.initialize();
  
  runApp(
    ProviderScope(
      child: provider_pkg.MultiProvider(
        providers: [
          provider_pkg.ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(),
          ),
        ],
        child: const MessengerApp(),
      ),
    ),
  );
}

