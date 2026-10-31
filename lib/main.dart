import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zone/app/app.dart';
import 'package:zone/core/config/supabase_config.dart';
import 'package:zone/services/push/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await PushNotificationService.initializeForCurrentPlatform();

  SupabaseClient? supabaseClient;
  Session? initialSession;
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl != null &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey != null &&
      supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
    supabaseClient = Supabase.instance.client;
    initialSession = supabaseClient.auth.currentSession;
  } else {
    debugPrint(
      'Supabase configuration is missing. Set SUPABASE_URL and SUPABASE_ANON_KEY in .env',
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        supabaseClientProvider.overrideWithValue(supabaseClient),
        supabaseInitialSessionProvider.overrideWithValue(initialSession),
      ],
      child: const ZoneApp(),
    ),
  );
}
