import 'dart:async';

import 'package:flutter/material.dart';

import 'brand.dart';
import 'state/app_model.dart';
import 'ui/home.dart';
import 'ui/theme.dart';
import 'update/updater.dart';

class FolderManagerApp extends StatefulWidget {
  const FolderManagerApp({super.key, required this.model, this.clock, this.checkUpdates = true});
  final AppModel model;

  /// A fixed time, for screenshots
  final DateTime? clock;
  final bool checkUpdates;

  @override
  State<FolderManagerApp> createState() => _FolderManagerAppState();
}

class _FolderManagerAppState extends State<FolderManagerApp> {
  final _nav = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    if (widget.checkUpdates) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _nav.currentContext;
        if (c != null) unawaited(checkForUpdate(c));
      });
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: appName,
    navigatorKey: _nav,
    debugShowCheckedModeBanner: false,
    theme: pfmTheme(),
    home: Home(model: widget.model, clock: widget.clock, onCheckUpdates: (c) => checkForUpdate(c, asked: true)),
  );
}
