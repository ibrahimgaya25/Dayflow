import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models.dart';

class StorageService {
  static const _fileName = 'dayflow_state_v1.json';
  static const _backupName = 'dayflow_state_v1.backup.json';

  Future<Directory> get _directory => getApplicationDocumentsDirectory();

  Future<DayFlowData> load() async {
    final directory = await _directory;
    final primary = File('${directory.path}/$_fileName');
    final backup = File('${directory.path}/$_backupName');
    for (final file in [primary, backup]) {
      if (!await file.exists()) continue;
      try {
        return DayFlowData.fromJsonString(await file.readAsString());
      } on FormatException {
        // Try the backup before starting fresh.
      }
    }
    return DayFlowData.fresh();
  }

  Future<void> save(DayFlowData data) async {
    final directory = await _directory;
    final primary = File('${directory.path}/$_fileName');
    final backup = File('${directory.path}/$_backupName');
    final temporary = File('${directory.path}/$_fileName.tmp');
    data.rev = DateTime.now().millisecondsSinceEpoch;
    await temporary.writeAsString(data.toJsonString(), flush: true);
    if (await primary.exists()) await primary.copy(backup.path);
    await temporary.rename(primary.path);
  }

  Future<File> createExport(DayFlowData data) async {
    final directory = await getTemporaryDirectory();
    final export = File('${directory.path}/dayflow-export-${ymd(DateTime.now())}.json');
    await export.writeAsString(data.toJsonString(pretty: true), flush: true);
    return export;
  }
}
