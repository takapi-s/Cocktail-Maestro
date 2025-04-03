import 'dart:convert';

import 'package:cocktailmaestro/core/models/recipe_model.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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
}
