import 'package:cocktailmaestro/core/models/material_model.dart';
import 'package:cocktailmaestro/core/services/material_service.dart';
import 'package:cocktailmaestro/core/services/uploadrecipewith_image.dart';
import 'package:cocktailmaestro/features/cocktail/view/detail/recipe_form.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AddRecipeScreenState createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  XFile? _pickedImage;

  final List<TextEditingController> _stepControllers = [
    TextEditingController(),
  ];
  final List<Map<String, dynamic>> _ingredients = [
    {
      "name": TextEditingController(), // 自由記述用
      "selectedMaterial": null, // 選択されたMaterialModel用
      "materialId": null, // ⭐ 追加：選んだ場合のMaterial ID
      "amount": TextEditingController(),
      "unit": 'なし',
      "custom": false, // trueなら自由記述
    },
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _units = ['なし', 'ml', 'g', '個'];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // 味覚要素（チェックボックス化）
  final Map<String, bool> _tasteElements = {
    '甘味': false,
    '酸味': false,
    '苦味': false,
    '塩味': false,
    '旨味': false,
  };

  // 香りの種類（チェックボックス化）
  final Map<String, bool> _aromaTypes = {
    'フルーティ': false,
    'フローラル': false,
    'ハーバル': false,
    'スパイシー': false,
    'ウッディ': false,
    'スモーキー': false,
  };

  double _alcoholStrength = 0; // 0% から 100% までを想定

  // 画像選択
  Future<void> _addRecipe() async {
    FocusScope.of(context).unfocus(); // キーボードを閉じる
    if (!_formKey.currentState!.validate()) return;

    if (_pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('画像を選択してください'),
          duration: Duration(seconds: 2), // 明示的に2秒間表示
        ),
      );
      return; // 処理を中断
    }

    // ローディングインジケーターを表示
    showDialog(
      context: context,
      barrierDismissible: false, // インジケーターが表示されている間は閉じられない
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        Navigator.of(context).pop(); // ローディングインジケーターを閉じる
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ログインが必要です')));
        return;
      }

      List<Map<String, dynamic>> ingredients =
          _ingredients
              .where((ingredient) => ingredient['name'].text.trim().isNotEmpty)
              .map(
                (ingredient) => {
                  'name': ingredient['name'].text.trim(),
                  'amount': ingredient['amount'].text.trim(),
                  'unit': ingredient['unit'],
                  'materialId': ingredient['materialId'] ?? '',
                },
              )
              .toList();

      String fileId = '';
      String recipeId = '';

      if (_pickedImage != null) {
        final uploadResult = await uploadRecipeWithImage(
          image: _pickedImage!,
          name: _titleController.text.trim(),
          ingredients: ingredients,
        );
        fileId = uploadResult.fileId;
        recipeId = uploadResult.recipeId;
      }

      List<String> steps =
          _stepControllers
              .map((controller) => controller.text.trim())
              .where((text) => text.isNotEmpty)
              .toList();

      // Firestore への保存
      await _firestore.collection('recipes').doc(recipeId).set({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'fileId': fileId,
        'userId': user.uid,
        'ingredients': ingredients,
        'steps': steps,
        'ratingAverage': 0.0,
        'createdAt': Timestamp.now(),
        'tasteElements': _tasteElements,
        'aromaTypes': _aromaTypes,
        'alcoholStrength': _alcoholStrength,
      });

      if (mounted) {
        Navigator.of(context).pop(); // ローディングインジケーターを閉じる
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('レシピが追加されました！')));
        Navigator.pop(context); // 画面を戻す
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      Navigator.of(context).pop(); // ローディングインジケーターを閉じる
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('エラー: $e')));
    }
  }

  // --- 材料追加 ---
  void _addIngredientField() {
    setState(() {
      _ingredients.add({
        "name": TextEditingController(),
        "selectedMaterial": null,
        "amount": TextEditingController(),
        "unit": 'なし',
        "custom": false, // 初期状態は選択式
      });
    });
  }

  // 材料削除
  void _removeIngredientField(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  void _addStepField() =>
      setState(() => _stepControllers.add(TextEditingController()));
  void _removeStepField(int index) =>
      setState(() => _stepControllers.removeAt(index));

  late Future<List<MaterialModel>> _materialsFuture;

  @override
  void initState() {
    super.initState();
    _materialsFuture = MaterialService.fetchOwnedMaterials(
      userId: FirebaseAuth.instance.currentUser?.uid,
    ); // ✅ ここを変更
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('レシピ追加')),
      body: RecipeForm(
        formKey: _formKey,
        units: _units,
        onAddIngredient: _addIngredientField,
        onRemoveIngredient: _removeIngredientField,
        onAddStep: _addStepField,
        onRemoveStep: _removeStepField,
        onAlcoholChanged: (value) => setState(() => _alcoholStrength = value),
        onImagePicked: (image) => setState(() => _pickedImage = image),
        materialsFuture: _materialsFuture,
        stepControllers: _stepControllers,
        ingredients: _ingredients,
        tags: [], // タグはまだ実装していないので空のリスト
        alcoholStrength: _alcoholStrength,
        pickedImage: _pickedImage,
        titleController: _titleController,
        descriptionController: _descriptionController,
        fileId: "",
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRecipe,
        child: Icon(Icons.save),
      ),
    );
  }
}
