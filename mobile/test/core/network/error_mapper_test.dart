import 'package:dio/dio.dart';
import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/core/network/error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapDioException', () {
    test('maps connection timeout to TimeoutApiException', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        type: DioExceptionType.connectionTimeout,
      );

      expect(mapDioException(error), isA<TimeoutApiException>());
    });

    test('maps connection error to NetworkException', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        type: DioExceptionType.connectionError,
      );

      expect(mapDioException(error), isA<NetworkException>());
    });
  });

  group('mapHttpResponse', () {
    test('maps 401 to UnauthorizedException', () {
      final exception = mapHttpResponse(
        Response<dynamic>(
          requestOptions: RequestOptions(path: '/auth/me'),
          statusCode: 401,
          data: const {'detail': 'Could not validate credentials'},
        ),
      );

      expect(exception, isA<UnauthorizedException>());
      expect(exception.message, 'Could not validate credentials');
    });

    test('maps 409 to ConflictException', () {
      final exception = mapHttpResponse(
        Response<dynamic>(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 409,
          data: const {'detail': 'Email already registered'},
        ),
      );

      expect(exception, isA<ConflictException>());
    });

    test('maps 422 validation list to ValidationException', () {
      final exception = mapHttpResponse(
        Response<dynamic>(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 422,
          data: const {
            'detail': [
              {
                'loc': ['body', 'email'],
                'msg': 'value is not a valid email address',
              },
            ],
          },
        ),
      );

      expect(exception, isA<ValidationException>());
      expect(exception.message, contains('email'));
    });

    test('maps nested 422 readiness detail to ValidationException', () {
      final exception = mapHttpResponse(
        Response<dynamic>(
          requestOptions: RequestOptions(path: '/recommendations/weekly'),
          statusCode: 422,
          data: const {
            'detail': {
              'message': 'Not enough weekly data to generate recommendation',
              'missing_data': ['workout_logs'],
            },
          },
        ),
      );

      expect(exception, isA<ValidationException>());
      expect(
        exception.message,
        'Not enough weekly data to generate recommendation',
      );
    });

    test('maps 500 to ServerException', () {
      final exception = mapHttpResponse(
        Response<dynamic>(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 500,
          data: const {'detail': 'Internal error'},
        ),
      );

      expect(exception, isA<ServerException>());
    });

    test('maps unknown status to UnknownApiException', () {
      final exception = mapHttpResponse(
        Response<dynamic>(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 418,
        ),
      );

      expect(exception, isA<UnknownApiException>());
    });
  });
}
