import 'package:cloud_firestore/cloud_firestore.dart';

class MaterialModel {
  final String id;
  final String name;
  final String categoryMain;
  final String categorySub;
  final double alcPercent;
  final String affiliateUrl;
  final bool approved;
  final Timestamp createdAt;
  final String registeredBy;

  MaterialModel({
    required this.id,
    required this.name,
    required this.categoryMain,
    required this.categorySub,
    required this.alcPercent,
    required this.affiliateUrl,
    required this.approved,
    required this.createdAt,
    required this.registeredBy,
  });

  // Firestoreから取得したデータを変換
  factory MaterialModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MaterialModel(
      id: doc.id,
      name: data['name'] ?? '',
      categoryMain: data['categoryMain'] ?? '',
      categorySub: data['categorySub'] ?? '',
      alcPercent: (data['alcPercent'] ?? 0).toDouble(),
      affiliateUrl: data['affiliateUrl'] ?? '',
      approved: data['approved'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      registeredBy: data['registeredBy'] ?? '',
    );
  }

  // Firestoreへ登録する際のMap形式
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'categoryMain': categoryMain,
      'categorySub': categorySub,
      'alcPercent': alcPercent,
      'affiliateUrl': affiliateUrl,
      'approved': approved,
      'createdAt': createdAt,
      'registeredBy': registeredBy,
    };
  }
}
