import 'package:cocktailmaestro/core/models/material_model.dart';
import 'package:cocktailmaestro/core/models/recipe_model.dart';
import 'package:cocktailmaestro/core/services/material_service.dart';
import 'package:cocktailmaestro/core/services/uploadrecipewith_image.dart';
import 'package:cocktailmaestro/features/cocktail/view/detail/recipe_form.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditRecipeScreen extends StatefulWidget {
  final Recipe recipe;

  const EditRecipeScreen({required this.recipe, super.key});

  @override
  // ignore: library_private_types_in_public_api
  _EditRecipeScreenState createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late List<TextEditingController> _stepControllers;
  late List<Map<String, dynamic>> _ingredients = []; // 空リストで初期化

  late List<String> _tags;

  double _alcoholStrength = 0;
  XFile? _pickedImage;

  late Future<List<MaterialModel>> _materialsFuture;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _units = ['なし', 'ml', 'g', '個'];
  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    _titleController = TextEditingController(text: recipe.title);
    _descriptionController = TextEditingController(text: recipe.description);
    _stepControllers =
        recipe.steps.map((s) => TextEditingController(text: s)).toList();
    _alcoholStrength = recipe.alcoholStrength;
    _tags = List<String>.from(recipe.tags);
    // 未来形の持っている材料リスト
    _materialsFuture = MaterialService.fetchOwnedMaterials(
      userId: recipe.userId,
    );

    // ⭐️ 材料情報のセット（materialId -> MaterialModel 変換）
    _materialsFuture.then((materials) {
      setState(() {
        _ingredients =
            recipe.ingredients.map((ingredient) {
              final matchedMaterial = materials.firstWhere(
                (m) => m.id == ingredient.materialId,
                orElse:
                    () => MaterialModel(
                      id: '',
                      name: '',
                      categoryMain: '',
                      categorySub: '',
                      affiliateUrl: "",
                      alcPercent: 0,
                      approved: false,
                      createdAt: Timestamp.now(),
                      registeredBy: '',
                    ), // 見つからない場合
              );

              return {
                "name": TextEditingController(text: ingredient.name),
                "selectedMaterial":
                    matchedMaterial.id.isNotEmpty ? matchedMaterial : null,
                "materialId": ingredient.materialId,
                "amount": TextEditingController(text: ingredient.amount),
                "unit": ingredient.unit,
                "custom": ingredient.materialId.isEmpty,
              };
            }).toList();
      });
    });
  }

  Future<void> _updateRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final recipeRef = _firestore.collection('recipes').doc(widget.recipe.id);

      List<Map<String, dynamic>> ingredients =
          _ingredients
              .map(
                (ingredient) => {
                  'name': ingredient['name'].text.trim(),
                  'amount': ingredient['amount'].text.trim(),
                  'unit': ingredient['unit'],
                  'materialId':
                      ingredient['selectedMaterial'] != null
                          ? ingredient['selectedMaterial'].id
                          : (ingredient['materialId'] ?? ''),
                },
              )
              .toList();

      List<String> steps =
          _stepControllers
              .map((c) => c.text.trim())
              .where((s) => s.isNotEmpty)
              .toList();

      String fileId = widget.recipe.fileId;
      if (_pickedImage != null) {
        final uploadResult = await uploadRecipeWithImage(
          image: _pickedImage!,
          name: _titleController.text.trim(),
          ingredients: ingredients,
        );
        fileId = uploadResult.fileId;
      }
      // ⭐️ デバッグ出力
      if (kDebugMode) {
        print('Updating Recipe with:');
      }

      await recipeRef.update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'fileId': fileId,
        'ingredients': ingredients,
        'steps': steps,
        'tags': _tags,
        'alcoholStrength': _alcoholStrength,
      });

      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('レシピを更新しました')));
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('エラー: $e')));
    } finally {}
  }

  void _addStepField() =>
      setState(() => _stepControllers.add(TextEditingController()));
  void _removeStepField(int index) =>
      setState(() => _stepControllers.removeAt(index));
  void _addIngredientField() => setState(
    () => _ingredients.add({
      "name": TextEditingController(),
      "selectedMaterial": null,
      "amount": TextEditingController(),
      "unit": 'なし',
      "custom": false,
    }),
  );
  void _removeIngredientField(int index) =>
      setState(() => _ingredients.removeAt(index));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('レシピ編集')),
      body: RecipeForm(
        // 各種コントローラーや関数を渡す
        formKey: _formKey,
        units: _units,
        stepControllers: _stepControllers,
        ingredients: _ingredients,
        alcoholStrength: _alcoholStrength,
        tags: _tags,
        onImagePicked: (image) => setState(() => _pickedImage = image),
        materialsFuture: _materialsFuture,
        onAddIngredient: _addIngredientField,
        onRemoveIngredient: _removeIngredientField,
        onAddStep: _addStepField,
        onRemoveStep: _removeStepField,
        onAlcoholChanged: (value) => setState(() => _alcoholStrength = value),
        pickedImage: _pickedImage,
        titleController: _titleController,
        descriptionController: _descriptionController,
        fileId: widget.recipe.fileId,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _updateRecipe,
        child: Icon(Icons.save),
      ),
    );
  }
}
