import 'package:cocktailmaestro/core/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _agreedToTerms = false;
  bool _isLoading = false;

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('ログイン')),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _isLoading,
            child: Opacity(
              opacity: _isLoading ? 0.5 : 1.0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap:
                              () => _launchURL(
                                "https://takapi-s.github.io/cocktailmaestro_terms_and_privacy/terms.html",
                              ),
                          child: const Text(
                            '利用規約',
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Text(' / '),
                        GestureDetector(
                          onTap:
                              () => _launchURL(
                                'https://takapi-s.github.io/cocktailmaestro_terms_and_privacy/privacy.html',
                              ),
                          child: const Text(
                            'プライバシーポリシー',
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          onChanged: (bool? value) {
                            setState(() {
                              _agreedToTerms = value ?? false;
                            });
                          },
                        ),
                        const Flexible(
                          child: Text(
                            '利用規約およびプライバシーポリシー\nに同意します',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed:
                          _agreedToTerms
                              ? () async {
                                setState(() {
                                  _isLoading = true;
                                });
                                final result =
                                    await userProvider.signInWithGoogle();
                                if (!mounted) return;
                                setState(() {
                                  _isLoading = false;
                                });

                                if (result == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('ログインに失敗またはキャンセルされました'),
                                    ),
                                  );
                                }
                                // 🔸 遷移は authStateChanges() に任せる
                              }
                              : null,
                      icon: const Icon(Icons.login),
                      label: const Text('Googleでログイン'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
