/// Helpers para filtrar módulos/actividades de Moodle.
bool isVideoModule(dynamic module) {
  final name = module['name']?.toString().toLowerCase() ?? '';
  return name.contains('video');
}

/// True si el módulo cuenta como ejercicio (no video).
bool isCountableExercise(dynamic module) {
  if (isVideoModule(module)) return false;
  final name = module['name']?.toString().toLowerCase() ?? '';
  return name.contains('ejercicio');
}

bool isModuleCompleted(dynamic module) {
  return module['completionState'] == 1 ||
      module['completionState'] == 2 ||
      (module['grade'] != null && module['grade'] != '-');
}

List<dynamic> modulesWithoutVideo(List<dynamic>? modules) {
  if (modules == null) return const [];
  return modules.where((m) => !isVideoModule(m)).toList();
}
