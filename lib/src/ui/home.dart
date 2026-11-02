// The window: banner, toolbar, drives, then the tree and the panel in one of the six layouts,
// and the status line. Also the keyboard: Alt+1 … Alt+6 for the views (as v6.2), and in the
// panel Ctrl+C / X / V / A, Delete, F2 and Esc (as v6.2) plus Ctrl+Z, Enter, Backspace, the
// arrow keys, F5, Ctrl+F and Alt+Left / Right (new).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_model.dart';
import 'bottom.dart';
import 'commands.dart';
import 'header.dart';
import 'module_list.dart';
import 'side_panel.dart';
import 'toolbar.dart';

class Home extends StatefulWidget {
  const Home({super.key, required this.model, this.clock, this.onCheckUpdates});
  final AppModel model;

  /// A fixed time, for screenshots
  final DateTime? clock;
  final void Function(BuildContext)? onCheckUpdates;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late final cmd = Commands(widget.model, () => context);
  final _root = TextEditingController();
  final _search = TextEditingController();
  final _filter = TextEditingController();
  final _searchFocus = FocusNode();
  final _keys = FocusNode(debugLabel: 'window');
  String _shownRoot = '';
  String? _shownPanel;

  AppModel get m => widget.model;

  @override
  void initState() {
    super.initState();
    m.addListener(_sync);
    _sync();
    if (m.options.drives) m.refreshDrives();
  }

  /// Fields follow the model when the project or the panel's folder changes
  void _sync() {
    if (m.root != _shownRoot) {
      _shownRoot = m.root;
      _root.text = m.root;
    }
    if (m.panelPath != _shownPanel) {
      _shownPanel = m.panelPath;
      if (_filter.text.isNotEmpty) _filter.clear();
    }
  }

  @override
  void dispose() {
    m.removeListener(_sync);
    for (final c in [_root, _search, _filter]) {
      c.dispose();
    }
    _searchFocus.dispose();
    _keys.dispose();
    super.dispose();
  }

  /// The keyboard is in a text box: its keys (Backspace, Ctrl+C, Ctrl+A …) belong to the text
  bool get _typing {
    final c = FocusManager.instance.primaryFocus?.context;
    if (c == null) return false;
    return c.widget is EditableText || c.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (ModalRoute.of(context)?.isCurrent == false) return KeyEventResult.ignored; // a box is open
    final k = HardwareKeyboard.instance;
    final key = e.logicalKey;
    final ctrl = k.isControlPressed, alt = k.isAltPressed, shift = k.isShiftPressed;

    // anywhere
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
    ];
    const pad = [
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
    ];
    if (alt && (digits.contains(key) || pad.contains(key))) {
      m.setLayout(digits.contains(key) ? digits.indexOf(key) : pad.indexOf(key));
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyF) {
      _searchFocus.requestFocus();
      _search.selection = TextSelection(baseOffset: 0, extentOffset: _search.text.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f5) {
      m.refresh();
      return KeyEventResult.handled;
    }
    if (_typing || !m.panelOpen || m.busy) return KeyEventResult.ignored;

    // in the panel
    void run(FutureOr<void> Function() f) => unawaited(Future.sync(f));
    if (alt && key == LogicalKeyboardKey.arrowLeft) return _did(m.panelBack);
    if (alt && key == LogicalKeyboardKey.arrowRight) return _did(m.panelForward);
    if (ctrl && key == LogicalKeyboardKey.keyC) return _did(() => run(cmd.copy));
    if (ctrl && key == LogicalKeyboardKey.keyX) return _did(() => run(cmd.cut));
    if (ctrl && key == LogicalKeyboardKey.keyV) return _did(() => run(cmd.paste));
    if (ctrl && key == LogicalKeyboardKey.keyA) return _did(m.selectAll);
    if (ctrl && key == LogicalKeyboardKey.keyZ) return _did(() => run(cmd.undo));
    if (key == LogicalKeyboardKey.delete) return _did(() => run(cmd.delete));
    if (key == LogicalKeyboardKey.f2) return _did(() => run(cmd.rename));
    if (key == LogicalKeyboardKey.escape) return _did(m.selectNone);
    if (key == LogicalKeyboardKey.backspace) return _did(m.panelUp);
    if (key == LogicalKeyboardKey.arrowDown) return _did(() => m.moveSelection(1, shift: shift));
    if (key == LogicalKeyboardKey.arrowUp) return _did(() => m.moveSelection(-1, shift: shift));
    if (key == LogicalKeyboardKey.enter) {
      final f = m.focused;
      if (f != null) return _did(() => f.isDir ? cmd.view(f.path) : run(() => cmd.open(f.path)));
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _did(void Function() f) {
    f();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _keys,
    autofocus: true,
    onKeyEvent: _onKey,
    child: Scaffold(
      body: ListenableBuilder(
        listenable: m,
        builder: (context, _) => LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            return GestureDetector(
              // a click on an empty part of the window gives the keys back to the window
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_typing) _keys.requestFocus();
              },
              child: Stack(
                children: [
                  Column(
                    children: [
                      Header(model: m, width: w, onEditTitle: cmd.editTitle, clock: widget.clock),
                      Toolbar(
                        model: m,
                        cmd: cmd,
                        rootField: _root,
                        searchField: _search,
                        searchFocus: _searchFocus,
                        onCheckUpdates: () => widget.onCheckUpdates?.call(context),
                      ),
                      if (m.options.drives) DrivesStrip(model: m, cmd: cmd),
                      Expanded(child: _body(w)),
                      StatusBar(model: m, width: w),
                    ],
                  ),
                  if (m.busy) Positioned(left: 0, right: 0, bottom: 0, child: OpBar(model: m)),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );

  /// The tree and the panel in the chosen layout (v6.2's six, with its split widths)
  Widget _body(double w) {
    final lay = m.layout;
    if (lay == 0 || !m.panelOpen) return ModuleList(model: m, cmd: cmd, width: w);
    SidePanel panel(AxisDirection edge) => SidePanel(model: m, cmd: cmd, filter: _filter, edge: edge);
    if (lay == 5) return panel(AxisDirection.down);
    if (lay == 4) {
      return Column(
        children: [
          Expanded(
            child: ModuleList(model: m, cmd: cmd, width: w),
          ),
          Expanded(child: panel(AxisDirection.up)),
        ],
      );
    }
    final pc = switch (lay) {
      1 => 36,
      3 => 64,
      _ => w < 1150 ? 55 : (w > 2200 ? 40 : 50),
    };
    final listW = w * (100 - pc) / 100;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 100 - pc,
          child: ModuleList(model: m, cmd: cmd, width: listW),
        ),
        Expanded(flex: pc, child: panel(AxisDirection.left)),
      ],
    );
  }
}
