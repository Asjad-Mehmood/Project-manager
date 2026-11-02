// LIST & EDIT: the folder's names (or full paths) in a text box to select and copy, or to edit
// and APPLY RENAMES. New in v7: a live preview beside the box shows each change and anything
// wrong before a single name changes, and quick tools edit every line at once.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/bulk_rename.dart';
import '../../core/disk.dart';
import '../../state/app_model.dart';
import '../theme.dart';
import '../widgets.dart';
import 'dialogs.dart';

Future<void> listEdit(BuildContext context, AppModel model) {
  final listed = model.panelEntries();
  if (listed.isEmpty) {
    return message(context, 'LIST & EDIT', 'Nothing is listed.\n\nOpen a folder first, or clear the filter.');
  }
  return showDialog<void>(context: context, builder: (c) => _ListEdit(model, listed));
}

class _ListEdit extends StatefulWidget {
  const _ListEdit(this.model, this.listed);
  final AppModel model;
  final List<Entry> listed;
  @override
  State<_ListEdit> createState() => _ListEditState();
}

class _ListEditState extends State<_ListEdit> {
  late final _box = TextEditingController(text: _names());
  final _boxFocus = FocusNode();
  final _find = TextEditingController();
  final _replace = TextEditingController();
  final _before = TextEditingController();
  final _after = TextEditingController();
  bool _paths = false;
  bool _busy = false;
  RenamePlan? _plan;

  String get _folder => widget.model.panelPath!;
  String _names() => widget.listed.map((e) => e.name).join('\r\n');

  @override
  void initState() {
    super.initState();
    _box.addListener(_replan);
    _replan();
    WidgetsBinding.instance.addPostFrameCallback((_) => _selectAll());
  }

  @override
  void dispose() {
    for (final c in [_box, _find, _replace, _before, _after]) {
      c.dispose();
    }
    _boxFocus.dispose();
    super.dispose();
  }

  void _replan() {
    if (_paths) return;
    setState(() => _plan = planRenames(widget.listed, _box.text, (n) => anyExists(p.join(_folder, n))));
  }

  void _mode(bool paths) {
    _paths = paths;
    _box.text = paths ? widget.listed.map((e) => e.path).join('\r\n') : _names();
    setState(() => _plan = paths ? null : _plan);
    if (!paths) _replan();
    _selectAll();
  }

  void _selectAll() {
    _boxFocus.requestFocus();
    _box.selection = TextSelection(baseOffset: 0, extentOffset: _box.text.length);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _box.text));
    widget.model.say('${boxLines(_box.text).length} line(s) copied to the clipboard');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to the clipboard')));
    }
  }

  void _tool(List<String> Function(List<String>) f) {
    if (_paths) _mode(false);
    _box.text = f(boxLines(_box.text)).join('\r\n');
  }

  Future<void> _apply() async {
    final plan = _plan;
    if (_paths || plan == null) return;
    if (!plan.ok) {
      await message(
        context,
        'CANNOT RENAME - nothing was changed',
        plan.countProblem ?? 'Fix these first:',
        lines: [for (final (n, why) in plan.problems) '$n    $why'],
      );
      return;
    }
    if (plan.changes.isEmpty) {
      await message(context, 'LIST & EDIT', 'No names were changed.');
      return;
    }
    final ok = await confirm(
      context,
      'RENAME ${plan.changes.length} ITEM(S)',
      'In $_folder\n\nClose any Explorer window showing these first. UNDO (Ctrl+Z) puts the names back.',
      yes: 'RENAME',
      amber: true,
      lines: [
        for (final c in plan.changes.take(20)) '${c.from}\n    →  ${c.to}',
        if (plan.changes.length > 20) '... and ${plan.changes.length - 20} more',
      ],
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final (done, failed) = await widget.model.applyBulk(plan);
    if (!mounted) return;
    Navigator.pop(context);
    if (failed.isNotEmpty) {
      await message(
        context,
        '$done renamed, ${failed.length} failed',
        'Usually because the folder is open in Explorer, or a file inside it is in use.',
        lines: [for (final (n, why) in failed) '$n    $why'],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final lines = boxLines(_box.text).length;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 36),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [C.barTop, C.panelBottom],
          ),
          border: Border.all(color: C.teal, width: 2),
          borderRadius: BorderRadius.circular(5),
          boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 40)],
        ),
        child: Column(
          children: [
            _head(),
            _tools(lines),
            _quickTools(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: _textBox()),
                    if (!_paths) ...[const SizedBox(width: 12), Expanded(flex: 4, child: _preview(plan))],
                  ],
                ),
              ),
            ),
            _foot(),
          ],
        ),
      ),
    );
  }

  Widget _head() => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [C.panelHeadTop, C.panelHeadBottom],
      ),
      border: Border(bottom: BorderSide(color: C.barEdge)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LIST & EDIT',
                style: t(17, color: C.white, w: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              Text(
                _folder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t(10, color: C.amber, m: true),
              ),
            ],
          ),
        ),
        Btn('CLOSE', icon: Icons.close, onTap: () => Navigator.pop(context)),
      ],
    ),
  );

  Widget _tools(int lines) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    decoration: const BoxDecoration(
      color: C.tools,
      border: Border(bottom: BorderSide(color: C.toolsEdge)),
    ),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 6,
      children: [
        const Lbl('SHOWING'),
        Btn('NAMES', lit: !_paths, onTap: () => _mode(false)),
        Btn('FULL PATHS', lit: _paths, onTap: () => _mode(true)),
        const SizedBox(width: 14),
        Btn('SELECT ALL', icon: Icons.select_all, onTap: _selectAll),
        Btn('COPY', icon: Icons.copy, kind: BtnKind.on, onTap: _copy),
        if (!_paths) ...[
          const SizedBox(width: 14),
          Btn('APPLY RENAMES', icon: Icons.edit, kind: BtnKind.amber, onTap: _busy ? null : _apply),
        ],
        const SizedBox(width: 14),
        Lbl('$lines LINE(S)'),
      ],
    ),
  );

  Widget _quickTools() {
    final s = t(12);
    Widget f(TextEditingController c, String hint, double w) => Padding(
      padding: const EdgeInsets.only(left: 5),
      child: Field(controller: c, hint: hint, width: w, style: s),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 7),
      decoration: const BoxDecoration(
        color: C.tools2,
        border: Border(bottom: BorderSide(color: C.toolsEdge)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 6,
        children: [
          const Lbl('QUICK TOOLS', right: 2),
          f(_find, 'find', 130),
          f(_replace, 'replace with', 130),
          Btn(
            'REPLACE',
            tip: 'Find and replace in every line (any case)',
            onTap: () => _tool((l) => findReplace(l, _find.text, _replace.text)),
          ),
          const SizedBox(width: 12),
          f(_before, 'add before', 100),
          f(_after, 'add after', 100),
          Btn(
            'ADD',
            tip: 'Add text before and after each name (the extension stays at the end)',
            onTap: () => _tool((l) => addText(l, before: _before.text, after: _after.text)),
          ),
          const SizedBox(width: 12),
          Btn('01_ NUMBER', tip: 'Number the lines: 01_, 02_ …', onTap: () => _tool((l) => number(l))),
          MenuBtn(
            'Aa CASE',
            tip: 'Upper case, lower case, Title Case, spaces and underscores',
            items: () => [
              menuItem('UPPER CASE', () => _tool((l) => changeCase(l, CaseChange.upper))),
              menuItem('lower case', () => _tool((l) => changeCase(l, CaseChange.lower))),
              menuItem('Title Case', () => _tool((l) => changeCase(l, CaseChange.title))),
              menuItem('spaces → underscores', () => _tool(swapSpaces)),
              menuItem('underscores → spaces', () => _tool((l) => swapSpaces(l, toUnderscore: false))),
            ],
          ),
          const SizedBox(width: 12),
          Btn('RESET', tip: 'Back to the names on the disk', onTap: () => _mode(false)),
        ],
      ),
    );
  }

  Widget _textBox() => TextField(
    controller: _box,
    focusNode: _boxFocus,
    maxLines: null,
    expands: true,
    textAlignVertical: TextAlignVertical.top,
    style: t(13, m: true, h: 1.45),
    decoration: fieldDecoration().copyWith(contentPadding: const EdgeInsets.all(10)),
    onTapOutside: (_) {},
  );

  Widget _preview(RenamePlan? plan) {
    Widget body;
    if (plan == null) {
      body = const SizedBox();
    } else if (plan.countProblem != null) {
      body = Text(plan.countProblem!, style: t(12, color: C.red, h: 1.4));
    } else if (plan.changes.isEmpty && plan.problems.isEmpty) {
      body = Text(
        'Edit a line on the left: each change shows here before anything is renamed.',
        style: t(12, color: C.label, h: 1.4),
      );
    } else {
      body = ListView(
        children: [
          for (final (n, why) in plan.problems)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('✕  $n\n    $why', style: t(12, color: C.red, m: true, h: 1.35)),
            ),
          for (final c in plan.changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${c.from}\n',
                      style: t(12, color: C.muted, m: true, h: 1.35),
                    ),
                    TextSpan(
                      text: '  →  ',
                      style: t(12, color: C.teal, m: true),
                    ),
                    TextSpan(
                      text: c.to,
                      style: t(12, color: C.amber, m: true, h: 1.35),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    final ok = plan != null && plan.ok && plan.changes.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: C.field,
        border: Border.all(color: plan != null && !plan.ok ? C.red : C.fieldEdge),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Lbl(
            plan == null
                ? 'PREVIEW'
                : !plan.ok
                ? 'PREVIEW  ·  ${plan.countProblem != null ? 'LINE COUNT DOES NOT MATCH' : '${plan.problems.length} PROBLEM(S)'}'
                : 'PREVIEW  ·  ${plan.changes.length} CHANGE(S)${ok ? '  ·  READY' : ''}',
          ),
          const SizedBox(height: 8),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _foot() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
    decoration: const BoxDecoration(
      color: C.tools,
      border: Border(top: BorderSide(color: C.toolsEdge)),
    ),
    child: Text(
      'Select the text and press Ctrl+C to copy  ·  edit any line, then APPLY RENAMES to rename on the disk  ·  '
      'don\'t add or remove lines  ·  UNDO (Ctrl+Z) puts the names back',
      style: t(11, color: C.label),
    ),
  );
}
