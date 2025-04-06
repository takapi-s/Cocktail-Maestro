import 'package:cloud_firestore/cloud_firestore.dart';
import 'recipe_ingredient_model.dart';

class Recipe {
  final String id;
  String title;
  String description;
  final String fileId;
  final String userId;
  final List<RecipeIngredient> ingredients;
  List<String> steps;
  final double ratingAverage;
  final int ratingCount; // 追加する評価数
  final DateTime createdAt;
  final List<String> tags;
  final String glass; // グラスの種類
  final double alcoholStrength; // アルコール度数

  Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.fileId,
    required this.userId,
    required this.ingredients,
    required this.steps,
    required this.ratingAverage,
    required this.ratingCount,

    required this.createdAt,
    this.tags = const [],
    this.glass = '', // グラスの種類は空文字で初期化
    required this.alcoholStrength,
  });

  factory Recipe.fromJson(Map<String, dynamic> json, String id) {
    return Recipe(
      id: id,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      fileId: json['fileId'] ?? '',
      userId: json['userId'] ?? '',
      ingredients:
          (json['ingredients'] as List<dynamic>?)
              ?.map((item) => RecipeIngredient.fromJson(item))
              .toList() ??
          [],
      steps: List<String>.from(json['steps'] ?? []),
      ratingAverage: (json['ratingAverage'] ?? 0).toDouble(),
      ratingCount: (json['ratingCount'] ?? 0).toInt(),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      tags: List<String>.from(json['tags'] ?? []),
      glass: json['glass'] ?? '', // グラスの種類
      alcoholStrength: (json['alcoholStrength'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'fileId': fileId,
      'userId': userId,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'steps': steps,
      'ratingAverage': ratingAverage,
      'ratingCount': ratingCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'tags': tags,
      'glass': glass, // グラスの種類
      'alcoholStrength': alcoholStrength,
    };
  }

  Recipe copyWith({
    String? id,
    String? title,
    String? description,
    String? fileId,
    String? userId,
    List<RecipeIngredient>? ingredients,
    List<String>? steps,
    double? ratingAverage,
    int? ratingCount,
    DateTime? createdAt,
    List<String>? tags,
    String? glass,
    double? alcoholStrength,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      fileId: fileId ?? this.fileId,
      userId: userId ?? this.userId,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      ratingAverage: ratingAverage ?? this.ratingAverage,
      ratingCount: ratingCount ?? this.ratingCount,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
      glass: glass ?? this.glass,
      alcoholStrength: alcoholStrength ?? this.alcoholStrength,
    );
  }
}
