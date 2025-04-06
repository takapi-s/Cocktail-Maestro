import 'dart:convert';

import 'package:cocktailmaestro/core/models/recipe_ingredient_model.dart';
import 'package:cocktailmaestro/core/models/recipe_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class RecipeProvider extends ChangeNotifier {
  List<Recipe> _latestRecipes = [];
  List<Recipe> _popularRecipes = [];
  List<Recipe> _searchResults = []; // 🔑 追加：検索結果用
  List<Recipe> _userRecipes = [];
  List<Recipe> _favoriteRecipes = [];
  List<Recipe> _forYouRecipes = [];

  List<Recipe> get latestRecipes => _latestRecipes;
  List<Recipe> get popularRecipes => _popularRecipes;
  List<Recipe> get searchResults => _searchResults; // 🔑 追加：検索結果
  List<Recipe> get userRecipes => _userRecipes;
  List<Recipe> get favoriteRecipes => _favoriteRecipes;
  List<Recipe> get forYouRecipes => _forYouRecipes;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool? get isLoading => null;
  Future<void> fetchForYouRecipesFromCloud(String userId) async {
    try {
      final uri = Uri.parse('${dotenv.env['API_URL']}/recommend?uid=$userId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<String> ids = List<String>.from(data['recommendationIds']);

        if (ids.isEmpty) {
          _forYouRecipes = [];
        } else {
          _forYouRecipes = await fetchRecipesByKeys(ids);
        }
        notifyListeners();
      } else {
        if (kDebugMode) {
          print('APIエラー: ${response.statusCode} ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('クラウドレコメンド取得エラー: $e');
      }
      _forYouRecipes = [];
      notifyListeners();
    }
  }

  Future<void> fetchUserRecipes(String userId) async {
    try {
      final snapshot =
          await _firestore
              .collection('recipes')
              .where('userId', isEqualTo: userId)
              .get();

      _userRecipes =
          snapshot.docs
              .map<Recipe>((doc) => Recipe.fromJson(doc.data(), doc.id))
              .toList();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('エラー: $e');
      }
    }
  }

  // RecipeProvider.dart 側
  Future<void> fetchFavoriteRecipes(
    String userId, {
    String sortBy = 'rating',
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .doc(userId)
          .collection('ratedRecipes');

      if (sortBy == 'rating') {
        query = query.orderBy('rating', descending: true);
      } else if (sortBy == 'timestamp') {
        query = query.orderBy('timestamp', descending: true);
      }

      final querySnapshot = await query.get();

      List<String> favoriteRecipeIds =
          querySnapshot.docs.map((doc) => doc.id).toList();

      if (favoriteRecipeIds.isNotEmpty) {
        final recipeSnapshot =
            await _firestore
                .collection('recipes')
                .where(FieldPath.documentId, whereIn: favoriteRecipeIds)
                .get();

        _favoriteRecipes =
            recipeSnapshot.docs
                .map<Recipe>((doc) => Recipe.fromJson(doc.data(), doc.id))
                .toList();
      } else {
        _favoriteRecipes = [];
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('エラー: $e');
      }
    }
  }

  // 最新レシピ取得
  Future<void> fetchLatestRecipes() async {
    final snapshot =
        await _firestore
            .collection('recipes')
            .orderBy('createdAt', descending: true)
            .limit(20)
            .get();

    _latestRecipes =
        snapshot.docs
            .map<Recipe>((doc) => Recipe.fromJson(doc.data(), doc.id))
            .toList();

    notifyListeners();
  }

  // 人気レシピ（評価が高い順）
  Future<void> fetchPopularRecipes() async {
    final snapshot =
        await _firestore
            .collection('recipes')
            .orderBy('ratingAverage', descending: true)
            .limit(20)
            .get();
    _popularRecipes =
        snapshot.docs
            .map<Recipe>((doc) => Recipe.fromJson(doc.data(), doc.id))
            .toList();
    notifyListeners();
  }

  Future<List<String>> searchRecipeKeys(String query) async {
    final uri = Uri.parse(
      '${dotenv.env['API_URL']}/search?q=${Uri.encodeComponent(query)}',
    );
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      final keys =
          jsonList.map<String>((json) => json['key'] as String).toList();
      return keys;
    } else {
      if (kDebugMode) {
        print('検索API失敗: ${response.statusCode}');
      }
      return [];
    }
  }

  Future<List<Recipe>> fetchRecipesByKeys(List<String> keys) async {
    final List<Recipe> recipes = [];

    for (final key in keys) {
      final doc = await _firestore.collection('recipes').doc(key).get();
      if (doc.exists) {
        recipes.add(Recipe.fromJson(doc.data()!, doc.id));
      }
    }

    return recipes;
  }

  // 🔽 レシピ名 or 材料名から検索する関数
  Future<void> searchRecipes(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    try {
      // ✅ まずCloudflare APIで key 一覧を取得
      final keys = await searchRecipeKeys(query);
      if (keys.isEmpty) {
        _searchResults = [];
        notifyListeners();
        return;
      }

      // ✅ 次に key をもとに Firestore から詳細データ取得
      _searchResults = await fetchRecipesByKeys(keys);
    } catch (e) {
      if (kDebugMode) {
        print('検索中にエラー: $e');
      }
      _searchResults = [];
    }

    notifyListeners();
  }

  // 🔽 レシピ削除関数
  Future<void> deleteRecipe(Recipe recipe) async {
    print('レシピ削除: ${recipe.id}');
    try {
      // ======================
      // 3. ローカルリストから削除
      // ======================
      _latestRecipes.removeWhere((r) => r.id == recipe.id);
      _popularRecipes.removeWhere((r) => r.id == recipe.id);
      _searchResults.removeWhere((r) => r.id == recipe.id);
      _forYouRecipes.removeWhere((r) => r.id == recipe.id);
      _userRecipes.removeWhere((r) => r.id == recipe.id);

      // ======================
      // 4. リスナー通知
      // ======================
      notifyListeners();

      // ======================
      // 1. Firestore から削除
      // ======================
      await _firestore.collection('recipes').doc(recipe.id).delete();

      // ======================
      // 2. Cloudflare (Hono) へ削除依頼
      // ======================
      final response = await http.post(
        Uri.parse("${dotenv.env['API_URL']}/delete"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'recipeId': recipe.id,
          'apiKey': "${dotenv.env['API_KEY']}",
          // R2, GAS 側のファイル削除に必要
          'fileId': recipe.fileId,
        }),
      );

      if (response.statusCode == 200) {
        final resBody = jsonDecode(response.body);
        if (kDebugMode) {
          ('Cloudflare側削除成功: $resBody');
        }
      } else {
        if (kDebugMode) {
          print('Cloudflare側削除失敗: ${response.statusCode} ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('レシピ削除失敗: $e');
      }
    }
  }

  Future<void> updateRecipe({
    required Recipe originalRecipe,
    required String title,
    required String description,
    required List<RecipeIngredient> ingredients,
    required List<String> steps,
    required List<String> tags,
    required double alcoholStrength,
    XFile? image,
    String? glass,
  }) async {
    try {
      final docRef = _firestore.collection('recipes').doc(originalRecipe.id);

      String fileId = originalRecipe.fileId;

      // ========================
      // Cloudflare側のindex.json更新＋画像アップロード（任意）
      // ========================
      final body = {
        'recipeId': originalRecipe.id,
        'apiKey': dotenv.env['API_KEY'],
        'recipeInfo': {
          'name': title,
          'ingredients':
              ingredients
                  .map((e) => e.name.trim())
                  .where((name) => name.isNotEmpty)
                  .toList(),
          'tags': tags,
          'glass': glass,
        },
      };
      print('Cloudflareに送信するbody: ${jsonEncode(body)}');

      // 画像がある場合、base64とfileNameを追加
      if (image != null) {
        final bytes = await image.readAsBytes();
        body['imageBase64'] = base64Encode(bytes);
        body['fileName'] = image.name;
      }

      final response = await http.post(
        Uri.parse('${dotenv.env['API_URL']}/edit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        fileId = result['fileId'] ?? fileId;

        print("Cloudflare更新成功: fileId=$fileId");
        print("Cloudflare更新後データ: ${result['updated']}");
      } else {
        debugPrint('Cloudflare側の編集失敗: ${response.statusCode} ${response.body}');
      }

      // ========================
      // Firestore側の更新
      // ========================
      await docRef.update({
        'title': title,
        'description': description,
        'fileId': fileId,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'steps': steps,
        'tags': tags,
        'glass': glass,
        'alcoholStrength': alcoholStrength,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      notifyListeners();
    } catch (e) {
      debugPrint('レシピ更新エラー: $e');
      rethrow;
    }
  }

  Future<void> addRecipe({
    required String title,
    required String description,
    required List<RecipeIngredient> ingredients,
    required List<String> steps,
    required List<String> tags,
    required double alcoholStrength,
    required String glass,
    XFile? image,
  }) async {
    try {
      final userId = _auth.currentUser?.uid ?? '';
      String fileId = '';
      String newDocId = _firestore.collection('recipes').doc().id;

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        final fileName = image.name;

        final response = await http.post(
          Uri.parse('${dotenv.env['API_URL']}/upload'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'newDocID': newDocId,
            'apiKey': dotenv.env['API_KEY'],
            'recipeInfo': {
              'name': title,
              'ingredients':
                  ingredients
                      .map((e) => e.name.trim())
                      .where((name) => name.isNotEmpty)
                      .toList(),
              'tags': tags,
              'glass': glass,
            },
            'imageBase64': base64Image,
            'fileName': fileName,
          }),
        );

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          fileId = result['fileId'] ?? '';
        } else {
          debugPrint(
            'Cloudflare画像アップロード失敗: ${response.statusCode} ${response.body}',
          );
        }
      }

      final newRecipe = Recipe(
        id: newDocId,
        userId: userId,
        title: title,
        description: description,
        fileId: fileId,
        ingredients: ingredients,
        steps: steps,
        tags: tags,
        glass: glass,
        alcoholStrength: alcoholStrength,
        createdAt: DateTime.now(),
        ratingAverage: 0.0,
        ratingCount: 0,
      );

      await _firestore
          .collection('recipes')
          .doc(newDocId)
          .set(newRecipe.toJson());

      _latestRecipes.insert(0, newRecipe); // 必要に応じて追加
      _userRecipes.add(newRecipe);

      notifyListeners();
    } catch (e) {
      debugPrint('レシピ追加失敗: $e');
      rethrow;
    }
  }
}
