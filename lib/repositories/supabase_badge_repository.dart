import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'badge_repository.dart';

/// Implementación concreta de [BadgeRepository] que utiliza Supabase como backend.
///
/// Interactúa con la tabla `insignias_usuarios` en Supabase, la cual tiene:
/// - `moodle_user_id` (texto, llave primaria): identificador del usuario en Moodle.
/// - `insignias` (arreglo de texto): lista de insignias ganadas por el usuario.
///
/// Esta clase sigue el Principio Abierto/Cerrado (OCP): se puede extender el
/// sistema con nuevas implementaciones de [BadgeRepository] (ej. repositorio local)
/// sin modificar esta clase ni la interfaz.
class SupabaseBadgeRepository implements BadgeRepository {
  /// Nombre de la tabla en Supabase.
  static const String _tableName = 'insignias_usuarios';

  /// Referencia al cliente de Supabase.
  ///
  /// Se obtiene de la instancia singleton inicializada en `main.dart`.
  SupabaseClient get _client => Supabase.instance.client;

  /// {@macro BadgeRepository.getBadges}
  ///
  /// Consulta la tabla `insignias_usuarios` filtrando por [moodleUserId].
  /// Si el usuario no tiene registro, retorna una lista vacía.
  @override
  Future<List<String>> getBadges(String moodleUserId) async {
    try {
      final response = await _client
          .from(_tableName)
          .select('insignias')
          .eq('moodle_user_id', moodleUserId)
          .maybeSingle();

      // Si no existe registro para este usuario, retornar lista vacía.
      if (response == null) {
        return [];
      }

      // Convertir el arreglo de Supabase a List<String>.
      final List<dynamic> rawBadges =
          response['insignias'] as List<dynamic>? ?? [];
      return rawBadges.map((badge) => badge.toString()).toList();
    } catch (e) {
      debugPrint(
          'SupabaseBadgeRepository.getBadges: Error al obtener insignias '
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
  /// 3. Usa `upsert` para crear o actualizar el registro en Supabase.
  @override
  Future<void> addBadge(String moodleUserId, String newBadge) async {
    try {
      // 1. Obtener insignias actuales.
      final currentBadges = await getBadges(moodleUserId);

      // 2. Verificar duplicados — si ya existe, no hacer nada.
      if (currentBadges.contains(newBadge)) {
        debugPrint('SupabaseBadgeRepository.addBadge: La insignia "$newBadge" '
            'ya existe para el usuario $moodleUserId. No se agrega duplicado.');
        return;
      }

      // 3. Agregar la nueva insignia y hacer upsert.
      final updatedBadges = [...currentBadges, newBadge];

      await _client.from(_tableName).upsert({
        'moodle_user_id': moodleUserId,
        'insignias': updatedBadges,
      });

      debugPrint('SupabaseBadgeRepository.addBadge: Insignia "$newBadge" '
          'agregada exitosamente para el usuario $moodleUserId.');
    } catch (e) {
      // Si el error ya es una BadgeRepositoryException (del getBadges),
      // re-lanzarla sin envolverla de nuevo.
      if (e is BadgeRepositoryException) {
        rethrow;
      }

      debugPrint('SupabaseBadgeRepository.addBadge: Error al agregar insignia '
          '"$newBadge" para usuario $moodleUserId: $e');
      throw BadgeRepositoryException(
        'Error al agregar la insignia "$newBadge" para el usuario $moodleUserId',
        cause: e,
      );
    }
  }
}
