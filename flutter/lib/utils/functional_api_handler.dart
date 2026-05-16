import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'failure.dart';

String _extractErrorMessage(dynamic data, String fallback) {
  if (data is Map<String, dynamic>) {
    return (data['error'] ?? data['detail'] ?? data['message'] ?? fallback)
        .toString();
  }
  return fallback;
}

mixin FunctionalApiHandler {
  TaskEither<Failure, T> makeRequest<T>(
    Future<Response> Function() request,
    FutureOr<T> Function(dynamic data) mapper,
  ) {
    return TaskEither(() async {
      try {
        final response = await request();
        final statusCode = response.statusCode ?? 0;

        if (statusCode >= 200 && statusCode < 300) {
          return Right(await mapper(response.data));
        }

        return Left(
          ApiFailure(
            _extractErrorMessage(
              response.data,
              'Request failed',
            ),
            statusCode: statusCode,
          ),
        );
      } on DioException catch (error) {
        return Left(
          ApiFailure(
            _extractErrorMessage(
              error.response?.data,
              error.message ?? 'Network error',
            ),
            statusCode: error.response?.statusCode,
          ),
        );
      } catch (error) {
        return Left(ApiFailure(error.toString()));
      }
    });
  }
}
