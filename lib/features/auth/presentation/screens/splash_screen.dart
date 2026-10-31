import 'package:flutter/material.dart';
import 'package:zone/features/auth/presentation/widgets/chef_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: CHEFLogo()),
    );
  }
}
