import 'package:cached_network_image/cached_network_image.dart';
import 'package:cocktailmaestro/core/models/recipe_model.dart';
import 'package:cocktailmaestro/features/cocktail/view/detail/recipe_detail_screen.dart';
import 'package:flutter/material.dart';

class RecipeList extends StatelessWidget {
  final List<Recipe> recipes;
  final String currentUserId;
  final Future<void> Function(Recipe recipe) deleteRecipe; // 追加

  const RecipeList({
    super.key,
    required this.recipes,
    required this.currentUserId,
    required this.deleteRecipe, // 追加
  });

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return Center(child: Text('レシピがありません'));
    }

    return ListView.builder(
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.only(left: 16, right: 4), // 右の余白を減らす
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child:
                    recipe.fileId.isNotEmpty
                        ? CachedNetworkImage(
                          imageUrl:
                              "https://drive.google.com/uc?export=view&id=${recipe.fileId}",
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          errorWidget:
                              (context, url, error) =>
                                  Icon(Icons.broken_image, size: 40),
                        )
                        : Icon(Icons.local_bar, size: 40),
              ),
            ),

            title: Text(
              recipe.title,
              maxLines: 2,
              softWrap: true, // 折り返しを許可
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    SizedBox(width: 4),
                    Text(
                      recipe.ratingAverage > 0
                          ? recipe.ratingAverage.toStringAsFixed(1)
                          : '評価なし',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  recipe.createdAt.toString().substring(0, 16),
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (recipe.userId == currentUserId)
                  IconButton(
                    icon: Icon(Icons.clear, color: Colors.red),
                    onPressed: () async {
                      bool confirm = await showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: Text('レシピ削除'),
                              content: Text('このレシピを削除しますか？'),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, false),
                                  child: Text('キャンセル'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text('削除'),
                                ),
                              ],
                            ),
                      );
                      if (confirm) {
                        await deleteRecipe(recipe); // コールバック呼び出し
                      }
                    },
                  ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecipeDetailScreen(recipe: recipe),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
