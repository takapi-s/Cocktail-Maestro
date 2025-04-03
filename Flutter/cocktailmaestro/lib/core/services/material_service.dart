import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cocktailmaestro/core/models/material_model.dart';

class MaterialService {
  // ✅ Firestore から ID指定で MaterialModel を作成
  static MaterialModel _fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MaterialModel(
      id: doc.id,
      name: data['name'] ?? '名称不明',
      alcPercent: (data['alcPercent'] ?? 0).toDouble(),
      categoryMain: data['categoryMain'] ?? '',
      categorySub: data['categorySub'] ?? '',
      affiliateUrl: data['affiliateUrl'] ?? '',
      approved: data['approved'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      registeredBy: data['registeredBy'] ?? '',
    );
  }

  // ✅ 外部から呼び出し可能な材料取得メソッド
  static Future<List<MaterialModel>> fetchOwnedMaterials({
    String? userId,
  }) async {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    // 1. ユーザーの持つ材料IDを取得
    final ownedSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('OwnedIngredient')
            .get();

    final ownedIds = ownedSnapshot.docs.map((doc) => doc.id).toList();

    if (ownedIds.isEmpty) return [];

    // 2. 10件ずつ材料情報を取得
    List<DocumentSnapshot> materialDocs = [];
    for (int i = 0; i < ownedIds.length; i += 10) {
      final batchIds = ownedIds.sublist(
        i,
        i + 10 > ownedIds.length ? ownedIds.length : i + 10,
      );

      final snapshot =
          await FirebaseFirestore.instance
              .collection('materials')
              .where(FieldPath.documentId, whereIn: batchIds)
              .get();

      materialDocs.addAll(snapshot.docs);
    }

    // 3. MaterialModel に変換して返す
    return materialDocs.map((doc) => _fromFirestore(doc)).toList();
  }
}
