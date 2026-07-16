import 'json_parsing.dart';

class NutritionSummary {
  const NutritionSummary({
    required this.daysLogged,
    required this.avgCalories,
    required this.avgProtein,
    required this.avgCarbs,
    required this.avgFats,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFats,
  });

  final int daysLogged;
  final double avgCalories;
  final double avgProtein;
  final double avgCarbs;
  final double avgFats;
  final int totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFats;

  bool get isEmpty => daysLogged == 0;

  factory NutritionSummary.fromJson(Map<String, dynamic> json) {
    return NutritionSummary(
      daysLogged: requiredNonNegativeInt(json, 'days_logged'),
      avgCalories: requiredDouble(json, 'avg_calories'),
      avgProtein: requiredDouble(json, 'avg_protein'),
      avgCarbs: requiredDouble(json, 'avg_carbs'),
      avgFats: requiredDouble(json, 'avg_fats'),
      totalCalories: requiredNonNegativeInt(json, 'total_calories'),
      totalProtein: requiredDouble(json, 'total_protein'),
      totalCarbs: requiredDouble(json, 'total_carbs'),
      totalFats: requiredDouble(json, 'total_fats'),
    );
  }
}
