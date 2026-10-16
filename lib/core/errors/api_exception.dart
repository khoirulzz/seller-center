/// Representasi terstruktur error API dan jaringan dengan kode status & machine code.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.machineCode,
    this.isOffline = false,
  });

  final String message;
  final int? statusCode;
  final String? machineCode;
  final bool isOffline;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isLockedEntitlement => statusCode == 423;
  bool get isRateLimited => statusCode == 429;
  bool get isPayloadTooLarge => statusCode == 413;
  bool get isServerSetupRequired => statusCode == 503;

  @override
  String toString() => message;
}
