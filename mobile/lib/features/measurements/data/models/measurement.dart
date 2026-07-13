import 'json_parsing.dart';

class Measurement {
  const Measurement({
    required this.id,
    required this.date,
    required this.weight,
    this.waist,
    this.bodyFatEstimate,
    this.notes,
  });

  final String id;
  final DateTime date;
  final double weight;
  final double? waist;
  final double? bodyFatEstimate;
  final String? notes;

  factory Measurement.fromJson(Map<String, dynamic> json) {
    return Measurement(
      id: requiredString(json, 'id'),
      date: requiredDate(json, 'date'),
      weight: requiredDouble(json, 'weight'),
      waist: optionalDouble(json, 'waist'),
      bodyFatEstimate: optionalDouble(json, 'body_fat_estimate'),
      notes: optionalString(json, 'notes'),
    );
  }
}
