import 'package:cocktailmaestro/features/cocktail/view/foryou_recipe_view.dart';
import 'package:cocktailmaestro/features/cocktail/view/latest_recipes_view.dart';
import 'package:cocktailmaestro/features/cocktail/view/popular_recipes_view.dart';
import 'package:flutter/material.dart';
import '../../widgets/tabbed_screen.dart';

class HomeTabView extends StatelessWidget {
  const HomeTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return TabbedScreen(
      tabs: const [
        Tab(text: 'Latest'),
        Tab(text: 'Popular'),
        Tab(text: 'For You'),
      ],
      views: const [
        LatestRecipesView(),
        PopularRecipesView(),
        ForYouRecipesView(),
      ],
    );
  }
}
