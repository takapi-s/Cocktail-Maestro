import 'package:cocktailmaestro/core/providers/material_provider.dart';
import 'package:cocktailmaestro/widgets/material_listview.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cocktailmaestro/core/models/material_model.dart';

class OwnedIngredientsTab extends StatefulWidget {
  const OwnedIngredientsTab({super.key});

  @override
  _OwnedIngredientsTabState createState() => _OwnedIngredientsTabState();
}

class _OwnedIngredientsTabState extends State<OwnedIngredientsTab>
    with AutomaticKeepAliveClientMixin {
  final String? userId = FirebaseAuth.instance.currentUser?.uid;
  late Future<List<MaterialModel>> _materialsFuture;

  @override
  void initState() {
    super.initState();
    _materialsFuture = MaterialProvider().getMyMaterials().then((materials) {
      return materials;
    });
  }

  Future<void> _refreshMaterials() async {
    final materials = await MaterialProvider().getMyMaterials();
    setState(() {
      _materialsFuture = Future.value(materials);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ← これ重要！
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
              children: const [
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
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

  @override
  bool get wantKeepAlive => true;
}
