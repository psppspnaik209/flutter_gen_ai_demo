import 'dart:io';

import 'package:flutter_gen_ai_demo/models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gen_ai.dart';

const _modelFolderKey = 'model_folder_path';
const _modelFolderUriKey = 'model_folder_uri';

List<String> _getModelFileNames() {
  return Models.getModel().files.map((file) => file.split('/').last).toList();
}

Future<void> setModelFolderPath(String? path) async {
  final prefs = await SharedPreferences.getInstance();
  if (path == null || path.isEmpty) {
    await prefs.remove(_modelFolderKey);
  } else {
    await prefs.setString(_modelFolderKey, path);
  }
}

Future<void> setModelFolderUri(String? uri) async {
  final prefs = await SharedPreferences.getInstance();
  if (uri == null || uri.isEmpty) {
    await prefs.remove(_modelFolderUriKey);
  } else {
    await prefs.setString(_modelFolderUriKey, uri);
  }
}

Future<String?> getModelFolderPath() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_modelFolderKey);
}

Future<String?> getModelFolderUri() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_modelFolderUriKey);
}

Future<String> getModelPath() async {
  final configured = await getModelFolderPath();
  if (configured == null || configured.isEmpty) {
    throw Exception('Model folder not set');
  }
  return configured;
}

Future<bool> isModelFilesExist() async {
  final missingFiles = await getMissingModelFiles();
  return missingFiles.isEmpty;
}

Future<List<String>> getMissingModelFiles() async {
  final expectedFiles = _getModelFileNames();
  final configured = await getModelFolderPath();
  if (configured == null || configured.isEmpty) {
    return expectedFiles;
  }
  final directory = Directory(configured);
  final missing = <String>[];
  if (!await directory.exists()) {
    return expectedFiles;
  }
  for (final fileName in expectedFiles) {
    final file = File('${directory.path}/$fileName');
    if (!await file.exists()) {
      missing.add(fileName);
      continue;
    }
    final length = await file.length();
    if (length == 0) {
      missing.add(fileName);
    }
  }
  return missing;
}

Future<void> configureModelFolderSelection(String selection) async {
  if (selection.startsWith('content://')) {
    await setModelFolderUri(selection);
    await setModelFolderPath(null);
    final targetDir = await _getAppModelPath();
    await GenAI.copyModelFromUri(selection, targetDir, _getModelFileNames());
    await setModelFolderPath(targetDir);
  } else {
    await setModelFolderUri(null);
    await setModelFolderPath(selection);
  }
}

Future<String> _getAppModelPath() async {
  final doc = await getApplicationSupportDirectory();
  final modelDir = Directory('${doc.path}/${Models.getModel().path}');
  if (!await modelDir.exists()) {
    await modelDir.create(recursive: true);
  }
  return modelDir.path;
}
