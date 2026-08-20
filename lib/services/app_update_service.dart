import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Comprueba actualizaciones con la API oficial de Google Play.
///
/// Solo funciona en Android con la app instalada desde Play Store
/// (producción, prueba interna, cerrada o abierta). En debug / APK
/// suelto falla de forma silenciosa.
class AppUpdateService {
  AppUpdateService._();

  /// Si hay update y Play permite actualización inmediata, la lanza
  /// (pantalla a pantalla completa; el usuario no puede usar la app
  /// hasta actualizar o cancelar según política de Play).
  ///
  /// Si solo permite flexible, descarga en segundo plano e instala al terminar.
  static Future<void> checkAndUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      if (info.immediateUpdateAllowed) {
        final result = await InAppUpdate.performImmediateUpdate();
        debugPrint('In-app immediate update: $result');
        return;
      }

      if (info.flexibleUpdateAllowed) {
        final result = await InAppUpdate.startFlexibleUpdate();
        debugPrint('In-app flexible update: $result');
        if (result == AppUpdateResult.success) {
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      // Normal en emulador, debug o instalación fuera de Play.
      debugPrint('In-app update check skipped: $e');
    }
  }
}
