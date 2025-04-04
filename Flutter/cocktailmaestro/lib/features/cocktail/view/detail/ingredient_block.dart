import 'package:flutter/material.dart';

class IngredientBlock extends StatelessWidget {
  IngredientBlock({super.key});

  final List<String> units = ['なし', 'ml', 'g', '個'];
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 材料名ボタン
        ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder:
                  (_) => AlertDialog(
                    title: Text('材料を選択'),
                    content: Text('（ここに検索付き材料一覧が入る予定）'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('閉じる'),
                      ),
                    ],
                  ),
            );
          },
          child: Text('材料名を選択'),
        ),
        SizedBox(height: 8),
        // 量 + 単位
        Row(
          children: [
            // 量
            Expanded(
              flex: 2,
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: '量',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(width: 8),
            // 単位
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: '単位',
                  border: OutlineInputBorder(),
                ),
                items:
                    units
                        .map(
                          (unit) =>
                              DropdownMenuItem(value: unit, child: Text(unit)),
                        )
                        .toList(),
                onChanged: (_) {}, // 今は何もしない
              ),
            ),
          ],
        ),
      ],
    );
  }
}
