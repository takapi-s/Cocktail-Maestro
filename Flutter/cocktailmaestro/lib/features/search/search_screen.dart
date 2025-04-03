import 'package:cocktailmaestro/core/models/providers/recipe_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/recipe_list.dart'; // 既存のレシピ一覧ウィジェットを活用
// import 'package:firebase_auth/firebase_auth.dart'; // 🔑 必要ならユーザーID取得用

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RecipeProvider>(context);
    final currentUserId =
        FirebaseAuth.instance.currentUser!.uid; // 🔑 実際のユーザーID取得 (Firebase使用時)

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'カクテル名または材料名で検索',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    provider.searchRecipes(''); // 検索解除
                  },
                ),
              ),
              onSubmitted: (value) {
                provider.searchRecipes(value); // 🔑 入力確定時に検索
              },
            ),
          ),
          Expanded(
            child:
                provider.searchResults.isEmpty
                    ? Center(child: Text('該当するレシピが見つかりません'))
                    : RecipeList(
                      recipes: provider.searchResults,
                      currentUserId: currentUserId, // ✅ ユーザーIDを渡す
                      deleteRecipe:
                          (recipe) =>
                              provider.deleteRecipe(recipe), // ✅ 削除関数を渡す
                    ),
          ),
        ],
      ),
    );
  }
}
