import 'dart:io';

import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/brand.dart';
import 'src/platform/shell.dart';
import 'src/self_check.dart';
import 'src/state/app_model.dart';
import 'src/state/store.dart';
import 'src/support/crash_log.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // the Windows check on GitHub's machines: real jobs on a real Windows, then close
  final i = args.indexOf('--self-check');
  if (i >= 0 && args.length > i + 2) {
    exit(await selfCheck(args[i + 1], args[i + 2]) ? 0 : 1);
  }
  CrashLog.start(appName: appName, version: appVersion);
  final model = AppModel(store: Store.forThisUser(), shell: defaultShell())
    ..start()
    ..watchDisk();
  runApp(FolderManagerApp(model: model));
}
