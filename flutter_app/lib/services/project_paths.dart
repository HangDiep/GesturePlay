import 'dart:io';

class ProjectPaths {
  static String locateRoot() {
    const configured = String.fromEnvironment('GESTUREPLAY_ROOT');
    if (configured.isNotEmpty) return configured;
    for (final start in [
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    ]) {
      var dir = start;
      for (var i = 0; i < 9; i++) {
        if (File('${dir.path}/config.py').existsSync() &&
            Directory('${dir.path}/models').existsSync()) {
          return dir.path;
        }
        if (dir.parent.path == dir.path) break;
        dir = dir.parent;
      }
    }
    return Directory.current.path;
  }

  static String get python => '${locateRoot()}/.venv/Scripts/python.exe';
  static String get service => '${locateRoot()}/main.py';
  static File get results =>
      File('${locateRoot()}/flutter_app/data/runner_results.json');
}
