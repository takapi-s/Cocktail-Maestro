import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 追加

/// 不具合報告ダイアログを表示する共通関数
Future<void> showReportDialog({
  required BuildContext context,
  required String reportType, // 'app' | 'recipe' | 'material' など
  String? recipeId,
  String? materialId,
}) async {
  final TextEditingController controller = TextEditingController();
  final userId = FirebaseAuth.instance.currentUser?.uid;

  if (userId == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ユーザー情報が取得できません')));
    return;
  }

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('不具合を報告する'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(hintText: '不具合の内容を記入してください'),
        ),
        actions: [
          TextButton(
            child: const Text('キャンセル'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('送信'),
            onPressed: () async {
              final description = controller.text.trim();
              if (description.isEmpty) return;

              try {
                final Map<String, dynamic> reportData = {
                  'type': reportType,
                  'userId': userId,
                  'description': description,
                  'timestamp': FieldValue.serverTimestamp(),
                  'status': 'pending',
                };

                if (recipeId != null) {
                  reportData['recipeId'] = recipeId;
                }

                if (materialId != null) {
                  reportData['materialId'] = materialId;
                }

                await FirebaseFirestore.instance
                    .collection('reports')
                    .add(reportData);

                final webhookUrl = dotenv.env['DISCORD_WEBHOOK_URL'];
                if (webhookUrl != null && webhookUrl.isNotEmpty) {
                  final discordMessage = {
                    'content':
                        '🛠️ **不具合が報告されました**\n'
                        '**種類**: $reportType\n'
                        '**ユーザーID**: $userId\n'
                        '${recipeId != null ? "**レシピID**: $recipeId\n" : ""}'
                        '${materialId != null ? "**材料ID**: $materialId\n" : ""}'
                        '**内容**:\n$description',
                  };

                  await http.post(
                    Uri.parse(webhookUrl),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode(discordMessage),
                  );
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('不具合が報告されました')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('報告に失敗しました: $e')));
                }
              }
            },
          ),
        ],
      );
    },
  );
}
