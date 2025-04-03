import 'package:cocktailmaestro/features/mybar/detail/material_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:cocktailmaestro/core/models/material_model.dart';

// ignore: must_be_immutable
class MaterialListView extends StatelessWidget {
  final List<MaterialModel> materials;
  final Function(MaterialModel)? onTap;

  MaterialListView({super.key, required this.materials, this.onTap});

  // カテゴリーごとのアイコンと色
  final Map<String, Map<String, dynamic>> categoryIconMap = {
    'スピリッツ': {'icon': Icons.local_bar, 'color': Colors.blueAccent},
    'リキュール': {'icon': Icons.liquor, 'color': Colors.deepPurpleAccent},
    'ビール': {'icon': Icons.sports_bar, 'color': Colors.redAccent},
    'ワイン': {'icon': Icons.wine_bar, 'color': Colors.greenAccent},
    'ミキサー': {'icon': Icons.local_drink, 'color': Colors.teal},
    'ビターズ': {'icon': Icons.water_drop, 'color': Colors.orangeAccent},
    '和酒': {'icon': Icons.local_cafe, 'color': Colors.brown}, // 和酒を追加
  };

  // カテゴリーからアイコンと色を取得する関数
  Map<String, dynamic> _getIconAndColor(String categoryMain) {
    return categoryIconMap[categoryMain] ??
        {'icon': Icons.help_outline, 'color': Colors.grey}; // デフォルト
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: materials.length,
      itemBuilder: (context, index) {
        final material = materials[index];
        final iconData = _getIconAndColor(material.categoryMain);

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: iconData['color'],
              child: Icon(iconData['icon'], color: Colors.white),
            ),
            title: Text(
              material.name,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Row(
              children: [
                Text(material.categoryMain, style: TextStyle(fontSize: 12)),
                SizedBox(width: 8),
                Text(material.categorySub, style: TextStyle(fontSize: 12)),
                SizedBox(width: 8),
              ],
            ),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MaterialDetailPage(material: material),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
