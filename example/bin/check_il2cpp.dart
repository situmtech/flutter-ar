import 'dart:io';

import 'package:io/io.dart' as io;

import 'config.dart';

void main() {
  try {
    if (Platform.isLinux || Platform.isMacOS) {
      String templatePath = il2cppPath;
      String deployPath =
          '${Directory.current.path}/android/unityExport/src/main/Il2CppOutputProject/IL2CPP/build/deploy';

      _checkDirs([templatePath, deployPath]);

      Directory(deployPath).deleteSync(recursive: true);
      io.copyPathSync(templatePath, deployPath);
    }
  } catch (e) {
    print(e);
  }
}

void _checkDirs(List<String> dirs) {
  for (var dir in dirs) {
    if (!Directory(dir).existsSync()) {
      throw Exception('Directory not found: `$dir`');
    }
  }
}