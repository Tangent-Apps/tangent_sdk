import 'dart:developer' as dev;

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class AppLogger {

  AppLogger._();
  static const String _prefix = '[TangentSDK]';
  static bool _isDebugMode = false;

  static void setDebugMode(bool enabled) {
    _isDebugMode = enabled;
  }

  static void debug(String message, {String? tag}) {
    if (_isDebugMode) {
      _log(LogLevel.debug, message, tag);
    }
  }

  static void info(String message, {String? tag}) {
    _log(LogLevel.info, message, tag);
  }

  static void warning(String message, {String? tag}) {
    _log(LogLevel.warning, message, tag);
  }

  static void error(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag);
    if (error != null) {
      dev.log(
        '$_prefix ERROR: $error',
        name: tag ?? 'TangentSDK',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static void _log(LogLevel level, String message, String? tag) {
    final String levelPrefix = _getLevelPrefix(level);
    final String formattedMessage = '$_prefix $levelPrefix ${tag != null ? '[$tag]' : ''} $message';

    dev.log(
      formattedMessage,
      name: tag ?? 'TangentSDK',
      level: _getLogLevel(level),
    );
  }

  static String _getLevelPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔥 DEBUG:';
      case LogLevel.info:
        return '🔥 INFO:';
      case LogLevel.warning:
        return '🔥 WARNING:';
      case LogLevel.error:
        return '🔥 ERROR:';
    }
  }

  static int _getLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}
