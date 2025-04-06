import 'package:cocktailmaestro/features/cocktail/view/detail/recipe_form_screen.dart';
import 'package:cocktailmaestro/features/mybar/ingredient_tab.dart';
import 'package:cocktailmaestro/features/drower/app_drawer.dart';
import 'package:cocktailmaestro/features/cocktail/home_tab.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    HomeTabView(),
    SearchScreen(),
    IngredientScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: Icon(Icons.menu),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
        ),
        title: Text(['カクテル', '検索', '材料'][_selectedIndex]),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () async {
              final url = Uri.parse("https://discord.gg/jWsxVJWtxX");
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                print("URLを開けませんでした");
              }
            },
            icon: Icon(Icons.discord),
          ),
        ],
      ),
      drawer: AppDrawer(),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      floatingActionButton:
          _selectedIndex == 0
              ? FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecipeFormScreen()),
                  );
                },
                backgroundColor: Theme.of(context).primaryColor,
                child: const Icon(Icons.add, color: Colors.white),
              )
              : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.wine_bar), label: 'カクテル'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '検索'),
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: '材料'),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
