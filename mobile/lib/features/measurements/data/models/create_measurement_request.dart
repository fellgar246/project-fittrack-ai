import 'json_parsing.dart';

class CreateMeasurementRequest {
  const CreateMeasurementRequest({
    required this.date,
    required this.weight,
    this.waist,
    this.bodyFatEstimate,
    this.notes,
  });

  final DateTime date;
  final double weight;
  final double? waist;
  final double? bodyFatEstimate;
  final String? notes;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'date': dateOnly(date),
      'weight': weight,
    };

    if (waist != null) {
      json['waist'] = waist;
    }
    if (bodyFatEstimate != null) {
      json['body_fat_estimate'] = bodyFatEstimate;
    }
    if (notes != null) {
      json['notes'] = notes;
    }

    return json;
  }
}
