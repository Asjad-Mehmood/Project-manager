// The program's boxes, in v6.2's colours: messages, yes / no, a name to type, the clash
// question, the discipline picker, FIND's list of projects, and Properties.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/disciplines.dart';
import '../../core/file_ops.dart';
import '../../core/format.dart';
import '../../core/project_finder.dart';
import '../../state/app_model.dart';
import '../theme.dart';
import '../widgets.dart';

/// The frame every box uses: a title, a body and buttons on the right
class Box extends StatelessWidget {
  const Box({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.edge = C.teal,
    this.width = 580,
    this.titleColor = C.white,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final Color edge;
  final double width;
  final Color titleColor;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: C.dialog,
    insetPadding: const EdgeInsets.all(24),
    shape: RoundedRectangleBorder(
      // a quiet frame; only a warning (delete, a clash) gets its colour
      side: BorderSide(color: edge == C.teal ? C.fieldEdge : edge),
      borderRadius: BorderRadius.circular(12),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: t(16, color: titleColor, w: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Flexible(child: SingleChildScrollView(child: child)),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(alignment: WrapAlignment.end, spacing: 2, runSpacing: 6, children: actions),
            ],
          ],
        ),
      ),
    ),
  );
}

Future<void> message(BuildContext context, String title, String text, {List<String> lines = const []}) =>
    showDialog<void>(
      context: context,
      builder: (c) => Box(
        title: title,
        actions: [Btn('OK', kind: BtnKind.on, onTap: () => Navigator.pop(c))],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(text, style: t(13, h: 1.4)),
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: C.field,
                  border: Border.all(color: C.fieldEdge),
                ),
                child: SelectableText(lines.join('\n'), style: t(12, m: true, h: 1.4)),
              ),
            ],
          ],
        ),
      ),
    );

Future<bool> confirm(
  BuildContext context,
  String title,
  String text, {
  String yes = 'CONTINUE',
  String no = 'CANCEL',
  List<String> lines = const [],
  bool amber = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => Box(
        title: title,
        edge: amber ? C.amber : C.teal,
        titleColor: amber ? C.amber : C.white,
        actions: [
          Btn(no, onTap: () => Navigator.pop(c, false)),
          Btn(yes, kind: amber ? BtnKind.amber : BtnKind.on, onTap: () => Navigator.pop(c, true)),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: t(13, h: 1.4)),
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: C.field,
                  border: Border.all(color: C.fieldEdge),
                ),
                child: Text(lines.join('\n'), style: t(12, m: true, h: 1.4)),
              ),
            ],
          ],
        ),
      ),
    ) ==
    true;

/// A name to type. [check] says what is wrong with it, or null; the box shows it as you type.
Future<String?> ask(
  BuildContext context,
  String title,
  String text, {
  String initial = '',
  String ok = 'OK',
  String? Function(String)? check,
  bool selectBase = false,
}) => showDialog<String>(context: context, builder: (c) => _Ask(title, text, initial, ok, check, selectBase));

class _Ask extends StatefulWidget {
  const _Ask(this.title, this.text, this.initial, this.ok, this.check, this.selectBase);
  final String title, text, initial, ok;
  final String? Function(String)? check;
  final bool selectBase;
  @override
  State<_Ask> createState() => _AskState();
}

class _AskState extends State<_Ask> {
  late final _c = TextEditingController(text: widget.initial);
  String? _problem;

  @override
  void initState() {
    super.initState();
    // like Explorer: only the name is selected, not the extension
    final dot = widget.initial.lastIndexOf('.');
    _c.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.selectBase && dot > 0 ? dot : widget.initial.length,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _ok() {
    final v = _c.text.trim();
    final pr = v.isEmpty ? 'type a name' : widget.check?.call(v);
    if (pr != null) {
      setState(() => _problem = pr);
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) => Box(
    title: widget.title,
    actions: [
      Btn('CANCEL', onTap: () => Navigator.pop(context)),
      Btn(widget.ok, kind: BtnKind.on, onTap: _ok),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.text.isNotEmpty) ...[
          Text(widget.text, style: t(12, color: C.soft, h: 1.4)),
          const SizedBox(height: 10),
        ],
        Field(
          controller: _c,
          autofocus: true,
          style: t(13),
          onSubmitted: (_) => _ok(),
          onChanged: (v) {
            if (_problem != null) setState(() => _problem = widget.check?.call(v.trim()));
          },
        ),
        if (_problem != null) ...[const SizedBox(height: 6), Text(_problem!, style: t(12, color: C.red))],
      ],
    ),
  );
}

/// NAME ALREADY EXISTS: replace, keep both, skip, cancel; once or for all the rest
Future<(Clash, bool)> askClash(BuildContext context, String name, String destination, {required bool move}) async {
  final r = await showDialog<(Clash, bool)>(
    context: context,
    barrierDismissible: false,
    builder: (c) {
      Widget b(String l, Clash x, bool all, {BtnKind k = BtnKind.plain}) =>
          Btn(l, kind: k, onTap: () => Navigator.pop(c, (x, all)));
      return Box(
        title: 'NAME ALREADY EXISTS',
        edge: C.amber,
        titleColor: C.amber,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: t(12, m: true)),
            Text('already exists in', style: t(12, color: C.label)),
            Text(destination, style: t(12, m: true)),
            const SizedBox(height: 4),
            Text(
              'Replace overwrites files; a folder is merged with the one already there.',
              style: t(11, color: C.label),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 5,
              runSpacing: 6,
              children: [
                b('REPLACE', Clash.replace, false, k: BtnKind.on),
                b('KEEP BOTH', Clash.keepBoth, false, k: BtnKind.on),
                b('SKIP', Clash.skip, false),
                const SizedBox(width: 9),
                b('CANCEL ALL', Clash.cancel, false),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: C.fieldEdge, height: 1),
            const SizedBox(height: 10),
            const Lbl('DO THE SAME FOR EVERY REMAINING CLASH'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 6,
              children: [
                b('REPLACE ALL', Clash.replace, true),
                b('KEEP BOTH ALL', Clash.keepBoth, true),
                b('SKIP ALL', Clash.skip, true),
              ],
            ),
          ],
        ),
      );
    },
  );
  return r ?? (Clash.cancel, false);
}

/// The discipline picker: every discipline in its colour
Future<String?> pickDiscipline(BuildContext context, String moduleName, String current) => showDialog<String>(
  context: context,
  builder: (c) => Box(
    title: moduleName,
    width: 640,
    actions: [Btn('CANCEL', icon: Icons.close, onTap: () => Navigator.pop(c))],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose the discipline for this folder', style: t(11, color: C.subtitle, ls: .6)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final d in disciplines.keys)
              Hover(
                cursor: SystemMouseCursors.click,
                builder: (context, h) => GestureDetector(
                  onTap: () => Navigator.pop(c, d),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: disciplineColor(d),
                      borderRadius: BorderRadius.circular(4),
                      border: d == current ? Border.all(color: C.white, width: 2) : null,
                      boxShadow: h ? const [BoxShadow(color: Color(0xFF99FFFF), blurRadius: 14)] : null,
                    ),
                    child: Text(
                      d,
                      style: t(12, color: C.ink, w: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  ),
);

/// After dropping items on a folder: move or copy them there?
Future<bool?> askDrop(BuildContext context, int count, String folder) => showDialog<bool>(
  context: context,
  builder: (c) => Box(
    title: '${plural(count, 'item')} onto ${p.basename(folder)}',
    actions: [
      Btn('CANCEL', onTap: () => Navigator.pop(c)),
      Btn('COPY HERE', icon: Icons.copy, kind: BtnKind.on, onTap: () => Navigator.pop(c, false)),
      Btn('MOVE HERE', icon: Icons.drive_file_move_outline, kind: BtnKind.amber, onTap: () => Navigator.pop(c, true)),
    ],
    child: Text(folder, style: t(12, color: C.amber, m: true)),
  ),
);

/// FIND: looks on every drive for folders holding numbered modules
Future<String?> findProjectDialog(BuildContext context, List<String> roots) =>
    showDialog<String>(context: context, builder: (c) => _Find(roots));

class _Find extends StatefulWidget {
  const _Find(this.roots);
  final List<String> roots;
  @override
  State<_Find> createState() => _FindState();
}

class _FindState extends State<_Find> {
  List<Candidate>? _found;
  bool _stop = false;

  @override
  void initState() {
    super.initState();
    findProjects(widget.roots, cancelled: () => _stop).then((f) {
      if (mounted) setState(() => _found = f);
    });
  }

  @override
  void dispose() {
    _stop = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = _found;
    return Box(
      title: 'FIND A PROJECT',
      width: 680,
      actions: [Btn('CLOSE', onTap: () => Navigator.pop(context))],
      child: f == null
          ? Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text('Looking on ${widget.roots.join('  ')} for folders with numbered modules ...', style: t(12)),
              ],
            )
          : f.isEmpty
          ? Text(
              'No project folder found on ${widget.roots.join('  ')}.\n\nUse BROWSE and pick the project folder yourself.',
              style: t(13, h: 1.4),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Click one to open it:', style: t(12, color: C.soft)),
                const SizedBox(height: 8),
                for (final c in f)
                  Hover(
                    cursor: SystemMouseCursors.click,
                    builder: (context, h) => GestureDetector(
                      onTap: () => Navigator.pop(context, c.path),
                      child: AccentBox(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.fromLTRB(7, 7, 10, 7),
                        color: h ? C.vrowHover : C.rowBottom,
                        accent: h ? C.tealHi : C.teal,
                        accentWidth: 3,
                        radius: 3,
                        child: Row(
                          children: [
                            folderIcon,
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(c.path, style: t(12, m: true, color: C.amber)),
                            ),
                            Text('${c.modules} modules', style: t(11, color: C.label)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Properties: where it is, how big, how many files (new in v7)
Future<void> properties(BuildContext context, String path, {required bool isDir, int? size, DateTime? modified}) =>
    showDialog<void>(
      context: context,
      builder: (c) => Box(
        title: p.basename(path).isEmpty ? path : p.basename(path),
        actions: [
          Btn(
            'COPY PATH',
            icon: Icons.content_copy,
            onTap: () => Clipboard.setData(ClipboardData(text: path)),
          ),
          Btn('OK', kind: BtnKind.on, onTap: () => Navigator.pop(c)),
        ],
        child: _Props(path, isDir, size, modified),
      ),
    );

class _Props extends StatefulWidget {
  const _Props(this.path, this.isDir, this.size, this.modified);
  final String path;
  final bool isDir;
  final int? size;
  final DateTime? modified;
  @override
  State<_Props> createState() => _PropsState();
}

class _PropsState extends State<_Props> {
  (int, int, int)? _m;

  @override
  void initState() {
    super.initState();
    if (widget.isDir) {
      AppModel.measure(widget.path).then((m) {
        if (mounted) setState(() => _m = m);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget row(String k, String v, {bool mono = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Lbl(k)),
          Expanded(
            child: SelectableText(
              v,
              style: t(12, m: mono, color: mono ? C.amber : C.text),
            ),
          ),
        ],
      ),
    );
    final m = _m;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row('WHERE', widget.path, mono: true),
        row('TYPE', widget.isDir ? 'Folder' : '${extLabel(widget.path)} file'),
        if (!widget.isDir) row('SIZE', fileSize(widget.size)),
        if (widget.isDir)
          row(
            'SIZE',
            m == null ? 'counting ...' : '${fileSize(m.$1)}  ·  ${plural(m.$2, 'file')}, ${plural(m.$3, 'folder')}',
          ),
        if (widget.modified != null) row('MODIFIED', shortDateTime(widget.modified!)),
      ],
    );
  }
}
