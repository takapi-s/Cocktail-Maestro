import 'package:flutter/material.dart';
import 'view/owned_ingredients_view.dart';
import 'view/search_ingredients_view.dart';
import '../../widgets/tabbed_screen.dart';

class IngredientScreen extends StatelessWidget {
  const IngredientScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TabbedScreen(
      tabs: const [Tab(text: 'Stock'), Tab(text: 'Search')],
      views: const [OwnedIngredientsTab(), SearchIngredientsTab()],
      fabBuilder: (index) {
        if (index == 1) {
          return FloatingActionButton(
            onPressed: () {
              Navigator.pushNamed(context, '/ingredient-register');
            },
            tooltip: '新しい材料を登録',
            child: const Icon(Icons.add),
          );
        }
        return null;
      },
    );
  }
}
