import 'package:cocktailmaestro/core/providers/recipe_provider.dart';
import 'package:cocktailmaestro/widgets/recipe_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PopularRecipesView extends StatefulWidget {
  const PopularRecipesView({super.key});

  @override
  State<PopularRecipesView> createState() => _PopularRecipesViewState();
}

class _PopularRecipesViewState extends State<PopularRecipesView>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPopularRecipes();
  }

  Future<void> _loadPopularRecipes() async {
    final provider = Provider.of<RecipeProvider>(context, listen: false);
    await provider.fetchPopularRecipes();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ← super.build を呼ぶ必要があります
    final provider = Provider.of<RecipeProvider>(context);
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: provider.fetchPopularRecipes,
      child:
          provider.popularRecipes.isEmpty
              ? ListView(
                children: const [
                  SizedBox(
                    height: 400,
                    child: Center(child: Text('データがありません')),
                  ),
                ],
              )
              : RecipeList(
                recipes: provider.popularRecipes,
                currentUserId: currentUserId,
                deleteRecipe: (recipe) => provider.deleteRecipe(recipe),
              ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
