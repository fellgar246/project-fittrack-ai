import 'json_parsing.dart';

class CreateNutritionLogRequest {
  const CreateNutritionLogRequest({
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.notes,
  });

  final DateTime date;
  final int calories;
  final double protein;
  final double carbs;
  final double fats;
  final String? notes;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'date': dateOnly(date),
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
    };

    if (notes != null) {
      json['notes'] = notes;
    }

    return json;
  }
}
