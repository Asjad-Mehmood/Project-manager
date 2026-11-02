import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:project_folder_manager/src/self_check.dart';

void main() {
  test('the self-check passes here too (Windows-only steps are checked on Windows)', () async {
    final base = Directory.systemTemp.createTempSync('pfm-self');
    addTearDown(() => base.deleteSync(recursive: true));
    final report = p.join(base.path, 'report.json');
    await selfCheck(p.join(base.path, 'run'), report);
    final r = jsonDecode(File(report).readAsStringSync()) as Map<String, Object?>;
    final steps = (r['steps']! as List).cast<Map<String, Object?>>();
    final failed = [
      for (final s in steps)
        if (s['ok'] != true) '${s['step']}: ${s['error']}',
    ];
    // there are no drives on Linux; everything else must pass
    expect(failed.where((f) => !f.startsWith('the drives')), isEmpty);
    expect(steps, hasLength(9));
  });
}
