// GAS API に画像＋レシピ情報をアップロード
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class UploadResult {
  final String fileId;
  final String recipeId;

  UploadResult({required this.fileId, required this.recipeId});
}

Future<UploadResult> uploadRecipeWithImage({
  required XFile image,
  required String name,
  required List<Map<String, dynamic>> ingredients,
}) async {
  final bytes = await image.readAsBytes();
  final base64Image = base64Encode(bytes);
  final fileName = image.name;

  /// 画像とレシピ情報をアップロード
  final url = Uri.parse(
    '${dotenv.env['API_URL']}/upload', // Cloudflare WorkerのURL
  );

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'imageBase64': base64Image, // 画像データ
        'fileName': fileName, // 画像ファイル名
        'apiKey': '${dotenv.env['API_KEY']}', // 認証キー
        'recipeInfo': {
          'name': name, // レシピ名
          'ingredients': ingredients, // 材料
        },
      }),
    );

    if (response.statusCode == 200) {
      final contentType = response.headers['content-type'];
      if (contentType != null && contentType.contains('application/json')) {
        final responseData = jsonDecode(response.body);

        return UploadResult(
          fileId: responseData["fileId"],
          recipeId: responseData["recipeId"],
        );
      } else {
        throw Exception('Unexpected response format: ${response.body}');
      }
    } else {
      throw Exception('サーバエラー: ${response.statusCode}');
    }
  } catch (e) {
    if (kDebugMode) {
      print("通信エラー: $e");
    }
    rethrow;
  }
}
