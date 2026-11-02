// The DRIVES strip, the status line at the bottom with its thin index bar, and the bar that
// shows a copy or move going on, with CANCEL.
import 'package:flutter/material.dart';

import '../brand.dart';
import '../core/format.dart';
import '../platform/shell.dart';
import '../state/app_model.dart';
import 'commands.dart';
import 'theme.dart';
import 'widgets.dart';

class DrivesStrip extends StatelessWidget {
  const DrivesStrip({super.key, required this.model, required this.cmd});
  final AppModel model;
  final Commands cmd;

  @override
  Widget build(BuildContext context) {
    final drives = model.drives;
    final rootLetter = model.root.isEmpty ? '' : model.root[0].toUpperCase();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 7, 18, 8),
      decoration: const BoxDecoration(
        color: C.driveStrip,
        border: Border(bottom: BorderSide(color: C.driveStripEdge)),
      ),
      child: drives.isEmpty
          ? const Lbl('no drives could be read on this PC')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [for (final d in drives) _tile(d, d.letter == rootLetter)]),
            ),
    );
  }

  Widget _tile(DriveInfo d, bool isRoot) {
    final name = d.label.isNotEmpty ? d.label : d.type;
    final pct = d.usedPercent;
    final bar = pct >= 90 ? C.barHot : (pct >= 75 ? C.barMid : C.barOk);
    return Opacity(
      opacity: d.ready ? 1 : .45,
      child: Hover(
        cursor: d.ready ? SystemMouseCursors.click : SystemMouseCursors.basic,
        builder: (context, h) => Tooltip(
          message: d.ready ? 'Open ${d.root} in the panel' : 'No media in this drive',
          child: GestureDetector(
            onTap: d.ready ? () => cmd.view(d.root) : null,
            child: Container(
              width: 188,
              margin: const EdgeInsets.only(right: 9),
              padding: const EdgeInsets.fromLTRB(9, 6, 9, 7),
              decoration: BoxDecoration(
                gradient: h && d.ready
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [C.driveTop, C.driveBottom],
                      ),
                color: h && d.ready ? const Color(0xFF163049) : null,
                border: Border.all(color: h && d.ready ? const Color(0xFF2F7F8F) : C.driveEdge),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${d.letter}:',
                        style: t(12, color: C.tealHi, w: FontWeight.bold, m: true),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t(12, color: C.title, w: FontWeight.bold),
                        ),
                      ),
                      if (isRoot)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.star, size: 12, color: C.gold),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.ready
                        ? '${driveSize(d.free)} free of ${driveSize(d.total)}  ·  $pct% used'
                        : '${d.type}  ·  not ready',
                    style: t(9, color: C.label, ls: .3),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: C.barTrack,
                      border: Border.all(color: C.driveEdge),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: d.ready ? pct / 100 : 0,
                      child: Container(color: bar),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.model, required this.width});
  final AppModel model;
  final double width;

  @override
  Widget build(BuildContext context) {
    final idx = model.index;
    final pg = model.progress;
    String right;
    if (model.indexing && pg != null) {
      right = 'indexing ${pg.percent}%';
    } else if (idx.isEmpty) {
      right = 'no index yet';
    } else {
      right = 'index ${idx.length} items${idx.built == null ? '' : ', ${ago(idx.built!, model.now())}'}';
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 2,
          child: pg == null
              ? null
              : Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: pg.percent / 100,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: C.teal,
                        boxShadow: [BoxShadow(color: C.teal, blurRadius: 10)],
                      ),
                    ),
                  ),
                ),
        ),
        Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: const BoxDecoration(
            color: C.status,
            border: Border(top: BorderSide(color: C.barEdge)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  model.status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t(11, color: C.label),
                ),
              ),
              if (width >= 700) Text(right, style: t(10, color: C.faint, ls: 1)),
              if (width >= 900) ...[
                const SizedBox(width: 18),
                Text('$appName v$appVersion  ·  Excel to KML', style: t(10, color: C.faint, ls: 1)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "Copying 3 of 10 · name" with CANCEL, over the bottom of the window
class OpBar extends StatelessWidget {
  const OpBar({super.key, required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final op = model.op!;
    final verb = model.clipCut ? 'Moving' : 'Copying';
    return Material(
      color: C.clip,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: C.teal)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: C.teal)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                op.count == 0
                    ? 'working ...'
                    : '$verb ${op.index} of ${op.count}  ·  ${op.name}${op.files > 0 ? '  ·  ${plural(op.files, 'file')}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t(12),
              ),
            ),
            Btn('CANCEL', icon: Icons.close, onTap: model.cancelOp),
          ],
        ),
      ),
    );
  }
}
