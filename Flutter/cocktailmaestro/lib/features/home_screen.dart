import 'package:cocktailmaestro/features/cocktail/view/detail/recipe_form_screen.dart';
import 'package:cocktailmaestro/features/mybar/ingredient_tab.dart';
import 'package:cocktailmaestro/features/drower/app_drawer.dart';
import 'package:cocktailmaestro/features/cocktail/home_tab.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cocktailmaestro/core/providers/user_provider.dart';
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
  void initState() {
    super.initState();
  }

  Widget _buildPolicyDialog(UserProvider userProvider) {
    return AlertDialog(
      title: const Text("ポリシー変更のお知らせ"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("プライバシーポリシーまたは利用規約が更新されました。\n内容をご確認の上、再度同意してください。"),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _linkText(
                "利用規約",
                "https://takapi-s.github.io/cocktailmaestro_terms_and_privacy/terms.html",
              ),
              const Text(' / '),
              _linkText(
                "プライバシーポリシー",
                "https://takapi-s.github.io/cocktailmaestro_terms_and_privacy/privacy.html",
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await userProvider.agreeLatestPolicy();
            Navigator.of(context).pop();
          },
          child: const Text("同意する"),
        ),
      ],
    );
  }

  Widget _linkText(String text, String urlStr) {
    return GestureDetector(
      onTap: () async {
        final url = Uri.parse(urlStr);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        if (userProvider.shouldShowPolicyDialog) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ModalRoute.of(context)?.isCurrent ?? false) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => _buildPolicyDialog(userProvider),
              );
              userProvider.clearPolicyDialogFlag(); // ダイアログの二重表示防止！
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(['カクテル', '検索', '材料'][_selectedIndex]),
            centerTitle: true,
          ),
          drawer: AppDrawer(),
          body: IndexedStack(index: _selectedIndex, children: _screens),
          floatingActionButton:
              _selectedIndex == 0
                  ? FloatingActionButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RecipeFormScreen(),
                        ),
                      );
                    },
                    backgroundColor: Theme.of(context).primaryColor,
                    child: const Icon(Icons.add, color: Colors.white),
                  )
                  : null,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.wine_bar),
                label: 'カクテル',
              ),
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
      },
    );
  }
}
