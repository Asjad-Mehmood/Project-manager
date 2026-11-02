// v6.2's small parts: the buttons (plain, lit "on", amber), labels, the dark fields and lists,
// the chips (discipline, "3 sub", file type), the green / red dot and the KPI boxes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/disciplines.dart';
import 'theme.dart';

enum BtnKind { plain, on, amber }

/// .btn, .btn.on and .btn.am, with the glow when the mouse is over them
class Btn extends StatefulWidget {
  const Btn(
    this.label, {
    super.key,
    this.icon,
    this.onTap,
    this.kind = BtnKind.plain,
    this.tip,
    this.small = false,
    this.lit = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final BtnKind kind;
  final String? tip;
  final bool small;

  /// A switch that is on (DEEP, MISSING …): drawn as an "on" button
  final bool lit;

  @override
  State<Btn> createState() => _BtnState();
}

class _BtnState extends State<Btn> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final kind = widget.lit ? BtnKind.on : widget.kind;
    final enabled = widget.onTap != null;
    final hot = enabled && (_hover || _focus);
    Gradient? g;
    Color bg, fg, edge;
    List<BoxShadow>? glow;
    if (hot && kind == BtnKind.amber) {
      bg = C.amber;
      fg = const Color(0xFF241A00);
      edge = C.amberHi;
      glow = const [BoxShadow(color: C.amber, blurRadius: 10)];
    } else if (hot) {
      bg = C.teal;
      fg = C.ink;
      edge = C.tealEdge;
      glow = const [BoxShadow(color: C.teal, blurRadius: 10)];
    } else if (kind == BtnKind.on) {
      bg = C.onTop;
      g = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.onTop, C.onBottom]);
      fg = C.ink;
      edge = C.tealEdge;
    } else {
      bg = C.btnTop;
      g = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [C.btnTop, C.btnBottom],
      );
      fg = kind == BtnKind.amber ? C.amber : C.btnText;
      edge = C.fieldEdge;
    }
    if (!enabled) fg = fg.withValues(alpha: .4);
    final size = widget.small ? 10.0 : 11.0;
    Widget b = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      padding: EdgeInsets.symmetric(horizontal: widget.small ? 8 : 11, vertical: widget.small ? 2 : 4),
      decoration: BoxDecoration(
        color: g == null ? bg : null,
        gradient: g,
        border: Border.all(color: edge),
        borderRadius: BorderRadius.circular(3),
        boxShadow: glow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: size + 3, color: fg),
            if (widget.label.isNotEmpty) const SizedBox(width: 4),
          ],
          if (widget.label.isNotEmpty) Text(widget.label, style: t(size, color: fg, ls: .5, h: 1.25)),
        ],
      ),
    );
    b = FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: b),
    );
    b = Padding(padding: const EdgeInsets.only(left: 5), child: b); // v6.2's margin-left:5px
    final tip = widget.tip;
    return Semantics(
      button: true,
      label: widget.label.isEmpty ? tip : null,
      child: tip == null ? b : Tooltip(message: tip, child: b),
    );
  }
}

/// .lab: the small grey capitals before a field
class Lbl extends StatelessWidget {
  const Lbl(this.text, {super.key, this.right = 7});
  final String text;
  final double right;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(right: right),
    child: Text(text, style: t(10, color: C.label, ls: 1.3)),
  );
}

InputDecoration fieldDecoration({String? hint}) => InputDecoration(
  isDense: true,
  hintText: hint,
  hintStyle: t(12, color: C.muted),
  filled: true,
  fillColor: C.field,
  contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
  enabledBorder: OutlineInputBorder(
    borderSide: const BorderSide(color: C.fieldEdge),
    borderRadius: BorderRadius.circular(3),
  ),
  focusedBorder: OutlineInputBorder(
    borderSide: const BorderSide(color: C.teal),
    borderRadius: BorderRadius.circular(3),
  ),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(3)),
);

/// The dark text box
class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.controller,
    this.width,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.style,
    this.onEscape,
    this.tip,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final double? width;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final TextStyle? style;
  final VoidCallback? onEscape;
  final String? tip;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    Widget f = TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      style: style ?? t(12),
      decoration: fieldDecoration(hint: hint),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
    if (onEscape != null) {
      f = CallbackShortcuts(bindings: {const SingleActivator(LogicalKeyboardKey.escape): onEscape!}, child: f);
    }
    f = SizedBox(width: width, height: 28, child: f);
    return tip == null ? f : Tooltip(message: tip!, child: f);
  }
}

/// The dark drop-down list
class Select<T> extends StatelessWidget {
  const Select({
    super.key,
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
    this.width = 140,
    this.tip,
  });

  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final double width;
  final String? tip;

  @override
  Widget build(BuildContext context) {
    final w = Container(
      width: width,
      height: 28,
      padding: const EdgeInsets.only(left: 7, right: 2),
      decoration: BoxDecoration(
        color: C.field,
        border: Border.all(color: C.fieldEdge),
        borderRadius: BorderRadius.circular(3),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          isDense: true,
          dropdownColor: C.dialog,
          iconEnabledColor: C.label,
          focusColor: Colors.transparent,
          style: t(12),
          items: [
            for (final i in items)
              DropdownMenuItem<T>(
                value: i,
                child: Text(label(i), overflow: TextOverflow.ellipsis, style: t(12)),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
    return tip == null ? w : Tooltip(message: tip!, child: w);
  }
}

/// A KPI box top right: the number and its name
class Kpi extends StatelessWidget {
  const Kpi(this.value, this.label, {super.key, this.color = C.teal, this.glow = const Color(0xFF00CC66)});
  final int value;
  final String label;
  final Color color;
  final Color glow;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 9),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    constraints: const BoxConstraints(minWidth: 86),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [C.kpiTop, C.kpiBottom],
      ),
      border: Border.all(color: C.fieldEdge),
      borderRadius: BorderRadius.circular(4),
      boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2))],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: t(
            20,
            color: color,
            w: FontWeight.bold,
            h: 1.1,
          ).copyWith(shadows: [Shadow(color: glow, blurRadius: 12)]),
        ),
        Text(label, style: t(9, color: C.label, ls: 1.4)),
      ],
    ),
  );
}

/// The discipline chip; clicking it changes the discipline
class DisciplineChip extends StatelessWidget {
  const DisciplineChip(this.discipline, {super.key, this.onTap});
  final String discipline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: onTap == null ? discipline : 'Change the discipline',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: disciplineColor(discipline), borderRadius: BorderRadius.circular(10)),
          child: Text(
            discipline,
            style: t(10, color: C.ink, w: FontWeight.bold, ls: .4),
          ),
        ),
      ),
    ),
  );
}

/// "3 sub"
class SubChip extends StatelessWidget {
  const SubChip(this.count, {super.key});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: C.subBg,
      border: Border.all(color: C.subEdge),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text('$count sub', style: t(10, color: C.teal)),
  );
}

/// The file type chip: "PDF" in red, "DWG" in amber …
class ExtChip extends StatelessWidget {
  const ExtChip(this.fileName, {super.key});
  final String fileName;
  @override
  Widget build(BuildContext context) {
    final c = extColor(extOf(fileName));
    return Container(
      constraints: const BoxConstraints(minWidth: 40),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(color: c ?? C.chipGrey, borderRadius: BorderRadius.circular(3)),
      child: Text(
        extLabel(fileName),
        textAlign: TextAlign.center,
        style: t(9, color: c == null ? C.btnText : C.ink, w: FontWeight.bold, h: 1.5),
      ),
    );
  }
}

/// The folder icon, amber as in v6.2
const folderIcon = Icon(Icons.folder, size: 16, color: C.amber);

/// Green when the folder is on the disk, red when not
class Dot extends StatelessWidget {
  const Dot(this.ok, {super.key});
  final bool ok;
  @override
  Widget build(BuildContext context) {
    final c = ok ? C.green : C.red;
    return Tooltip(
      message: ok ? 'On the disk' : 'Not on the disk',
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: c, blurRadius: 8)],
        ),
      ),
    );
  }
}

/// Tracks the mouse for hover colours
class Hover extends StatefulWidget {
  const Hover({super.key, required this.builder, this.cursor = MouseCursor.defer});
  final Widget Function(BuildContext, bool hover) builder;
  final MouseCursor cursor;
  @override
  State<Hover> createState() => _HoverState();
}

class _HoverState extends State<Hover> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.cursor,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: widget.builder(context, _h),
  );
}

/// One of the six VIEW buttons: a little picture of the layout
class LayoutIcon extends StatelessWidget {
  const LayoutIcon(this.n, {super.key, required this.on, required this.onTap, required this.tip});
  final int n;
  final bool on;
  final VoidCallback onTap;
  final String tip;

  // [left, top, width, height, panel?] inside a 28 × 20 box, as v6.2 drew them
  static const _parts = <List<List<num>>>[
    [
      [3, 3, 22, 14, 0],
    ],
    [
      [3, 3, 14, 14, 0],
      [19, 3, 6, 14, 1],
    ],
    [
      [3, 3, 10, 14, 0],
      [15, 3, 10, 14, 1],
    ],
    [
      [3, 3, 6, 14, 0],
      [11, 3, 14, 14, 1],
    ],
    [
      [3, 3, 22, 6, 0],
      [3, 11, 22, 6, 1],
    ],
    [
      [3, 3, 22, 14, 1],
    ],
  ];

  @override
  Widget build(BuildContext context) => Hover(
    cursor: SystemMouseCursors.click,
    builder: (context, h) => Tooltip(
      message: tip,
      child: Semantics(
        button: true,
        selected: on,
        label: tip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 30,
            height: 22,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: on ? const Color(0xFF0E4F55) : C.btnBottom,
              border: Border.all(color: on || h ? C.tealEdge : C.fieldEdge),
              borderRadius: BorderRadius.circular(3),
              boxShadow: h ? const [BoxShadow(color: C.teal, blurRadius: 8)] : null,
            ),
            child: Stack(
              children: [
                for (final r in _parts[n])
                  Positioned(
                    left: r[0].toDouble(),
                    top: r[1].toDouble(),
                    width: r[2].toDouble(),
                    height: r[3].toDouble(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: r[4] == 1
                            ? (on ? C.amberHi : C.amber)
                            : (on ? const Color(0xFF9FD8D8) : const Color(0xFF4F7A96)),
                        borderRadius: BorderRadius.circular(1),
                      ),
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

/// A button that opens a menu under itself; each item carries what it does
class MenuBtn extends StatelessWidget {
  const MenuBtn(
    this.label, {
    super.key,
    this.icon = Icons.arrow_drop_down,
    required this.items,
    this.tip,
    this.lit = false,
  });
  final String label;
  final IconData icon;
  final List<PopupMenuEntry<VoidCallback>> Function() items;
  final String? tip;
  final bool lit;

  @override
  Widget build(BuildContext context) => Builder(
    builder: (ctx) => Btn(
      label,
      icon: icon,
      tip: tip,
      lit: lit,
      onTap: () async {
        final box = ctx.findRenderObject()! as RenderBox;
        final overlay = Overlay.of(ctx).context.findRenderObject()! as RenderBox;
        final at = box.localToGlobal(Offset(0, box.size.height + 2), ancestor: overlay);
        final f = await showMenu<VoidCallback>(
          context: ctx,
          position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
          items: items(),
        );
        f?.call();
      },
    ),
  );
}

/// One line of a menu
PopupMenuItem<VoidCallback> menuItem(
  String text,
  VoidCallback? onTap, {
  IconData? icon,
  bool checked = false,
  String? sub,
}) => PopupMenuItem<VoidCallback>(
  value: onTap,
  enabled: onTap != null,
  height: sub == null ? 30 : 40,
  child: Row(
    children: [
      SizedBox(width: 22, child: Icon(checked ? Icons.check : icon, size: 15, color: onTap == null ? C.muted : C.teal)),
      const SizedBox(width: 6),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: t(12, color: onTap == null ? C.muted : C.text),
            ),
            if (sub != null)
              Text(
                sub,
                overflow: TextOverflow.ellipsis,
                style: t(10, color: C.muted, m: true),
              ),
          ],
        ),
      ),
    ],
  ),
);

/// A rounded row with a coloured strip down its left side (v6.2's border-left), drawn so that the
/// strip and the rounded corners can differ in colour
class AccentBox extends StatelessWidget {
  const AccentBox({
    super.key,
    required this.accent,
    required this.child,
    this.accentWidth = 4,
    this.edge,
    this.colors,
    this.color,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.radius = 4,
    this.shadow = false,
    this.bottomLine,
  });

  final Color accent;
  final double accentWidth;
  final Widget child;
  final Color? edge;
  final List<Color>? colors;
  final Color? color;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double radius;
  final bool shadow;

  /// A line under the row instead of a frame (the panel's rows)
  final Color? bottomLine;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    decoration: BoxDecoration(
      color: colors == null ? color : null,
      gradient: colors == null
          ? null
          : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors!),
      border: edge != null
          ? Border.all(color: edge!)
          : (bottomLine != null ? Border(bottom: BorderSide(color: bottomLine!)) : null),
      borderRadius: bottomLine != null && edge == null ? null : BorderRadius.circular(radius),
      boxShadow: shadow ? const [BoxShadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1))] : null,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius - 1),
      child: Stack(
        children: [
          Padding(
            padding: padding.add(EdgeInsets.only(left: accentWidth)),
            child: child,
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: accentWidth,
            child: ColoredBox(color: accent),
          ),
        ],
      ),
    ),
  );
}
