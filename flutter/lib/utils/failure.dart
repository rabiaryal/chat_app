import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ApiFailure extends Failure {
  final int? statusCode;
  const ApiFailure(String message, {this.statusCode}) : super(message);

  @override
  List<Object?> get props => [message, statusCode];
}

class NetworkFailure extends Failure {
  const NetworkFailure(String message) : super(message);
}

class AuthFailure extends Failure {
  const AuthFailure(String message) : super(message);
}
