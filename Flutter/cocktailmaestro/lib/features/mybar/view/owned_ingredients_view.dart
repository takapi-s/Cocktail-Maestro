import 'package:cocktailmaestro/core/services/material_service.dart';
import 'package:cocktailmaestro/widgets/material_listview.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cocktailmaestro/core/models/material_model.dart';

class OwnedIngredientsTab extends StatefulWidget {
  const OwnedIngredientsTab({super.key});

  @override
  _OwnedIngredientsTabState createState() => _OwnedIngredientsTabState();
}

class _OwnedIngredientsTabState extends State<OwnedIngredientsTab> {
  final String? userId = FirebaseAuth.instance.currentUser?.uid;
  Future<List<MaterialModel>>? _materialsFuture;
  List<MaterialModel>? _cachedMaterials; // キャッシュ用変数

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  void _loadMaterials() {
    if (_cachedMaterials == null) {
      // キャッシュがない時だけロードする
      _materialsFuture = MaterialService.fetchOwnedMaterials(
        userId: userId,
      ).then((materials) {
        _cachedMaterials = materials;
        return materials;
      });
    }
  }

  Future<void> _refreshMaterials() async {
    final materials = await MaterialService.fetchOwnedMaterials(userId: userId);
    setState(() {
      _cachedMaterials = materials;
      _materialsFuture = Future.value(materials); // キャッシュを更新
    });
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return Center(child: Text('ログインしてください'));
    }

    return RefreshIndicator(
      onRefresh: _refreshMaterials,
      child: FutureBuilder<List<MaterialModel>>(
        future: _materialsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return ListView(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('材料が登録されていません'),
                  ),
                ),
              ],
            );
          }

          final materials = snapshot.data!;
          return MaterialListView(materials: materials);
        },
      ),
    );
  }
}
