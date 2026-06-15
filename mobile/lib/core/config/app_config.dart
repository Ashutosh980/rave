/// Backend and sync configuration.
class AppConfig {
  /// Set at build time for distributed APKs, e.g.
  /// --dart-define=API_BASE_URL=https://your-server.com
  static const String compileTimeServerUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String prefsServerUrlKey = 'server_url';

  /// Emulator fallback when nothing is configured.
  static const String emulatorDefault = 'http://10.0.2.2:3000';

  /// Resync participant playback when drift exceeds this threshold.
  static const int driftThresholdMs = 500;

  /// How often non-host clients check for playback drift.
  static const Duration driftCheckInterval = Duration(seconds: 2);

  static String resolveServerUrl(String? savedUrl) {
    // Baked-in deploy URL wins (distributed APK builds)
    if (compileTimeServerUrl.isNotEmpty) {
      return _normalize(compileTimeServerUrl);
    }
    final saved = savedUrl?.trim();
    if (saved != null && saved.isNotEmpty) {
      return _normalize(saved);
    }
    return emulatorDefault;
  }

  static String _normalize(String url) {
    var normalized = url.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
