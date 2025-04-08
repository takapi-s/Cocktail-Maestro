import 'package:cocktailmaestro/core/services/global.dart';
import 'package:flutter/material.dart';

class TagSelectorDialog {
  static Future<List<String>?> show(
    BuildContext context,
    List<String> currentTags,
  ) {
    List<String> tempSelectedTags = List<String>.from(currentTags);
    final scrollController = ScrollController();

    return showDialog<List<String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("タグを選択"),
          content: Scrollbar(
            controller: scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: scrollController,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    allTagOptions.map((tag) {
                      final isSelected = tempSelectedTags.contains(tag);
                      return ChoiceChip(
                        label: Text(tag, style: TextStyle(fontSize: 12)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            tempSelectedTags.add(tag);
                          } else {
                            tempSelectedTags.remove(tag);
                          }
                          (context as Element).markNeedsBuild(); // 再描画
                        },
                        selectedColor: Colors.orange.shade200,
                        backgroundColor: Colors.grey.shade200,
                      );
                    }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text("キャンセル"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, tempSelectedTags),
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }
}
