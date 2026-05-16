import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../constants/api_constant.dart';
import '../../utils/failure.dart';
import '../../utils/functional_api_handler.dart';

/// E2EE (End-to-End Encryption) key management endpoints
mixin E2eeApi on FunctionalApiHandler {
  Dio get dio;

  /// Upload user's RSA Public Key for E2EE
  TaskEither<Failure, void> uploadPublicKey(String publicKey, String deviceId) =>
      makeRequest(
        () => dio.post(
          ApiConstant.uploadPublicKey,
          data: {
            'public_key': publicKey,
            'device_id': deviceId,
          },
        ),
        (_) => null,
      );

  /// Get another user's RSA Public Key for E2EE
  TaskEither<Failure, String?> getPublicKey(int userId) => makeRequest(
        () => dio.get(ApiConstant.getPublicKey(userId)),
        (data) => data['public_key'] as String?,
      );
}

/// Push notification device registration endpoints
mixin NotificationApi on FunctionalApiHandler {
  Dio get dio;

  /// Register an FCM device token for push notifications
  TaskEither<Failure, void> registerDevice(String registrationId, String type) =>
      makeRequest(
        () => dio.post(
          ApiConstant.registerDevice,
          data: {
            'registration_id': registrationId,
            'type': type,
          },
        ),
        (_) => null,
      );

  /// Unregister an FCM device token (on logout)
  TaskEither<Failure, void> unregisterDevice(String registrationId) =>
      makeRequest(
        () => dio.post(
          ApiConstant.unregisterDevice,
          data: {
            'registration_id': registrationId,
          },
        ),
        (_) => null,
      );
}
