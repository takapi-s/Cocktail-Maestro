import 'package:cocktailmaestro/core/providers/recipe_provider.dart';
import 'package:cocktailmaestro/widgets/recipe_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ForYouRecipesView extends StatefulWidget {
  const ForYouRecipesView({super.key});

  @override
  State<ForYouRecipesView> createState() => _ForYouRecipesViewState();
}

class _ForYouRecipesViewState extends State<ForYouRecipesView>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadForYouRecipes();
  }

  Future<void> _loadForYouRecipes() async {
    final provider = Provider.of<RecipeProvider>(context, listen: false);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId != null) {
      await provider.fetchForYouRecipesFromCloud(currentUserId); //← ここがポイント
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RecipeProvider>(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchForYouRecipesFromCloud(currentUserId!),
      child:
          provider.forYouRecipes.isEmpty
              ? ListView(
                children: const [
                  SizedBox(
                    height: 400,
                    child: Center(child: Text('あなたへのおすすめがまだありません')),
                  ),
                ],
              )
              : RecipeList(
                recipes: provider.forYouRecipes,
                currentUserId: currentUserId!,
                deleteRecipe: (recipe) => provider.deleteRecipe(recipe),
              ),
    );
  }
}
