import 'package:dio/dio.dart';

import '../errors/api_exception.dart';

ApiException mapDioException(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const TimeoutApiException();
    case DioExceptionType.connectionError:
      return NetworkException(
        error.message ?? 'Connection failed. Check your network and try again.',
      );
    case DioExceptionType.cancel:
      return const UnknownApiException('Request was cancelled.');
    case DioExceptionType.badCertificate:
      return const NetworkException('Secure connection failed.');
    case DioExceptionType.badResponse:
      return mapHttpResponse(error.response);
    case DioExceptionType.unknown:
      return UnknownApiException(
        error.message ?? 'Something went wrong. Try again.',
      );
  }
}

ApiException mapHttpResponse(Response<dynamic>? response) {
  if (response == null) {
    return const UnknownApiException();
  }

  final statusCode = response.statusCode ?? 0;
  final message = _extractDetailMessage(response.data);
  final technicalDetail = _extractTechnicalDetail(response.data);

  switch (statusCode) {
    case 400:
      return BadRequestException(
        message ?? 'Invalid request.',
        400,
        technicalDetail,
      );
    case 401:
      return UnauthorizedException(
        message ?? 'Invalid email or password.',
        401,
        technicalDetail,
      );
    case 403:
      return ForbiddenException(
        message ?? 'Access denied.',
        403,
        technicalDetail,
      );
    case 404:
      return NotFoundException(
        message ?? 'Resource not found.',
        404,
        technicalDetail,
      );
    case 409:
      return ConflictException(
        message ?? 'Email already registered.',
        409,
        technicalDetail,
      );
    case 422:
      return ValidationException(
        message ?? 'Validation failed. Check your input.',
        technicalDetail: technicalDetail,
      );
    case 429:
      return RateLimitedException(
        message ?? 'Too many requests. Try again later.',
        429,
        technicalDetail,
      );
    default:
      if (statusCode >= 500) {
        return ServerException(
          message ?? 'Server error. Try again later.',
          statusCode,
          technicalDetail,
        );
      }
      return UnknownApiException(
        message ?? 'Something went wrong. Try again.',
        statusCode,
        technicalDetail,
      );
  }
}

String? _extractDetailMessage(dynamic data) {
  if (data is Map<String, dynamic>) {
    final detail = data['detail'];
    if (detail is String) {
      return detail;
    }
    if (detail is Map<String, dynamic>) {
      final message = detail['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    if (detail is List) {
      return _formatValidationDetail(detail);
    }
  }
  return null;
}

String? _extractTechnicalDetail(dynamic data) {
  if (data is Map<String, dynamic>) {
    final detail = data['detail'];
    if (detail is List) {
      return detail.toString();
    }
    if (detail is String) {
      return detail;
    }
  }
  return null;
}

String? _formatValidationDetail(List<dynamic> detail) {
  if (detail.isEmpty) {
    return 'Validation failed. Check your input.';
  }

  final first = detail.first;
  if (first is Map<String, dynamic>) {
    final field = _formatFieldLocation(first['loc']);
    final message = first['msg'];
    if (field != null && message is String) {
      return '$field: $message';
    }
    if (message is String) {
      return message;
    }
  }

  return 'Validation failed. Check your input.';
}

String? _formatFieldLocation(dynamic location) {
  if (location is! List) {
    return null;
  }

  final parts = location
      .whereType<String>()
      .where((part) => part != 'body')
      .toList(growable: false);

  if (parts.isEmpty) {
    return null;
  }

  return parts.join('.');
}
