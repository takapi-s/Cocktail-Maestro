import 'package:cocktailmaestro/core/models/providers/user_provider.dart';
import 'package:cocktailmaestro/features/home_screen.dart';
import 'package:cocktailmaestro/features/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    if (userProvider.shouldShowPolicyDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (_) => AlertDialog(
                title: const Text("ポリシー変更のお知らせ"),
                content: const Text(
                  "プライバシーポリシーまたは利用規約が更新されました。内容をご確認の上、再度同意してください。",
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // 🔽 フラグをリセット（ここが重要）
                      userProvider.clearPolicyDialogFlag();
                    },
                    child: const Text("OK"),
                  ),
                ],
              ),
        );
      });
    }

    if (userProvider.user == null) {
      return const LoginScreen();
    } else {
      return HomeScreen();
    }
  }
}
