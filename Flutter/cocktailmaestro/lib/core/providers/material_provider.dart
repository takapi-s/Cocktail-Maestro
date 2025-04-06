// MaterialProvider.dart
import 'dart:convert';
import 'package:cocktailmaestro/core/models/material_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class MaterialProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<MaterialModel> _materials = [];
  List<MaterialModel> _myMaterials = [];
  List<MaterialModel> _searchMaterials = [];

  List<MaterialModel> get materials => _materials;
  List<MaterialModel> get myMaterials => _myMaterials;
  List<MaterialModel> get searchMaterials => _searchMaterials;

  Future<void> fetchMaterials() async {
    print('材料データ取得開始...');
    try {
      final querySnapshot =
          await _firestore.collection('materials').orderBy('name').get();

      _materials =
          querySnapshot.docs
              .map((doc) => MaterialModel.fromFirestore(doc))
              .toList();

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('材料データ取得エラー: $e');
      }
    }
  }

  Future<void> searchMaterialsWithCloudflareAndFetchDetails(
    Map<String, String> queryParams,
  ) async {
    try {
      // クエリを組み立て
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final apiUrl = '${dotenv.env["API_URL"]}/material/search?$queryString';

      if (kDebugMode) {
        print('リクエストURL: $apiUrl'); // リクエストURLをログに出力
      }

      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        // ================================
        // UTF-8 デコードを強制的に適用する
        // ================================
        final decodedBody = utf8.decode(response.bodyBytes);

        if (kDebugMode) {
          print('レスポンスデータ (デコード後): $decodedBody');
        }

        final List<dynamic> data = jsonDecode(decodedBody);

        List<MaterialModel> detailedMaterials = [];

        // Cloudflareから取得したIDを元にFirestore詳細取得
        for (var item in data) {
          final id = item['id'];

          if (id == null || id.isEmpty) {
            if (kDebugMode) {
              print('無効なID: $id');
            }
            continue;
          }

          final docSnapshot =
              await FirebaseFirestore.instance
                  .collection('materials')
                  .doc(id)
                  .get();

          if (docSnapshot.exists) {
            final material = MaterialModel.fromFirestore(docSnapshot);
            detailedMaterials.add(material);
          } else {
            if (kDebugMode) {
              print('存在しないドキュメントID: $id');
            }
          }
        }

        // プロバイダーのリストを更新
        _materials = detailedMaterials;
        notifyListeners();

        if (kDebugMode) {
          print('Firestoreからの取得完了。材料件数: ${detailedMaterials.length}');
        }
      } else {
        if (kDebugMode) {
          print(
            'Cloudflare検索APIエラー: ${response.statusCode} - ${response.body}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('検索時エラー: $e');
      }
    }
  }

  Future<void> addMaterial(MaterialModel material) async {
    try {
      // 1. Firestore 登録
      final docRef = await _firestore
          .collection('materials')
          .add(material.toMap());

      // 2. Firestore ID取得
      final String docId = docRef.id;

      // 3. Cloudflare Worker へ通知
      final response = await http.post(
        Uri.parse("${dotenv.env['API_URL']}/material/register"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': docId,
          'name': material.name,
          'categoryMain': material.categoryMain, // ✅ 修正
          'categorySub': material.categorySub, // ✅ 修正
          'apiKey': "${dotenv.env['API_KEY']}",
        }),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Cloudflare通知成功');
        }
      } else {
        if (kDebugMode) {
          print('Cloudflare通知失敗: ${response.body}');
        }
      }

      notifyListeners(); // 変更通知（必要に応じて）
    } catch (e) {
      if (kDebugMode) {
        print('材料登録エラー: $e');
      }
      rethrow; // エラー伝搬も可能
    }
  }

  /// IDから材料を取得するメソッド
  Future<MaterialModel?> getMaterialById(String materialId) async {
    try {
      final docSnapshot =
          await _firestore.collection('materials').doc(materialId).get();

      if (docSnapshot.exists) {
        return MaterialModel.fromFirestore(docSnapshot);
      } else {
        if (kDebugMode) {
          print('指定されたIDの材料が存在しません: $materialId');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('材料取得エラー: $e');
      }
      return null; // エラー時は null を返す
    }
  }

  Future<List<MaterialModel>> getMyMaterials() async {
    print('マイ材料データ取得開始...');
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    // Step 1: OwnedIngredient ID を createdAt順に取得
    final ownedSnapshot =
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('OwnedIngredient')
            .orderBy(
              'createdAt',
              descending: true,
            ) // 昇順。降順は descending: true を追加
            .get();

    final ownedIds = ownedSnapshot.docs.map((doc) => doc.id).toList();
    if (ownedIds.isEmpty) return [];

    // Step 2: materials コレクションから詳細を取得
    final materialSnapshot =
        await _firestore
            .collection('materials')
            .where(FieldPath.documentId, whereIn: ownedIds)
            .get();

    // Step 3: Map に変換して順番を維持
    final materialsMap = {
      for (var doc in materialSnapshot.docs)
        doc.id: MaterialModel.fromJson(doc.data(), doc.id),
    };

    // Step 4: ownedIds の順番で並び替えて返す
    return ownedIds
        .where((id) => materialsMap.containsKey(id))
        .map((id) => materialsMap[id]!)
        .toList();
  }
}
