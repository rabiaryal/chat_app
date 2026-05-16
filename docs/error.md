# Error Handling Architecture

This project employs a robust, centralized error handling system that combines functional programming principles with a unified UI reporting layer.

## 1. Functional Error Handling (`fpdart`)

Instead of traditional imperative `try-catch` blocks, the application uses **`TaskEither<Failure, T>`** from the `fpdart` package. This makes error handling a first-class citizen in the type system.

-   **`Either<L, R>`**: Represents a value that can be one of two types. By convention, `L` (Left) is the failure type and `R` (Right) is the success type.
-   **`TaskEither`**: Represents an asynchronous operation that might fail.

### Benefits
*   **Explicitness**: You are forced to handle the error case (e.g., using `.fold()`).
*   **Safety**: Eliminates runtime crashes caused by unhandled exceptions.
*   **Readability**: Operations follow a declarative pipeline.

## 2. Failure Models

All errors are encapsulated in a `Failure` sealed class hierarchy (see `lib/utils/failure.dart`):

*   **`ApiFailure`**: Represents server-side errors (e.g., 400 Bad Request, 500 Server Error). It includes the HTTP status code.
*   **`NetworkFailure`**: Represents connectivity issues (e.g., timeout, no internet).
*   **`AuthFailure`**: Specifically for authentication and session-related errors.

## 3. Data Layer Implementation

The `ApiService` uses the **`FunctionalApiHandler`** mixin to standardize how network requests are executed:

```dart
// Standardized request pattern
return makeRequest<User>(
  request: () => dio.get('/api/user'),
  mapper: (data) => User.fromJson(data),
);
```

The mixin automatically catches `DioException`, maps it to the appropriate `Failure` subtype, and returns a `Left(failure)`.

## 4. Provider Integration

Providers execute the API tasks and store the result in an observable state:

```dart
final result = await apiService.login(...).run();

result.fold(
  (failure) {
    _error = failure.message;
    notifyListeners();
  },
  (successData) {
    _currentUser = successData;
    notifyListeners();
  },
);
```

## 5. Centralized UI Reporting

To ensure a consistent user experience, the **`ErrorHandler`** utility ([error_handler.dart](file:///Applications/development/flutter_dev/chat_app/flutter/lib/utils/error_handler.dart)) is used at the UI level.

### Implementation Patterns

#### Action-based Reporting
For one-time actions (like a button click), errors are shown immediately:
```dart
final success = await authProvider.login(...);
if (!success) {
  ErrorHandler.handle(context, authProvider.error);
}
```

#### Listener-based Reporting
For continuous states (like a WebSocket connection in `ChatScreen`), the UI listens for error changes:
```dart
void _onChatError() {
  if (chatProvider.error != null) {
    ErrorHandler.handle(context, chatProvider.error);
  }
}
```

### Visual Feedback
Errors are displayed using a customized **SnackBar** (`SnackbarUtils`) that features:
*   **Color Coding**: Red for errors, Green for success, Purple for info.
*   **Icons**: Visual indicators for the error type.
*   **Dismissal**: Explicit manual dismissal or auto-hide after a duration.
