import 'package:flutter/foundation.dart';
import '../services/insforge_service.dart';
import 'badge_repository.dart';

/// Implementación concreta de [BadgeRepository] que utiliza InsForge como backend.
///
/// Interactúa con la tabla `insignias_usuarios` en InsForge via REST API,
/// la cual tiene:
/// - `moodle_user_id` (texto, llave primaria): identificador del usuario en Moodle.
/// - `insignias` (arreglo de texto): lista de insignias ganadas por el usuario.
///
/// Esta clase sigue el Principio Abierto/Cerrado (OCP): se puede extender el
/// sistema con nuevas implementaciones de [BadgeRepository] (ej. repositorio local)
/// sin modificar esta clase ni la interfaz.
class InsforgeBadgeRepository implements BadgeRepository {
  /// Nombre de la tabla en InsForge.
  static const String _tableName = 'insignias_usuarios';

  /// Referencia al servicio de InsForge.
  final InsforgeService _service = InsforgeService();

  /// {@macro BadgeRepository.getBadges}
  ///
  /// Consulta la tabla `insignias_usuarios` filtrando por [moodleUserId].
  /// Si el usuario no tiene registro, retorna una lista vacía.
  @override
  Future<List<String>> getBadges(String moodleUserId) async {
    try {
      final response = await _service.querySingle(
        _tableName,
        filters: {'moodle_user_id': 'eq.$moodleUserId'},
        select: 'insignias',
      );

      // Si no existe registro para este usuario, retornar lista vacía.
      if (response == null) {
        return [];
      }

      // Convertir el arreglo de InsForge a List<String>.
      final List<dynamic> rawBadges =
          response['insignias'] as List<dynamic>? ?? [];
      return rawBadges.map((badge) => badge.toString()).toList();
    } catch (e) {
      debugPrint(
          'InsforgeBadgeRepository.getBadges: Error al obtener insignias '
          'para usuario $moodleUserId: $e');
      throw BadgeRepositoryException(
        'Error al obtener insignias para el usuario $moodleUserId',
        cause: e,
      );
    }
  }

  /// {@macro BadgeRepository.addBadge}
  ///
  /// Flujo:
  /// 1. Obtiene las insignias actuales del usuario (o lista vacía si no existe).
  /// 2. Verifica que [newBadge] no sea un duplicado.
  /// 3. Usa `upsert` para crear o actualizar el registro en InsForge.
  @override
  Future<void> addBadge(String moodleUserId, String newBadge) async {
    try {
      // 1. Obtener insignias actuales.
      final currentBadges = await getBadges(moodleUserId);

      // 2. Verificar duplicados — si ya existe, no hacer nada.
      if (currentBadges.contains(newBadge)) {
        debugPrint('InsforgeBadgeRepository.addBadge: La insignia "$newBadge" '
            'ya existe para el usuario $moodleUserId. No se agrega duplicado.');
        return;
      }

      // 3. Agregar la nueva insignia y hacer upsert.
      final updatedBadges = [...currentBadges, newBadge];

      await _service.upsert(_tableName, [
        {
          'moodle_user_id': moodleUserId,
          'insignias': updatedBadges,
        }
      ]);

      debugPrint('InsforgeBadgeRepository.addBadge: Insignia "$newBadge" '
          'agregada exitosamente para el usuario $moodleUserId.');
    } catch (e) {
      // Si el error ya es una BadgeRepositoryException (del getBadges),
      // re-lanzarla sin envolverla de nuevo.
      if (e is BadgeRepositoryException) {
        rethrow;
      }

      debugPrint('InsforgeBadgeRepository.addBadge: Error al agregar insignia '
          '"$newBadge" para usuario $moodleUserId: $e');
      throw BadgeRepositoryException(
        'Error al agregar la insignia "$newBadge" para el usuario $moodleUserId',
        cause: e,
      );
    }
  }
}
