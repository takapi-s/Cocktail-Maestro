import 'package:cocktailmaestro/widgets/image_cropper_widget.dart';
import 'package:cocktailmaestro/widgets/tag_display.dart';
import 'package:cocktailmaestro/widgets/tag_selecter_dialog.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cocktailmaestro/core/models/material_model.dart';

class RecipeForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final List<TextEditingController> stepControllers;
  final List<Map<String, dynamic>> ingredients;
  final double alcoholStrength;
  final List<String> tags;
  final XFile? pickedImage;
  final Function(XFile?) onImagePicked;
  final Future<List<MaterialModel>> materialsFuture;
  final List<String> units;
  final Function() onAddIngredient;
  final Function(int) onRemoveIngredient;
  final Function() onAddStep;
  final Function(int) onRemoveStep;
  final Function(double) onAlcoholChanged;
  final String fileId; // ← 追加

  const RecipeForm({
    super.key,
    required this.formKey,
    required this.titleController,
    required this.descriptionController,
    required this.stepControllers,
    required this.ingredients,
    required this.alcoholStrength,
    required this.tags,
    required this.pickedImage,
    required this.onImagePicked,
    required this.materialsFuture,
    required this.units,
    required this.onAddIngredient,
    required this.onRemoveIngredient,
    required this.onAddStep,
    required this.onRemoveStep,
    required this.onAlcoholChanged,
    required this.fileId, // ← 追加
  });

  @override
  State<RecipeForm> createState() => _RecipeFormState();
}

class _RecipeFormState extends State<RecipeForm> {
  void _updateEstimatedAlcohol() {
    double totalAlcohol = 0;
    double totalVolume = 0;

    for (var ingredient in widget.ingredients) {
      final amountText = ingredient['amount']?.text ?? '';
      final amount = double.tryParse(amountText) ?? 0.0;
      final unit = ingredient['unit'];

      if (unit != 'ml') continue;

      double alcPercent = 0;

      if (!ingredient['custom'] && ingredient['selectedMaterial'] != null) {
        alcPercent = ingredient['selectedMaterial']?.alcPercent ?? 0;
      }

      totalAlcohol += amount * (alcPercent / 100.0);
      totalVolume += amount;
    }

    setState(() {
      widget.onAlcoholChanged(totalAlcohol / totalVolume * 100);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImageCropperWidget(
                pickedImage: widget.pickedImage,
                onImagePicked: widget.onImagePicked,
                fileId: widget.fileId,
              ),
              TextFormField(
                controller: widget.titleController,
                decoration: InputDecoration(labelText: 'タイトル'),
              ),
              TextFormField(
                controller: widget.descriptionController,
                decoration: InputDecoration(labelText: '説明'),
              ),
              RichText(
                text: TextSpan(
                  text: '推定アルコール度数: ',
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(
                      text: '${widget.alcoholStrength.toStringAsFixed(1)} %',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange, // 強調色
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),

              FutureBuilder<List<MaterialModel>>(
                future: widget.materialsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  final materials = snapshot.data!;
                  return Column(
                    children:
                        widget.ingredients.asMap().entries.map((entry) {
                          final index = entry.key;
                          final ingredient = entry.value;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ★ 材料名 + 切替 + 削除ボタン
                                Row(
                                  children: [
                                    // 材料名（自由記述 or 選択）
                                    Expanded(
                                      child:
                                          ingredient['custom']
                                              ? TextFormField(
                                                controller: ingredient['name'],
                                                decoration: InputDecoration(
                                                  hintText: '材料名（自由記述）',
                                                ),
                                              )
                                              : DropdownButtonFormField<
                                                MaterialModel
                                              >(
                                                isExpanded: true, // ← これを追加
                                                value:
                                                    ingredient['selectedMaterial'],
                                                items:
                                                    materials
                                                        .map(
                                                          (
                                                            material,
                                                          ) => DropdownMenuItem(
                                                            value: material,
                                                            child: Text(
                                                              material.name,
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                onChanged: (value) {
                                                  setState(() {
                                                    ingredient['selectedMaterial'] =
                                                        value;
                                                    ingredient['name'].text =
                                                        value?.name ?? '';
                                                    ingredient["materialId"] =
                                                        value?.id ?? '';
                                                  });
                                                },
                                                decoration: InputDecoration(
                                                  hintText: '材料を選択',
                                                ),
                                              ),
                                    ),
                                    SizedBox(width: 8),
                                    // 切替ボタン
                                    IconButton(
                                      icon: Icon(
                                        ingredient['custom']
                                            ? Icons.arrow_drop_down_circle
                                            : Icons.edit,
                                        color:
                                            ingredient['custom']
                                                ? Colors.blue
                                                : Colors.orange,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          ingredient['custom'] =
                                              !ingredient['custom'];
                                          ingredient['name'].clear();
                                          ingredient['selectedMaterial'] = null;
                                        });
                                      },
                                      tooltip:
                                          ingredient['custom']
                                              ? '材料選択に切り替え'
                                              : '自由記述に切り替え',
                                    ),
                                    // 削除ボタン
                                  ],
                                ),

                                SizedBox(height: 8),

                                // ★ 分量と単位
                                Row(
                                  children: [
                                    // 量
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: ingredient['amount'],
                                        decoration: InputDecoration(
                                          hintText: '量',
                                        ),
                                        onChanged: (value) {
                                          _updateEstimatedAlcohol();
                                        },
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    // 単位
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String>(
                                        value: ingredient['unit'],
                                        items:
                                            widget.units
                                                .map(
                                                  (unit) => DropdownMenuItem(
                                                    value: unit,
                                                    child: Text(unit),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            ingredient['unit'] = value!;
                                          });
                                        },
                                        decoration: InputDecoration(
                                          hintText: '単位',
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.remove_circle,
                                        color: Colors.red,
                                      ),
                                      onPressed:
                                          () =>
                                              widget.onRemoveIngredient(index),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  );
                },
              ),

              TextButton(
                onPressed: widget.onAddIngredient,
                child: Text('材料を追加'),
              ),

              // 手順セクション
              ...widget.stepControllers.asMap().entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: e.value,
                          decoration: InputDecoration(hintText: '手順'),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => widget.onRemoveStep(e.key),
                      ),
                    ],
                  ),
                );
              }),
              TextButton(onPressed: widget.onAddStep, child: Text('手順を追加')),
              // アルコール度数表示の直後など、任意の位置に追加
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('タグ', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    TagDisplay(tags: widget.tags),
                    SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        final updatedTags = await TagSelectorDialog.show(
                          context,
                          widget.tags,
                        );
                        if (updatedTags != null) {
                          setState(() {
                            widget.tags
                              ..clear()
                              ..addAll(updatedTags);
                          });
                        }
                      },
                      icon: Icon(Icons.edit),
                      label: Text("タグを編集"),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 100), // ← 🔧 追加：保存ボタンとの重なり防止
            ],
          ),
        ),

        // ★ スクロール対応
      ),
    );
  }
}
