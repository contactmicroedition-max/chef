import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zone/app/app.dart';
import 'package:zone/core/config/supabase_config.dart';
import 'package:zone/core/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await PushNotificationService.initializeForCurrentPlatform();

  SupabaseConfig.initialSession = null;
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
    SupabaseConfig.client = Supabase.instance.client;
    SupabaseConfig.initialSession =
        Supabase.instance.client.auth.currentSession;
  } else {
    debugPrint(
      'Supabase configuration is missing. Set SUPABASE_URL and SUPABASE_ANON_KEY in .env',
    );
  }

  runApp(const ProviderScope(child: ZoneApp()));
}
