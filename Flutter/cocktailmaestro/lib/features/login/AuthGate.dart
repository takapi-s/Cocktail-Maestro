import 'package:cocktailmaestro/core/providers/user_provider.dart';
import 'package:cocktailmaestro/features/home_screen.dart';
import 'package:cocktailmaestro/features/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// AuthGate.dart
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    if (userProvider.user == null) {
      return const LoginScreen();
    } else {
      return const HomeScreen();
    }
  }
}
