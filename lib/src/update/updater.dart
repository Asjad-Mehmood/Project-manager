// Self-update for the Windows program. A few seconds after it opens, it reads latest.json from
// the newest GitHub release. When that version is higher it asks; on Yes it downloads the
// installer, checks its SHA-256, runs it silently and closes; the installer opens the new version.
// Any network problem is ignored: the program carries on as normal. "Look for an update" in the
// ⋯ menu does the same at once, and says so when there is nothing new.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../brand.dart';
import '../ui/dialogs/dialogs.dart';
import '../ui/widgets.dart';
import 'update_check.dart';

Future<void> checkForUpdate(BuildContext context, {bool asked = false}) async {
  if (!Platform.isWindows || const bool.fromEnvironment('NO_UPDATE_CHECK')) {
    if (asked && context.mounted) await message(context, 'UPDATES', 'Updates are looked for in the Windows program.');
    return;
  }
  if (!asked) await Future<void>.delayed(const Duration(seconds: 4));
  UpdateInfo? info;
  try {
    final r = await http.get(Uri.parse('$releaseBase$manifestName')).timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) info = UpdateInfo.parse(r.body);
  } catch (_) {
    if (asked && context.mounted) {
      await message(context, 'UPDATES', 'The update server could not be reached. Check the internet connection.');
    }
    return;
  }
  if (!context.mounted) return;
  if (info == null || !isNewer(info.version, appVersion)) {
    if (asked) await message(context, 'UPDATES', 'You have the newest version: $appVersion.');
    return;
  }

  final latest = info;
  final yes = await showDialog<bool>(
    context: context,
    builder: (c) => Box(
      title: 'A NEW VERSION IS READY',
      actions: [
        Btn('LATER', onTap: () => Navigator.pop(c, false)),
        Btn('UPDATE NOW', icon: Icons.system_update_alt, kind: BtnKind.on, onTap: () => Navigator.pop(c, true)),
      ],
      child: Text(
        '$appName ${latest.version} is available (you have $appVersion).\n\n'
        'Update now? The program closes, updates itself and opens again in a few seconds. '
        'Your projects, settings and index stay as they are.',
        style: const TextStyle(fontSize: 13, height: 1.4),
      ),
    ),
  );
  if (yes != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context)
    ..showSnackBar(const SnackBar(content: Text('Downloading the update ...'), duration: Duration(minutes: 5)));
  try {
    final r = await http.get(Uri.parse('$releaseBase$installerName')).timeout(const Duration(minutes: 5));
    if (r.statusCode != 200) throw HttpException('the server answered ${r.statusCode}');
    if (!sha256Matches(r.bodyBytes, latest.sha256)) {
      throw const FileSystemException('the download was damaged (checksum)');
    }
    final file = File('${Directory.systemTemp.path}\\ProjectFolderManager-Update.exe');
    await file.writeAsBytes(r.bodyBytes, flush: true);
    await Process.start(file.path, ['/S', '/UPDATE'], mode: ProcessStartMode.detached);
    exit(0);
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('The update could not be downloaded. Nothing was changed. ($e)')));
  }
}
