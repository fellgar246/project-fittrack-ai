import 'json_parsing.dart';

class NutritionLog {
  const NutritionLog({
    required this.id,
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.notes,
  });

  final String id;
  final DateTime date;
  final int calories;
  final double protein;
  final double carbs;
  final double fats;
  final String? notes;

  factory NutritionLog.fromJson(Map<String, dynamic> json) {
    return NutritionLog(
      id: requiredString(json, 'id'),
      date: requiredDate(json, 'date'),
      calories: requiredNonNegativeInt(json, 'calories'),
      protein: requiredDouble(json, 'protein'),
      carbs: requiredDouble(json, 'carbs'),
      fats: requiredDouble(json, 'fats'),
      notes: optionalString(json, 'notes'),
    );
  }
}
