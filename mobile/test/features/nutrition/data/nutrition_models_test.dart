import 'package:fittrack_ai/features/nutrition/data/models/create_nutrition_log_request.dart';
import 'package:fittrack_ai/features/nutrition/data/models/nutrition_log.dart';
import 'package:fittrack_ai/features/nutrition/data/models/nutrition_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses nutrition log with all fields', () {
    final log = NutritionLog.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'date': '2026-07-03',
      'calories': 1850,
      'protein': 105.5,
      'carbs': 210,
      'fats': 55,
      'notes': 'Good protein intake.',
    });

    expect(log.calories, 1850);
    expect(log.protein, 105.5);
    expect(log.carbs, 210);
    expect(log.fats, 55);
    expect(log.notes, 'Good protein intake.');
  });

  test('parses nutrition log with null notes', () {
    final log = NutritionLog.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'date': '2026-07-03',
      'calories': 1850,
      'protein': 105,
      'carbs': 210,
      'fats': 55,
      'notes': null,
    });

    expect(log.notes, isNull);
  });

  test('parses int and double numeric values', () {
    final log = NutritionLog.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'date': '2026-07-03',
      'calories': 1850,
      'protein': 105,
      'carbs': 210,
      'fats': 55,
      'notes': null,
    });

    expect(log.protein, 105.0);
    expect(log.carbs, 210.0);
    expect(log.fats, 55.0);
  });

  test('rejects invalid nutrition log payload', () {
    expect(
      () => NutritionLog.fromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'date': '2026-07-03',
        'calories': 'many',
        'protein': 105,
        'carbs': 210,
        'fats': 55,
        'notes': null,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects invalid date', () {
    expect(
      () => NutritionLog.fromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'date': 'not-a-date',
        'calories': 1850,
        'protein': 105,
        'carbs': 210,
        'fats': 55,
        'notes': null,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('serializes create request omitting empty notes', () {
    final request = CreateNutritionLogRequest(
      date: DateTime(2026, 7, 3),
      calories: 2100,
      protein: 130,
      carbs: 250,
      fats: 65,
    );

    expect(request.toJson(), {
      'date': '2026-07-03',
      'calories': 2100,
      'protein': 130,
      'carbs': 250,
      'fats': 65,
    });
  });

  test('serializes create request with notes', () {
    final request = CreateNutritionLogRequest(
      date: DateTime(2026, 7, 3),
      calories: 2100,
      protein: 130,
      carbs: 250,
      fats: 65,
      notes: 'Demo note',
    );

    expect(request.toJson(), {
      'date': '2026-07-03',
      'calories': 2100,
      'protein': 130,
      'carbs': 250,
      'fats': 65,
      'notes': 'Demo note',
    });
  });

  test('parses nutrition summary', () {
    final summary = NutritionSummary.fromJson({
      'days_logged': 2,
      'avg_calories': 1850,
      'avg_protein': 105,
      'avg_carbs': 205,
      'avg_fats': 55,
      'total_calories': 3700,
      'total_protein': 210,
      'total_carbs': 410,
      'total_fats': 110,
    });

    expect(summary.daysLogged, 2);
    expect(summary.avgCalories, 1850);
    expect(summary.totalCalories, 3700);
    expect(summary.isEmpty, isFalse);
  });

  test('parses empty nutrition summary', () {
    final summary = NutritionSummary.fromJson({
      'days_logged': 0,
      'avg_calories': 0,
      'avg_protein': 0,
      'avg_carbs': 0,
      'avg_fats': 0,
      'total_calories': 0,
      'total_protein': 0,
      'total_carbs': 0,
      'total_fats': 0,
    });

    expect(summary.isEmpty, isTrue);
  });
}
