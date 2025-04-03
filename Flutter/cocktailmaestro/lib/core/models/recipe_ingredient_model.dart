class RecipeIngredient {
  final String name;
  final String amount;
  final String unit;
  final String materialId;

  RecipeIngredient({
    required this.name,
    required this.amount,
    required this.unit,
    required this.materialId,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: json['name'] ?? '',
      amount: json['amount'] ?? '',
      unit: json['unit'] ?? '',
      materialId: json['materialId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
      'materialId': materialId,
    };
  }
}
