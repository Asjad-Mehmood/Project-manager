// What Help and Report a problem say about Project Folder Manager
import '../brand.dart';
import 'help.dart';

/// [openUrl]: the program's own way to open a page (the Windows shell)
AppInfo folderManagerInfo(Future<void> Function(String url) openUrl) => AppInfo(
  name: appName,
  version: appVersion,
  publisher: appPublisher,
  program: 'folder-manager',
  guideUrl: appPage,
  whatsNewUrl: 'https://www.surveyxdigital.com/whats-new/folder-manager',
  openUrl: openUrl,
);
