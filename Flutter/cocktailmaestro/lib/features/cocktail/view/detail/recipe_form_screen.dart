import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocktailmaestro/core/models/providers/recipe_provider.dart';
import 'package:cocktailmaestro/core/models/recipe_ingredient_model.dart';
import 'package:cocktailmaestro/core/services/global.dart';
import 'package:cocktailmaestro/widgets/image_picker_cropper.dart';
import 'package:cocktailmaestro/widgets/show_material_selecter_modal.dart';
import 'package:cocktailmaestro/widgets/tag_selecter_dialog.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cocktailmaestro/core/models/recipe_model.dart';
import 'package:provider/provider.dart';

class RecipeFormScreen extends StatefulWidget {
  final Recipe? recipe;

  const RecipeFormScreen({super.key, this.recipe});

  @override
  State<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends State<RecipeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late List<TextEditingController> _nameControllers = [];

  List<Map<String, String>> _ingredients = [];
  List<String> _steps = [];
  List<String> _selectedTags = [];
  late final List<String> _glassOptions;
  File? _imageFile;
  String _selectedGlass = '';
  double _alcoholStrength = 0.0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    try {
      final r = widget.recipe;
      _glassOptions = glassCapacitiesRange.keys.toList();

      _titleController = TextEditingController(text: r?.title ?? '');
      _descriptionController = TextEditingController(
        text: r?.description ?? '',
      );

      _steps = r?.steps ?? [];
      _selectedTags = r?.tags ?? [];
      print('r?.glass = ${r?.glass}');
      print('_glassOptions = $_glassOptions');
      _selectedGlass = r!.glass;

      _ingredients =
          r.ingredients.map((e) {
            return {
              'name': e.name,
              'amount': e.amount,
              'unit': e.unit,
              'materialId': e.materialId,
            };
          }).toList();

      _nameControllers =
          _ingredients
              .map((e) => TextEditingController(text: e['name']))
              .toList();

      // アルコール度数を計算
      _recalculateAlcoholStrength();
    } catch (e, stack) {
      debugPrint('initState エラー: $e');
      debugPrint('$stack');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('初期化中にエラーが発生しました')));
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _recalculateAlcoholStrength() async {
    final result = await estimateAlcoholStrength(
      ingredients: _ingredients,
      selectedGlass: _selectedGlass,
    );
    setState(() {
      _alcoholStrength = result;
      print('アルコール度数: $_alcoholStrength%');
    });
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add({'name': '', 'amount': '', 'unit': ''});
      _nameControllers.add(TextEditingController());
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
      _nameControllers.removeAt(index);
    });
  }

  void _addStep() {
    setState(() {
      _steps.add('');
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
    });
  }

  Future<double?> getAlcoholPercent(String materialId) async {
    try {
      if (materialId.isEmpty) return null;
      final doc =
          await FirebaseFirestore.instance
              .collection('materials')
              .doc(materialId)
              .get();
      if (!doc.exists) return null;
      final data = doc.data();
      return data?['alcPercent']?.toDouble();
    } catch (e) {
      print('getAlcoholPercent error: $e');
      return null;
    }
  }

  Future<double> estimateAlcoholStrength({
    required List<Map<String, String>> ingredients,
    required String? selectedGlass,
  }) async {
    double totalVolume = 0;
    double totalAlcoholVolume = 0;

    const liquidUnits = ['ml', 'ダッシュ', 'バースプーン', '小さじ', '滴'];
    const unitToMl = {
      'ml': 1.0,
      'ダッシュ': 0.92,
      'バースプーン': 5.0,
      '小さじ': 5.0,
      '滴': 0.05,
    };

    // 1. 通常材料の集計
    List<Map<String, String>> topWiths = [];
    for (final ing in ingredients) {
      final unit = ing['unit'] ?? '';
      final amountStr = ing['amount'] ?? '';
      final materialId = ing['materialId'] ?? '';
      final amount = double.tryParse(amountStr);
      if (amount == null) continue;

      if (unit == '適量でみたす') {
        topWiths.add(ing); // 後で処理
        continue;
      }

      if (!liquidUnits.contains(unit)) continue;

      final ml = amount * (unitToMl[unit] ?? 0.0);
      final alcPercent = await getAlcoholPercent(materialId) ?? 0.0;

      totalVolume += ml;
      totalAlcoholVolume += ml * (alcPercent / 100);
    }

    // 2. グラス最大容量から Top with の体積を算出し加算
    if (topWiths.isNotEmpty &&
        selectedGlass != null &&
        glassCapacitiesRange.containsKey(selectedGlass)) {
      final maxCapacity = glassCapacitiesRange[selectedGlass]?['最大'] ?? 0;
      final remainingVolume = (maxCapacity - totalVolume).clamp(0, maxCapacity);

      final volumePerTopWith =
          remainingVolume / topWiths.length; // 均等割り（複数Top with対応）

      for (final ing in topWiths) {
        final materialId = ing['materialId'] ?? '';
        final alcPercent = await getAlcoholPercent(materialId) ?? 0.0;

        totalVolume += volumePerTopWith;
        totalAlcoholVolume += volumePerTopWith * (alcPercent / 100);
      }
    }
    print('--- アルコール計算デバッグ ---');
    print('材料: $ingredients');
    print('グラス: $selectedGlass');
    print('現在の totalVolume: $totalVolume');
    print('現在の totalAlcoholVolume: $totalAlcoholVolume');

    if (totalVolume == 0) return 0;
    return (totalAlcoholVolume / totalVolume) * 100;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onSubmit() async {
    if (_isSubmitting) return; // 二重送信防止
    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null && widget.recipe?.fileId == null) {
      _showError('画像を選択してください');
      return;
    }

    if (_selectedGlass == "" || _selectedGlass.isEmpty) {
      _showError('グラスを選択してください');
      return;
    }

    if (_ingredients.isEmpty) {
      _showError('少なくとも1つ材料を追加してください');
      return;
    }

    for (int i = 0; i < _ingredients.length; i++) {
      final ing = _ingredients[i];
      final name = ing['name']?.trim() ?? '';
      final unit = ing['unit'] ?? '';
      final amount = ing['amount']?.trim() ?? '';

      if (name.isEmpty) {
        _showError('材料 ${i + 1} の名前が入力されていません');
        return;
      }

      final requiresAmount = unit != '適量' && unit != '適量で満たす';
      if (requiresAmount && amount.isEmpty) {
        _showError('材料 ${i + 1} の量を入力してください');
        return;
      }
    }

    if (_steps.isEmpty) {
      _showError('手順を1つ以上入力してください');
      return;
    }

    for (int i = 0; i < _steps.length; i++) {
      if (_steps[i].trim().isEmpty) {
        _showError('手順 ${i + 1} が空です');
        return;
      }
    }

    if (_selectedTags.isEmpty) {
      _showError('少なくとも1つタグを選択してください');
      return;
    }

    // ---- 追加バリデーション終了 ----
    setState(() {
      _isSubmitting = true;
    });

    final recipeProvider = context.read<RecipeProvider>();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final tags = _selectedTags;
    final steps = _steps;
    final image = _imageFile != null ? XFile(_imageFile!.path) : null;

    final ingredients =
        _ingredients.map((e) {
          return RecipeIngredient(
            name: e['name'] ?? '',
            amount: e['amount'] ?? '',
            unit: e['unit'] ?? '',
            materialId: e['materialId'] ?? '',
          );
        }).toList();

    await _recalculateAlcoholStrength();

    try {
      if (widget.recipe != null) {
        await recipeProvider.updateRecipe(
          originalRecipe: widget.recipe!,
          title: title,
          description: description,
          ingredients: ingredients,
          steps: steps,
          tags: tags,
          alcoholStrength: _alcoholStrength,
          image: image,
          glass: _selectedGlass,
        );
      } else {
        await recipeProvider.addRecipe(
          title: title,
          description: description,
          ingredients: ingredients,
          steps: steps,
          tags: tags,
          alcoholStrength: _alcoholStrength,
          image: image,
          glass: _selectedGlass,
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存中にエラーが発生しました')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.recipe != null;
    final fileId = widget.recipe?.fileId;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'レシピ編集' : 'レシピ追加'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isSubmitting ? null : _onSubmit, // ロック中は無効化
          ),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ImagePickerCropper(
                  initialImage: _imageFile,
                  initialFileId: fileId,
                  onImageSelected: (file) {
                    setState(() {
                      _imageFile = file;
                    });
                  },
                ),

                const SizedBox(height: 24),
                // タイトル
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'タイトル'),
                  validator:
                      (v) => v == null || v.isEmpty ? 'タイトルを入力してください' : null,
                ),
                const SizedBox(height: 16),

                // 説明
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: '説明'),
                  maxLines: 3,

                  validator:
                      (v) =>
                          v == null || v.trim().isEmpty ? '説明を入力してください' : null,
                ),
                const SizedBox(height: 24),

                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGlass,
                  items:
                      _glassOptions.map((glass) {
                        return DropdownMenuItem(
                          value: glass,
                          child: Text(glass),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGlass = value!;
                    });
                  },
                  decoration: const InputDecoration(labelText: '使用するグラス'),
                ),

                const SizedBox(height: 16),
                Text(
                  '推定アルコール度数: ${_alcoholStrength.toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                const Text('材料', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                Column(
                  children: [
                    for (int i = 0; i < _ingredients.length; i++)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              // 材料名入力 + 選択ボタン
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _nameControllers[i],
                                      decoration: const InputDecoration(
                                        labelText: '材料名',
                                        hintText: '自由入力または選択',
                                      ),
                                      onChanged: (value) {
                                        _ingredients[i]['name'] = value;
                                        _ingredients[i]['materialId'] =
                                            ''; // 手入力なら materialId をクリア
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.search),
                                    tooltip: 'MyBar から選択',
                                    onPressed: () async {
                                      final selected =
                                          await showMaterialSelectorModal(
                                            context,
                                          );
                                      if (selected != null) {
                                        setState(() {
                                          _nameControllers[i].text =
                                              selected.name;
                                          _ingredients[i]['name'] =
                                              selected.name;
                                          _ingredients[i]['materialId'] =
                                              selected.id;
                                        });
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _removeIngredient(i),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),
                              // 容量・単位の行
                              Row(
                                children: [
                                  if (_ingredients[i]['unit'] != '適量' &&
                                      _ingredients[i]['unit'] != '適量で満たす')
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: _ingredients[i]['amount'],
                                        onChanged: (v) async {
                                          _ingredients[i]['amount'] = v;
                                          if (v == '適量' || v == '適量でみたす') {
                                            _ingredients[i]['amount'] = '';
                                          }
                                          await _recalculateAlcoholStrength(); // ← 再計算
                                        },
                                        decoration: const InputDecoration(
                                          labelText: '量（例: 45）',
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  if (_ingredients[i]['unit'] != '適量' &&
                                      _ingredients[i]['unit'] != '適量で満たす')
                                    const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value:
                                          unitOptions.contains(
                                                _ingredients[i]['unit'],
                                              )
                                              ? _ingredients[i]['unit']
                                              : null,
                                      onChanged: (value) async {
                                        setState(() {
                                          _ingredients[i]['unit'] = value ?? '';
                                          if (value == '適量' ||
                                              value == '適量でみたす') {
                                            _ingredients[i]['amount'] = '';
                                          }
                                        });
                                        await _recalculateAlcoholStrength(); // ← 再計算
                                      },
                                      items:
                                          unitOptions.map((unit) {
                                            return DropdownMenuItem(
                                              value: unit,
                                              child: Text(unit),
                                            );
                                          }).toList(),
                                      decoration: const InputDecoration(
                                        labelText: '単位（例: ml）',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                    TextButton(
                      onPressed: _addIngredient,
                      child: const Text('＋材料を追加'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 手順
                const Text('手順', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (int i = 0; i < _steps.length; i++)
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _steps[i],
                          onChanged: (v) => _steps[i] = v,
                          decoration: InputDecoration(hintText: '手順 ${i + 1}'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeStep(i),
                      ),
                    ],
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _addStep,
                    child: const Text('＋手順を追加'),
                  ),
                ),
                const SizedBox(height: 16),
                // タグ選択
                const Text('タグ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      _selectedTags.map((tag) {
                        return Chip(
                          label: Text(tag),
                          onDeleted: () {
                            setState(() => _selectedTags.remove(tag));
                          },
                        );
                      }).toList(),
                ),

                TextButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text("タグを編集"),
                  onPressed: () async {
                    final result = await TagSelectorDialog.show(
                      context,
                      _selectedTags,
                    );
                    if (result != null) {
                      setState(() {
                        _selectedTags = result;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
