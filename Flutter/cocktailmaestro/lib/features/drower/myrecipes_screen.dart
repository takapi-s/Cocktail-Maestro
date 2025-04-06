import 'package:cocktailmaestro/core/models/recipe_model.dart';
import 'package:cocktailmaestro/core/providers/recipe_provider.dart';
import 'package:cocktailmaestro/widgets/recipe_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyRecipesScreenState createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _favoriteSortBy = 'rating'; // ⭐️ デフォルトは評価順

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<RecipeProvider>(context, listen: false);
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

      try {
        await Future.wait([
          provider.fetchUserRecipes(userId),
          provider.fetchFavoriteRecipes(userId, sortBy: _favoriteSortBy),
        ]);
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching my recipes: $e');
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Widget _buildFavoriteSortDropdown(RecipeProvider provider) {
    return DropdownButton<String>(
      value: _favoriteSortBy,
      onChanged: (value) async {
        if (value != null) {
          setState(() {
            _favoriteSortBy = value;
            _isLoading = true; // ローディング表示
          });
          final userId = FirebaseAuth.instance.currentUser!.uid;
          await provider.fetchFavoriteRecipes(userId, sortBy: value);
          setState(() {
            _isLoading = false;
          });
        }
      },
      items: [
        DropdownMenuItem(value: 'rating', child: Text('評価値順')),
        DropdownMenuItem(value: 'timestamp', child: Text('評価日順')),
      ],
    );
  }

  Widget _buildRecipeList(
    List<Recipe> recipes,
    Future<void> Function() onRefresh,
  ) {
    final provider = Provider.of<RecipeProvider>(context, listen: false);
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child:
          recipes.isEmpty
              ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(child: Text('レシピがありません')),
                  ),
                ],
              )
              : RecipeList(
                recipes: recipes,
                currentUserId: currentUserId,
                deleteRecipe: (recipe) => provider.deleteRecipe(recipe),
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RecipeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('マイレシピ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [Tab(text: '投稿したレシピ'), Tab(text: 'お気に入り')],
        ),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildRecipeList(
                    provider.userRecipes,
                    () => provider.fetchUserRecipes(
                      FirebaseAuth.instance.currentUser!.uid,
                    ),
                  ),
                  Column(
                    children: [
                      // ⭐️ ソート切り替えメニュー
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('並び替え: '),
                            _buildFavoriteSortDropdown(provider),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _buildRecipeList(
                          provider.favoriteRecipes,
                          () => provider.fetchFavoriteRecipes(
                            FirebaseAuth.instance.currentUser!.uid,
                            sortBy: _favoriteSortBy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/addRecipe');
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
