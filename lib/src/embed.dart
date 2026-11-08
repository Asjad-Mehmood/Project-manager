// Project Folder Manager inside another Flutter program: the Survey Toolkit shows it as one of its
// pages. The same screen, the same keys and the same settings file as the program itself
// (%APPDATA%\Excel to KML\Project Folder Manager), so both show the same project folders. There
// is no "Look for an update": the Toolkit brings new versions.
import 'package:flutter/material.dart';

import 'platform/shell.dart';
import 'state/app_model.dart';
import 'state/store.dart';
import 'ui/home.dart';
import 'ui/theme.dart';

class FolderManagerView extends StatefulWidget {
  const FolderManagerView({super.key, this.model});

  /// For tests: a model of their own instead of this user's settings
  final AppModel? model;

  @override
  State<FolderManagerView> createState() => _FolderManagerViewState();
}

class _FolderManagerViewState extends State<FolderManagerView> {
  late final AppModel _model =
      widget.model ??
      (AppModel(store: Store.forThisUser(), shell: defaultShell())
        ..start()
        ..watchDisk());

  @override
  void dispose() {
    // a model the test passed in is the test's to close
    if (widget.model == null) _model.dispose();
    super.dispose();
  }

  // its own colours, also in its dialogs and menus (they take the theme from here)
  @override
  Widget build(BuildContext context) => Theme(
    data: pfmTheme(),
    child: Home(model: _model),
  );
}
