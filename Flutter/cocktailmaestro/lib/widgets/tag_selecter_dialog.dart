import 'package:cocktailmaestro/core/services/global.dart';
import 'package:flutter/material.dart';

class TagSelectorDialog {
  static Future<List<String>?> show(
    BuildContext context,
    List<String> currentTags,
  ) {
    List<String> tempSelectedTags = List<String>.from(currentTags);
    final prefixToLabel = {
      "taste_": "味",
      "aroma_": "香り",
      "visual_": "見た目",
      "body_": "飲みごたえ",
      "situation_": "シチュエーション",
      "cost_": "コスパ・手軽さ",
      "unique_": "ユニークさ",
      "preference_": "好みの傾向",
    };

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    prefixToLabel.entries.map((entry) {
                      return _buildTagSection(
                        context,
                        entry.value,
                        entry.key,
                        tempSelectedTags,
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

  static Widget _buildTagSection(
    BuildContext context,
    String title,
    String prefix,
    List<String> selectedTags,
  ) {
    final filteredTags =
        allTagOptions.where((tag) => tag.startsWith(prefix)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children:
              filteredTags.map((tag) {
                final displayText = tag.replaceFirst(prefix, '');
                final isSelected = selectedTags.contains(tag);
                return ChoiceChip(
                  label: Text(displayText, style: TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      selectedTags.add(tag);
                    } else {
                      selectedTags.remove(tag);
                    }
                    (context as Element).markNeedsBuild(); // 再描画
                  },
                  selectedColor: Colors.orange.shade200,
                  backgroundColor: Colors.grey.shade200,
                );
              }).toList(),
        ),
        SizedBox(height: 12),
      ],
    );
  }
}
