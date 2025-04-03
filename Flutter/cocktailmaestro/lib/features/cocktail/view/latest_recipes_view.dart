import 'package:cocktailmaestro/core/models/providers/recipe_provider.dart';
import 'package:cocktailmaestro/widgets/recipe_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LatestRecipesView extends StatefulWidget {
  const LatestRecipesView({super.key});

  @override
  State<LatestRecipesView> createState() => _LatestRecipesViewState();
}

class _LatestRecipesViewState extends State<LatestRecipesView> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLatestRecipes();
  }

  Future<void> _loadLatestRecipes() async {
    final provider = Provider.of<RecipeProvider>(context, listen: false);
    await provider.fetchLatestRecipes();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RecipeProvider>(context);
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: provider.fetchLatestRecipes,
      child:
          provider.latestRecipes.isEmpty
              ? ListView(
                children: const [
                  SizedBox(
                    height: 400,
                    child: Center(child: Text('データがありません')),
                  ),
                ],
              )
              : RecipeList(
                recipes: provider.latestRecipes,
                currentUserId: currentUserId,
                deleteRecipe: (recipe) => provider.deleteRecipe(recipe),
              ),
    );
  }
}
