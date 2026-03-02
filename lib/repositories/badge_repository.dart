/// Interfaz abstracta que define los contratos para la gestión de insignias.
///
/// Aplicando el Principio Abierto/Cerrado (OCP) de SOLID, la lógica de negocio
/// depende de esta abstracción en lugar de implementaciones concretas.
/// Esto permite agregar nuevos repositorios (ej. local con SQLite, otro backend)
/// sin modificar las clases existentes.
abstract class BadgeRepository {
  /// Retorna la lista de insignias para el usuario identificado por [moodleUserId].
  ///
  /// Devuelve una lista vacía si el usuario no tiene insignias registradas
  /// o si el registro no existe.
  ///
  /// Lanza una excepción [BadgeRepositoryException] si ocurre un error
  /// en la comunicación con el backend.
  Future<List<String>> getBadges(String moodleUserId);

  /// Agrega una nueva insignia [newBadge] al arreglo del usuario [moodleUserId].
  ///
  /// Comportamiento esperado:
  /// - Si el usuario no existe en el almacenamiento, se crea el registro
  ///   automáticamente con su primera insignia (upsert).
  /// - Si la insignia ya existe en el arreglo del usuario, no se duplica.
  ///
  /// Lanza una excepción [BadgeRepositoryException] si ocurre un error
  /// en la comunicación con el backend.
  Future<void> addBadge(String moodleUserId, String newBadge);
}

/// Excepción personalizada para errores del repositorio de insignias.
///
/// Encapsula el mensaje de error y opcionalmente la causa original,
/// proporcionando un manejo de errores limpio y consistente.
class BadgeRepositoryException implements Exception {
  /// Mensaje descriptivo del error.
  final String message;

  /// Causa original de la excepción, si existe.
  final Object? cause;

  const BadgeRepositoryException(this.message, {this.cause});

  @override
  String toString() => 'BadgeRepositoryException: $message';
}
