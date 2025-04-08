import 'package:cocktailmaestro/core/providers/material_provider.dart';
import 'package:cocktailmaestro/features/login/AuthGate.dart';
import 'package:cocktailmaestro/features/mybar/view/register_ingredients_screen.dart';
import 'package:cocktailmaestro/features/drower/myrecipes_screen.dart';
import 'package:cocktailmaestro/features/search/search_screen.dart';
import 'package:cocktailmaestro/features/drower/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/recipe_provider.dart';
import 'core/providers/user_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => MaterialProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // これを追加するだけ
      title: 'Cocktail Maestro',
      theme: ThemeData(primarySwatch: Colors.teal),
      routes: {
        '/': (context) => const AuthGate(), // ← 認証判定画面
        '/search': (context) => SearchScreen(),
        '/my_recipes': (context) => MyRecipesScreen(),
        '/ingredient-register': (context) => RegisterIngredientScreen(),
        '/settings': (context) => SettingsScreen(),
      },
      initialRoute: '/',
    );
  }
}
