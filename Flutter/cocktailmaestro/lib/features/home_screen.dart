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
        title: Text(
          _selectedIndex == 0
              ? 'カクテル'
              : _selectedIndex == 1
              ? '検索'
              : '材料',
        ),
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
      body: _buildBody(),
      floatingActionButton:
          _selectedIndex == 0
              ? FloatingActionButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/addRecipe');
                },
                backgroundColor: Theme.of(context).primaryColor,
                child: Icon(Icons.add, color: Colors.white),
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

  Widget _buildBody() {
    if (_selectedIndex == 0) {
      return HomeTabView();
    } else if (_selectedIndex == 1) {
      return SearchScreen();
    } else if (_selectedIndex == 2) {
      return IngredientScreen();
    } else {
      return Container();
    }
  }
}
