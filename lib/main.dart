import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme.dart';

const supabaseUrl = 'https://weeoerkjdiqpxgzaofgz.supabase.co';
const supabaseAnonKey = 'sb_publishable_JPsr9LAzNblj5OIGwxumEw_wPL3VwzF';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      title: 'UniFriend',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: session != null ? const DashboardScreen() : const LoginScreen(),
    );
  }
}
