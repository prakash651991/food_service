import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      final authProvider = context.read<AuthProvider>();
      await authProvider.fetchProfile();
      if (!mounted) return;
      if (authProvider.isAdmin) {
        context.go('/admin');
      } else {
        context.go('/customer');
      }
    } else {
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', width: 150, height: 150),
            const SizedBox(height: 24),
            Text(
              'SAAPADU BOX',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Taste of Home. In Every Bite.',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 16),
            ),
            const SizedBox(height: 50),
            CircularProgressIndicator(color: Colors.orange.shade900),
          ],
        ),
      ),
    );
  }
}
