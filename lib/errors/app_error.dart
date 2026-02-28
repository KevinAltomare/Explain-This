enum AppErrorType {
  // Phase 1 — Camera
  cameraPermission,
  cameraUnavailable,
  cameraFailure,

  // Phase 2 — OCR
  ocrFailure,
  emptyScan,

  // Phase 3 — OpenAI / Network
  networkFailure,
  timeout,
  rateLimited,
  invalidApiKey,
  modelUnavailable,
  invalidResponse,

  // Phase 4 — Storage / File
  fileMissing,
  storageFailure,
  dataCorruption,

  // Catch‑all
  unexpected,
}

class AppError {
  final AppErrorType type;
  final String message;

  AppError(this.type, this.message);
}