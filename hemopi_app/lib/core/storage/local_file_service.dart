import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class LocalFileService {
  Future<Directory> get _appDir async {
    return await getApplicationDocumentsDirectory();
  }

  Future<String> saveSessionCsv({
    required String sessionId,
    required String fileName,
    required String csvContent,
  }) async {
    final root = await _appDir;
    final sessionDir = Directory(join(root.path, 'sessions', sessionId));
    if (!await sessionDir.exists()) {
      await sessionDir.create(recursive: true);
    }
    final file = File(join(sessionDir.path, fileName));
    await file.writeAsString(csvContent, flush: true);
    return join('sessions', sessionId, fileName);
  }

  Future<String> saveReportText({
    required String reportId,
    required String content,
  }) async {
    final root = await _appDir;
    final reportDir = Directory(join(root.path, 'reports'));
    if (!await reportDir.exists()) {
      await reportDir.create(recursive: true);
    }
    final file = File(join(reportDir.path, '$reportId.txt'));
    await file.writeAsString(content, flush: true);
    return join('reports', '$reportId.txt');
  }

  Future<File?> getAbsoluteFile(String relativePath) async {
    final root = await _appDir;
    final file = File(join(root.path, relativePath));
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<String?> readRelativeFile(String relativePath) async {
    final file = await getAbsoluteFile(relativePath);
    if (file != null) {
      return await file.readAsString();
    }
    return null;
  }

  Future<void> deleteAllFiles() async {
    final root = await _appDir;
    final sessionsDir = Directory(join(root.path, 'sessions'));
    if (await sessionsDir.exists()) {
      await sessionsDir.delete(recursive: true);
    }
    final reportsDir = Directory(join(root.path, 'reports'));
    if (await reportsDir.exists()) {
      await reportsDir.delete(recursive: true);
    }
  }
}
