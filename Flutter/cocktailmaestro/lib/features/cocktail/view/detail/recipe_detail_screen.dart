import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocktailmaestro/core/models/recipe_model.dart';
import 'package:cocktailmaestro/core/models/providers/material_provider.dart';
import 'package:cocktailmaestro/core/utils/report_dialog.dart';
import 'package:cocktailmaestro/features/cocktail/view/detail/recipe_form_screen.dart';
import 'package:cocktailmaestro/features/mybar/detail/material_detail_page.dart';
import 'package:cocktailmaestro/widgets/tag_display.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // 日付フォーマットのため

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({required this.recipe, super.key});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  double? _userRating; // ユーザーの評価（null なら未評価）
  Recipe? _recipe; // 取得して表示する用のレシピ情報
  double? _pendingRating; // ★ 送信用 (遷移時送信)
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isRatingLoaded = false; // ⭐️ 追加: 評価の読み込み完了フラグ

  void _onRatingSelected(double rating) {
    setState(() {
      _userRating = rating; // 即座にUI反映
      _pendingRating = rating; // 遷移時に送るために記録
    });
  }

  Future<void> fetchRecipe(String recipeId) async {
    final doc = await _firestore.collection('recipes').doc(recipeId).get();
    if (doc.exists) {
      if (!mounted) return; // ★ このチェックを追加することで安全に！

      final data = doc.data()!;

      setState(() {
        _recipe = Recipe.fromJson(data, doc.id);
      });
    }
  }

  Future<void> fetchUserRating(String recipeId) async {
    final String userId = _auth.currentUser!.uid;
    final userRatingRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('ratedRecipes')
        .doc(recipeId); // サブコレクション + レシピID

    final snapshot = await userRatingRef.get();

    if (snapshot.exists) {
      final rating = snapshot.data()!['rating']?.toDouble();
      setState(() {
        _userRating = rating;
        _pendingRating = rating;
        _isRatingLoaded = true;
      });
    } else {
      setState(() {
        _isRatingLoaded = true;
      });
    }
  }

  Future<void> submitRating(String recipeId, double rating) async {
    final String userId = _auth.currentUser!.uid;
    final recipeRef = _firestore.collection('recipes').doc(recipeId);
    final userRatingRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('ratedRecipes')
        .doc(recipeId); // サブコレクション + レシピID
    try {
      await _firestore.runTransaction((transaction) async {
        final recipeSnapshot = await transaction.get(recipeRef);
        final usersSnapshot = await transaction.get(userRatingRef);

        if (!recipeSnapshot.exists) throw Exception("レシピが存在しません");

        final recipeData = recipeSnapshot.data()!;
        final double ratingSum = (recipeData['ratingSum'] ?? 0).toDouble();
        final int ratingCount = (recipeData['ratingCount'] ?? 0);

        double? oldRating =
            usersSnapshot.exists
                ? usersSnapshot.data()!['rating']?.toDouble()
                : null;

        double newRatingSum = ratingSum;
        int newRatingCount = ratingCount;

        if (oldRating == null) {
          // 新規評価
          newRatingSum += rating;
          newRatingCount += 1;
        } else {
          // 既存評価の更新
          newRatingSum = newRatingSum - oldRating + rating;
        }

        // 新しい平均
        final newRatingAverage = double.parse(
          (newRatingSum / newRatingCount).toStringAsFixed(2),
        );

        // Firestore 更新
        transaction.update(recipeRef, {
          'ratingSum': newRatingSum,
          'ratingCount': newRatingCount,
          'ratingAverage': newRatingAverage,
        });

        // ユーザーの評価も保存（サブコレクション内に）
        transaction.set(userRatingRef, {
          'rating': rating,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
      if (kDebugMode) {
        print('トランザクション成功');
      }
    } catch (e) {
      if (kDebugMode) {
        print('トランザクション失敗: $e');
      }
    }

    if (kDebugMode) {
      print('評価が送信されました');
    }
  }

  IconData _getGlassIcon(double strength) {
    if (strength < 10) return Icons.wine_bar; // 軽め
    if (strength < 20) return Icons.local_bar; // 普通
    return Icons.liquor; // 強め
  }

  bool isMyRecipe() {
    final currentUser = _auth.currentUser;
    return currentUser != null && currentUser.uid == _recipe?.userId;
  }

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe; // 初期表示は渡されたレシピ
    fetchRecipe(widget.recipe.id); // 最新情報に更新
    fetchUserRating(widget.recipe.id); // ★ 画面が生きてる場合だけ
  }

  // ⭐️ 画面離脱時に評価送信
  @override
  void dispose() {
    // 送信すべき評価が存在すれば送信
    if (_pendingRating != null) {
      if (kDebugMode) {
        print('評価送信: ${widget.recipe.id} $_pendingRating');
      }
      submitRating(widget.recipe.id, _pendingRating!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipe = _recipe;
    if (recipe == null || !_isRatingLoaded) {
      if (kDebugMode) {
        print('レシピが取得できていないか、評価が読み込まれていません');
      }
      // ⭐️ 評価読み込みも考慮
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final formattedDate = DateFormat('yyyy-MM-dd').format(recipe.createdAt);
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          if (isMyRecipe())
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeFormScreen(recipe: recipe),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed:
                () => showReportDialog(
                  context: context,
                  reportType: 'recipe',
                  recipeId: widget.recipe.id,
                ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 画像表示
            if (recipe.fileId.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl:
                      "https://drive.google.com/uc?export=view&id=${recipe.fileId}",
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.contain,
                  placeholder:
                      (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),

            const SizedBox(height: 16),

            // タイトルと評価
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  recipe.title,

                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis, // 長い場合に省略
                  maxLines: 2, // 1行だけ表示
                ),

                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    Text(
                      recipe.ratingAverage.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const Spacer(), // これが左と右の要素の間を広げて右寄せにする
                    const Text(
                      '推定アルコール度数',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),
                    Text(
                      '${recipe.alcoholStrength.toStringAsFixed(1)} %',
                      style: TextStyle(fontSize: 16),
                    ),

                    Icon(_getGlassIcon(recipe.alcoholStrength), size: 30),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('グラス: ${recipe.glass}', style: const TextStyle(fontSize: 14)),

            // タグ表示（タグがあれば）
            if (recipe.tags.isNotEmpty) ...[
              TagDisplay(tags: recipe.tags),
              const SizedBox(height: 16),
            ],
            // 作成日
            Text(
              '投稿日: $formattedDate',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // 説明文
            const Text(
              '説明',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(recipe.description, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),

            // 材料リスト
            // 材料リスト表示（修正版）
            const Text(
              '材料',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...recipe.ingredients.map((ingredient) {
              final hasMaterialId = ingredient.materialId.isNotEmpty;

              return GestureDetector(
                onTap:
                    hasMaterialId
                        ? () async {
                          try {
                            final materialProvider =
                                Provider.of<MaterialProvider>(
                                  context,
                                  listen: false,
                                );
                            final material = await materialProvider
                                .getMaterialById(ingredient.materialId);
                            if (material != null) {
                              Navigator.push(
                                // ignore: use_build_context_synchronously
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => MaterialDetailPage(
                                        material: material,
                                      ),
                                ),
                              );
                            } else {
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('材料が見つかりませんでした')),
                              );
                            }
                          } catch (e) {
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('エラーが発生しました: $e')),
                            );
                          }
                        }
                        : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    '・${ingredient.name} ${ingredient.amount} ${ingredient.unit}',
                    style: TextStyle(
                      fontSize: 16,
                      color: hasMaterialId ? Colors.blue : Colors.black,
                      decoration:
                          hasMaterialId
                              ? TextDecoration.underline
                              : TextDecoration.none,
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // 手順
            const Text(
              '手順',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...recipe.steps.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  '${entry.key + 1}. ${entry.value}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16), // ★ ここから評価UI ★
            // 評価UI部分
            const Text(
              'このレシピを評価する',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return IconButton(
                  icon: Icon(
                    _userRating != null && _userRating! >= starIndex
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () => _onRatingSelected(starIndex.toDouble()),
                );
              }),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
