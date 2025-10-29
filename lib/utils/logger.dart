// lib/utils/logger.dart

import 'package:flutter/foundation.dart';
import 'constants.dart';

/// Sistema de logging centralizado con tag GRANIZO_BG
class AppLogger {
  static const String _tag = AppConstants.logTag;

  /// Log de información general
  static void info(String message) {
    if (kDebugMode) {
      print('[$_tag] ℹ️ $message');
    }
  }

  /// Log de advertencias
  static void warning(String message) {
    if (kDebugMode) {
      print('[$_tag] ⚠️ WARNING: $message');
    }
  }

  /// Log de errores
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('[$_tag] ❌ ERROR: $message');
      if (error != null) {
        print('[$_tag]    Error: $error');
      }
      if (stackTrace != null) {
        print('[$_tag]    StackTrace: $stackTrace');
      }
    }
  }

  /// Log de éxito
  static void success(String message) {
    if (kDebugMode) {
      print('[$_tag] ✅ $message');
    }
  }

  /// Log de debug (solo en modo debug)
  static void debug(String message) {
    if (kDebugMode) {
      print('[$_tag] 🐛 DEBUG: $message');
    }
  }

  /// Log de inicio de operación
  static void start(String operation) {
    if (kDebugMode) {
      print('[$_tag] 🚀 Iniciando: $operation');
    }
  }

  /// Log de fin de operación
  static void end(String operation) {
    if (kDebugMode) {
      print('[$_tag] 🏁 Completado: $operation');
    }
  }
}