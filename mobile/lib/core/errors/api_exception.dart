import 'app_exception.dart';

/// Base type for API-related failures with optional HTTP status.
abstract class ApiException extends AppException {
  const ApiException(
    super.message, {
    this.statusCode,
    this.technicalDetail,
  });

  final int? statusCode;
  final String? technicalDetail;
}

class NetworkException extends ApiException {
  const NetworkException([
    String message = 'Connection failed. Check your network and try again.',
  ]) : super(message);
}

class TimeoutApiException extends ApiException {
  const TimeoutApiException([
    String message = 'Request timed out. Try again.',
  ]) : super(message);
}

class BadRequestException extends ApiException {
  const BadRequestException([
    String message = 'Invalid request.',
    int statusCode = 400,
    String? technicalDetail,
  ]) : super(
          message,
          statusCode: statusCode,
          technicalDetail: technicalDetail,
        );
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([
    String message = 'Invalid email or password.',
    int statusCode = 401,
    String? technicalDetail,
  ]) : super(
          message,
          statusCode: statusCode,
          technicalDetail: technicalDetail,
        );
}

class ForbiddenException extends ApiException {
  const ForbiddenException([
    String message = 'Access denied.',
    int statusCode = 403,
    String? technicalDetail,
  ]) : super(
          message,
          statusCode: statusCode,
          technicalDetail: technicalDetail,
        );
}

class NotFoundException extends ApiException {
  const NotFoundException([
    String message = 'Resource not found.',
    int statusCode = 404,
    String? technicalDetail,
  ]) : super(
          message,
          statusCode: statusCode,
          technicalDetail: technicalDetail,
        );
}

class ConflictException extends ApiException {
  const ConflictException([
    String message = 'Email already registered.',
    int statusCode = 409,
    String? technicalDetail,
  ]) : super(
          message,
          statusCode: statusCode,
          technicalDetail: technicalDetail,
        );
}

class ValidationException extends ApiException {
  const ValidationException(
    String message, {
    int statusCode = 422,
    String? technicalDetail,
  }) : super(
          message,
          statusCode: statusCode,
          technicalDetail: technicalDetail,
        );
}

class RateLimitedException extends ApiException {
  const RateLimitedException([
    String message = 'Too many requests. Try again later.',
    int statusCode = 429,
    String? technicalDetail,
  ]) : super(
          message,
          statusCode: statusCode,
          technicalDetail: technicalDetail,
        );
}

class ServerException extends ApiException {
  const ServerException([
    String message = 'Server error. Try again later.',
    int statusCode = 500,
    String? technicalDetail,
  ]) : super(
          message,
          statusCode: statusCode,
          technicalDetail: technicalDetail,
        );
}

class UnknownApiException extends ApiException {
  const UnknownApiException([
    String message = 'Something went wrong. Try again.',
    int? statusCode,
    String? technicalDetail,
  ]) : super(
          message,
          statusCode: statusCode,
          technicalDetail: technicalDetail,
        );
}
