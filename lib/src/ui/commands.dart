// What each button, menu item and key does, with the questions and answers around it. The
// toolbar, the rows, the right-click menus and the keyboard all come here, so a job is done the
// same way however it is started.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../brand.dart';
import '../core/disk.dart';
import '../core/file_ops.dart';
import '../core/format.dart';
import '../core/names.dart';
import '../core/settings.dart';
import '../state/app_model.dart';
import '../state/store.dart';
import 'dialogs/dialogs.dart';
import 'dialogs/list_edit.dart';
import 'dialogs/manual.dart';
import 'theme.dart';

class Commands {
  Commands(this.model, this._context);
  final AppModel model;
  final BuildContext Function() _context;
  BuildContext get context => _context();

  void toast(String text) {
    final m = ScaffoldMessenger.maybeOf(context);
    m
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, style: t(12)),
          duration: const Duration(seconds: 3),
          width: 520,
        ),
      );
  }

  // ---------------------------------------------------------------- project

  Future<void> setRoot(String path) async {
    final why = model.setRoot(path);
    if (why != null) {
      await message(context, 'OPEN A FOLDER', why);
      return;
    }
    if (model.project != null && model.modules.isEmpty && context.mounted) await offerStandardFolders();
  }

  Future<void> browse() async {
    final f = await model.shell.pickFolder(initial: model.rootExists ? model.root : null);
    if (f != null) await setRoot(f);
  }

  Future<void> find() async {
    final roots = [
      for (final d in model.shell.drives())
        if (d.ready && d.type != 'CD Drive') d.root,
    ];
    if (roots.isEmpty) {
      await message(
        context,
        'FIND',
        'No drive could be read on this PC.\n\nChoose the folder from the menu top left instead.',
      );
      return;
    }
    final picked = await findProjectDialog(context, roots);
    if (picked != null) await setRoot(picked);
  }

  Future<void> offerStandardFolders() async {
    final yes = await confirm(
      context,
      'AN EMPTY FOLDER',
      '${model.root}\n\nhas no folders inside yet. Make the standard project folders?',
      yes: 'MAKE THEM',
      lines: const [
        '00_Admin  10_Survey  20_Piping  30_Electrical  40_Telecom  50_Civil Works',
        '60_Utilities  70_Facilities  80_Roads  90_Design & Drawings  99_Archive',
      ],
    );
    if (!yes) return;
    final failed = await model.createStandardFolders();
    if (failed.isNotEmpty && context.mounted) {
      await message(context, 'SOME FOLDERS WERE NOT MADE', 'These could not be made:', lines: failed);
    }
  }

  Future<void> openRoot() async {
    if (!model.rootExists) {
      await message(context, 'OPEN IN EXPLORER', 'This folder is not on this PC:\n\n   ${model.root}');
      return;
    }
    await model.shell.openFolder(model.root);
  }

  Future<void> editTitle() async {
    if (model.project == null) return;
    final n = await ask(
      context,
      'NAME',
      'The name shown at the top left. Leave it empty for the folder\'s own name; nothing on the disk changes.',
      initial: model.project!.title,
    );
    if (n != null) model.setTitle(n);
  }

  Future<void> forgetProject(int i) async {
    final pr = model.settings.projects[i];
    final ok = await confirm(
      context,
      'REMOVE FROM THE LIST',
      '${pr.title.isEmpty ? pr.root : '${pr.title}\n${pr.root}'}\n\nOnly the list forgets it: nothing on the disk changes.',
      yes: 'REMOVE',
    );
    if (ok) model.forgetProject(i);
  }

  Future<void> importV6([String? file]) async {
    final f = file ?? await model.shell.pickFile(label: 'Project Folder Manager settings', extensions: const ['txt']);
    if (f == null) return;
    final why = model.importV6(f);
    if (!context.mounted) return;
    if (why != null) {
      await message(context, 'IMPORT', why);
    } else {
      toast('Settings brought in from $v6ConfigName');
    }
  }

  /// Type or paste the folder (or drive) to open
  Future<void> typePath() async {
    final v = await ask(
      context,
      'OPEN A FOLDER',
      'Type or paste a folder or a drive, for example D:\\Projects\\North Gas or D:',
      initial: model.root,
      ok: 'OPEN',
      check: (x) => folderExists(x) || RegExp(r'^[A-Za-z]:$').hasMatch(x.trim()) && folderExists('${x.trim()}\\')
          ? null
          : 'that folder is not on this PC',
    );
    if (v != null) await setRoot(v);
  }

  /// MANUAL (F1): how to use the program
  Future<void> manual() => showManual(context);

  Future<void> shortcuts() => message(
    context,
    'KEYBOARD SHORTCUTS',
    'Anywhere',
    lines: const [
      'F1                the manual',
      'Alt+1 … Alt+6     the six views',
      'Ctrl+F            search',
      'F5                read the disk again',
      '',
      'In the panel',
      'Up / Down         move (Shift: select more)',
      'Enter             open',
      'Backspace         the folder above',
      'Alt+Left / Right  back / forward',
      'Ctrl+A            select all       Esc  select none',
      'Ctrl+C / X / V    copy / cut / paste',
      'F2                rename           Delete  to the Recycle Bin',
      'Ctrl+Z            undo',
    ],
  );

  Future<void> about() => message(
    context,
    '$appName  v$appVersion',
    'A dashboard for your project folders: open a drive or any folder, see its folders by discipline, search everything, '
        'and copy, move and rename without leaving it.\n\nSettings: ${model.store.settingsDir}\nIndex: ${model.store.dataDir}\n\n'
        'Updates arrive by themselves: the program checks when it opens.\n$appPage',
  );

  // ---------------------------------------------------------------- index

  Future<void> index([IndexScope? scope]) async {
    final sc = scope ?? model.options.scope;
    model.setScope(sc);
    if (sc != IndexScope.project) {
      final ok = await confirm(
        context,
        'INDEX ${sc.label.toUpperCase()}',
        'This reads every folder and file so that searching afterwards is instant. It can take a few minutes the '
            'first time, in the background: you can keep working, and STOP keeps what was found.',
        yes: 'START',
      );
      if (!ok) return;
    }
    final why = await model.startIndex();
    if (why != null && context.mounted) await message(context, 'INDEX', why);
  }

  // ---------------------------------------------------------------- disciplines

  Future<void> chooseDiscipline(Module m) async {
    final d = await pickDiscipline(context, m.name, m.discipline);
    if (d != null) model.setDiscipline(m.name, d);
  }

  // ---------------------------------------------------------------- opening

  void view(String path) {
    final why = model.openPanel(path);
    if (why != null) message(context, 'VIEW', why);
  }

  void showFile(String path) {
    final why = model.showFile(path);
    if (why != null) message(context, 'VIEW', why);
  }

  Future<void> open(String path) async {
    final ok = await model.openInWindows(path);
    if (ok || !context.mounted) return;
    final reveal = await confirm(
      context,
      'NO PROGRAM FOR THIS FILE',
      'Windows could not open this file:\n\n   $path\n\nThere may be no program for this type of file.',
      yes: 'SHOW IN EXPLORER',
    );
    if (reveal) await model.shell.reveal(path);
  }

  Future<void> copyText(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    model.say(what);
    toast(what);
  }

  // ---------------------------------------------------------------- the panel's jobs

  Future<void> newFolder([String? parent]) async {
    final dir = parent ?? model.panelPath;
    if (dir == null) return;
    final n = await ask(
      context,
      'NEW FOLDER',
      'Inside:\n$dir',
      initial: 'New folder',
      ok: 'MAKE IT',
      check: (v) => nameProblem(v) ?? (anyExists(p.join(dir, v)) ? 'something with that name is already there' : null),
    );
    if (n == null) return;
    final why = await model.makeFolder(n, dir);
    if (why != null && context.mounted) await message(context, 'NEW FOLDER', why);
  }

  Future<void> rename([Entry? item]) async {
    final sel = item != null ? [item] : model.selection();
    if (sel.length != 1) {
      await message(context, 'RENAME', 'Select exactly one item to rename.\n\nTo rename many at once use LIST / EDIT.');
      return;
    }
    final e = sel.single;
    final n = await ask(
      context,
      'RENAME',
      e.path,
      initial: e.name,
      ok: 'RENAME',
      selectBase: e.isFile,
      check: (v) {
        final pr = nameProblem(v);
        if (pr != null) return pr;
        if (v.toLowerCase() != e.name.toLowerCase() && anyExists(p.join(p.dirname(e.path), v))) {
          return 'that name already exists here';
        }
        return null;
      },
    );
    if (n == null || n == e.name) return;
    final why = await model.rename(e, n);
    if (why != null && context.mounted) await message(context, 'RENAME FAILED', why);
  }

  Future<void> listAndEdit() => listEdit(context, model);

  void copy({List<Entry>? items}) {
    if (!model.copySelection(cut: false, items: items)) _selectFirst();
  }

  void cut({List<Entry>? items}) {
    if (!model.copySelection(cut: true, items: items)) _selectFirst();
  }

  void _selectFirst() => message(
    context,
    'NOTHING SELECTED',
    'Select something first.\n\nClick a row, Ctrl+click for several, Shift+click for a range.',
  );

  Future<void> paste([String? into]) async {
    final why = model.pasteCheck(into);
    if (why != null) {
      await message(context, 'PASTE', why);
      return;
    }
    await _run(() => model.pasteHere((n, d) => askClash(context, n, d, move: model.clipCut), destination: into));
  }

  /// Items dragged onto a folder
  Future<void> drop(List<Item> items, String folder) async {
    final its = [
      for (final i in items)
        if (pathKey(p.dirname(i.path)) != pathKey(folder) && pathKey(i.path) != pathKey(folder)) i,
    ];
    if (its.isEmpty) return;
    final why = pasteProblem(its, folder, move: false);
    if (why != null) {
      await message(context, 'DROP', why);
      return;
    }
    final move = await askDrop(context, its.length, folder);
    if (move == null || !context.mounted) return;
    await _run(
      () => model.pasteHere(
        (n, d) => askClash(context, n, d, move: move),
        destination: folder,
        items: its,
        move: move,
      ),
    );
  }

  Future<void> _run(Future<OpResult> Function() job) async {
    final r = await job();
    if (!context.mounted) return;
    if (r.failed.isNotEmpty) {
      await message(
        context,
        '${r.ok} done, ${r.failed.length} failed',
        'Usually because the item is open in another program, or the path is too long.',
        lines: [for (final (n, why) in r.failed) '$n\n    $why'],
      );
    } else {
      toast('${model.status}${r.undo != null ? '  ·  Ctrl+Z to undo' : ''}');
    }
  }

  Future<void> delete([List<Entry>? items]) async {
    final a = items ?? model.selection();
    if (a.isEmpty) return _selectFirst();
    final ok = await confirm(
      context,
      'SEND ${plural(a.length, 'ITEM').toUpperCase()} TO THE RECYCLE BIN?',
      'You can get them back from the Recycle Bin.',
      yes: 'DELETE',
      amber: true,
      lines: [for (final e in a.take(15)) e.name, if (a.length > 15) '... and ${a.length - 15} more'],
    );
    if (!ok) return;
    final failed = await model.deleteItems(a);
    if (!context.mounted) return;
    if (failed.isNotEmpty) {
      await message(context, '${a.length - failed.length} deleted, ${failed.length} failed', '', lines: failed);
    } else {
      toast(model.status);
    }
  }

  Future<void> undo() async {
    final s = model.lastUndo;
    if (s == null) {
      toast('Nothing to undo.');
      return;
    }
    final failed = await model.undo();
    if (!context.mounted) return;
    if (failed.isNotEmpty) {
      await message(context, 'UNDO', 'Some things could not be put back:', lines: failed);
    } else {
      toast(model.status);
    }
  }

  Future<void> props(Entry e) => properties(context, e.path, isDir: e.isDir, size: e.size, modified: e.modified);

  // ---------------------------------------------------------------- right-click menus

  Future<void> menuAt(Offset at, List<(IconData, String, VoidCallback?)?> items) async {
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final pick = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        for (var i = 0; i < items.length; i++)
          if (items[i] == null)
            const PopupMenuDivider(height: 8)
          else
            PopupMenuItem<int>(
              value: i,
              height: 30,
              enabled: items[i]!.$3 != null,
              child: Row(
                children: [
                  Icon(items[i]!.$1, size: 15, color: items[i]!.$3 == null ? C.muted : C.teal),
                  const SizedBox(width: 10),
                  Text(items[i]!.$2, style: t(12, color: items[i]!.$3 == null ? C.muted : C.text)),
                ],
              ),
            ),
      ],
    );
    if (pick != null) items[pick]!.$3!();
  }

  Future<void> folderMenu(Offset at, String path, {Module? module}) => menuAt(at, [
    (Icons.folder_open, 'View in the panel', () => view(path)),
    (Icons.bolt, 'Open in Explorer', () => open(path)),
    null,
    (Icons.create_new_folder_outlined, 'New folder inside ...', () => newFolder(path)),
    (Icons.content_paste, 'Paste here', model.clip.isEmpty ? null : () => paste(path)),
    if (module != null) (Icons.palette_outlined, 'Change the discipline ...', () => chooseDiscipline(module)),
    (
      model.isPinned(path) ? Icons.star : Icons.star_border,
      model.isPinned(path) ? 'Unpin' : 'Pin for quick access',
      () => model.togglePin(path),
    ),
    null,
    (Icons.content_copy, 'Copy the path', () => copyText(path, 'path copied: $path')),
    (Icons.info_outline, 'Properties', () => properties(context, path, isDir: true)),
  ]);

  Future<void> entryMenu(Offset at, Entry e) {
    if (!model.isSelected(e)) model.click(e);
    final sel = model.selection();
    final many = sel.length > 1;
    return menuAt(at, [
      (Icons.bolt, e.isDir ? 'Open in Explorer' : 'Open', many ? null : () => open(e.path)),
      if (e.isDir) (Icons.folder_open, 'View here', many ? null : () => view(e.path)),
      if (e.isFile) (Icons.manage_search, 'Show in Explorer', many ? null : () => model.shell.reveal(e.path)),
      null,
      (Icons.copy, 'Copy${many ? ' ${sel.length} items' : ''}', () => copy(items: sel)),
      (Icons.content_cut, 'Cut${many ? ' ${sel.length} items' : ''}', () => cut(items: sel)),
      if (e.isDir) (Icons.content_paste, 'Paste into this folder', model.clip.isEmpty ? null : () => paste(e.path)),
      (Icons.edit, 'Rename  (F2)', many ? null : () => rename(e)),
      (Icons.delete_outline, 'Delete${many ? ' ${sel.length} items' : ''}  (Del)', () => delete(sel)),
      null,
      (
        Icons.content_copy,
        'Copy the path',
        () => copyText(many ? sel.map((x) => x.path).join('\r\n') : e.path, 'path copied'),
      ),
      (
        Icons.short_text,
        'Copy the name',
        () => copyText(many ? sel.map((x) => x.name).join('\r\n') : e.name, 'name copied'),
      ),
      if (e.isDir)
        (
          model.isPinned(e.path) ? Icons.star : Icons.star_border,
          model.isPinned(e.path) ? 'Unpin' : 'Pin for quick access',
          many ? null : () => model.togglePin(e.path),
        ),
      (Icons.info_outline, 'Properties', many ? null : () => props(e)),
    ]);
  }
}
