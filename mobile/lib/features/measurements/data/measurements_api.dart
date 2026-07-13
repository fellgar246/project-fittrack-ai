import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'models/create_measurement_request.dart';
import 'models/json_parsing.dart';
import 'models/measurement.dart';
import 'models/measurement_progress.dart';

class MeasurementsApi {
  MeasurementsApi(this._client);

  final ApiClient _client;

  Future<List<Measurement>> getMeasurements({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final response = await _client.get<List<dynamic>>(
      ApiEndpoints.measurements,
      queryParameters: _dateRangeQuery(dateFrom, dateTo),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty measurements list response.');
    }

    return data.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid measurement item in list.');
      }
      return Measurement.fromJson(item);
    }).toList(growable: false);
  }

  Future<Measurement> createMeasurement(
    CreateMeasurementRequest request,
  ) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.measurements,
      data: request.toJson(),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty create measurement response.');
    }
    return Measurement.fromJson(data);
  }

  Future<MeasurementProgress> getProgress({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.measurementProgress,
      queryParameters: _dateRangeQuery(dateFrom, dateTo),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty measurement progress response.');
    }
    return MeasurementProgress.fromJson(data);
  }
}

Map<String, String>? _dateRangeQuery(DateTime? dateFrom, DateTime? dateTo) {
  if (dateFrom == null && dateTo == null) {
    return null;
  }

  return {
    if (dateFrom != null) 'date_from': dateOnly(dateFrom),
    if (dateTo != null) 'date_to': dateOnly(dateTo),
  };
}
