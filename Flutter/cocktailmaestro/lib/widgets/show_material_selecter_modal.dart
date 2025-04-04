import 'package:cocktailmaestro/core/models/material_model.dart';
import 'package:cocktailmaestro/core/models/providers/material_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<MaterialModel?> showMaterialSelectorModal(BuildContext context) async {
  final materialProvider = Provider.of<MaterialProvider>(
    context,
    listen: false,
  );
  final materials = await materialProvider.getMyMaterials(); // MyBarの材料一覧を取得

  return showModalBottomSheet<MaterialModel>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              '材料を選択',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: materials.length,
              itemBuilder: (context, index) {
                final material = materials[index];
                return ListTile(
                  title: Text(material.name),
                  onTap: () => Navigator.pop(context, material),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}
