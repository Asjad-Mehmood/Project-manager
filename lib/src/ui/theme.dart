// v6.2's colours, fonts and sizes, taken from its stylesheet, so v7 looks the same.
import 'package:flutter/material.dart';

abstract final class C {
  static const bg = Color(0xFF081321);
  static const text = Color(0xFFDBE7F0);
  static const white = Color(0xFFFFFFFF);
  static const teal = Color(0xFF13A8A8);
  static const tealHi = Color(0xFF4FE3E3);
  static const tealEdge = Color(0xFF3FE0E0);
  static const amber = Color(0xFFF5A524);
  static const amberHi = Color(0xFFFFC860);
  static const gold = Color(0xFFD99A2B);
  static const red = Color(0xFFE8734A);
  static const green = Color(0xFF5CB85C);
  static const ink = Color(0xFF04121E); // text on a bright button
  static const label = Color(0xFF7D95A8);
  static const muted = Color(0xFF5F7D95);
  static const soft = Color(0xFF9FB6C7);
  static const softer = Color(0xFF9FB6C8);
  static const faint = Color(0xFF4A6A84);
  static const title = Color(0xFFEAF2F8);
  static const subtitle = Color(0xFF6F9FB0);

  static const headerTop = Color(0xFF14283C);
  static const headerBottom = Color(0xFF0A1726);
  static const headerEdge = Color(0xFF1D5C5C);
  static const barTop = Color(0xFF0C1E30);
  static const barBottom = Color(0xFF091827);
  static const barEdge = Color(0xFF16334C);
  static const field = Color(0xFF050F1A);
  static const fieldEdge = Color(0xFF1E4460);
  static const btnTop = Color(0xFF14304A);
  static const btnBottom = Color(0xFF0D2135);
  static const btnText = Color(0xFFCFE0EC);
  static const onTop = Color(0xFF19C6C6);
  static const onBottom = Color(0xFF0E8B8B);

  static const rowTop = Color(0xFF14293D);
  static const rowBottom = Color(0xFF0F2133);
  static const rowEdge = Color(0xFF17344C);
  static const rowHoverTop = Color(0xFF183049);
  static const rowHoverBottom = Color(0xFF122436);
  static const rowHoverEdge = Color(0xFF2A5F6B);
  static const kidTop = Color(0xFF102336);
  static const kidBottom = Color(0xFF0C1B2B);
  static const subBg = Color(0xFF0B3A42);
  static const subEdge = Color(0xFF14565F);

  static const panelTop = Color(0xFF0A1928);
  static const panelBottom = Color(0xFF070F19);
  static const panelHeadTop = Color(0xFF12304A);
  static const panelHeadBottom = Color(0xFF0B1B2D);
  static const tools = Color(0xFF09182A);
  static const tools2 = Color(0xFF0A1B2C);
  static const toolsEdge = Color(0xFF12283C);
  static const vrowEdge = Color(0xFF102132);
  static const vrowHover = Color(0xFF142837);
  static const vrowHoverEdge = Color(0xFF2F7F8F);
  static const selected = Color(0xFF16344A);
  static const goBg = Color(0xFF123A3A);
  static const goEdge = Color(0xFF1D5C5C);
  static const clip = Color(0xFF0C2033);
  static const status = Color(0xFF0B1B2D);
  static const dialog = Color(0xFF0C1E30);

  static const driveTop = Color(0xFF13293F);
  static const driveBottom = Color(0xFF0D1E30);
  static const driveEdge = Color(0xFF1B3D57);
  static const driveStrip = Color(0xFF09182A);
  static const driveStripEdge = Color(0xFF13283C);
  static const barTrack = Color(0xFF0A1826);
  static const barOk = Color(0xFF2F8F7F);
  static const barMid = Color(0xFFC9A227);
  static const barHot = Color(0xFFC0603C);

  static const kpiTop = Color(0xFF12304A);
  static const kpiBottom = Color(0xFF0A1A2B);
  static const chipGrey = Color(0xFF3A4A58);
}

const sans = 'Segoe UI';
const sansFallback = ['Tahoma', 'Arial', 'sans-serif'];
const mono = 'Consolas';
const monoFallback = ['Courier New', 'monospace'];

TextStyle t(double size, {Color color = C.text, FontWeight? w, double? ls, bool m = false, double? h}) => TextStyle(
  fontFamily: m ? mono : sans,
  fontFamilyFallback: m ? monoFallback : sansFallback,
  fontSize: size,
  color: color,
  fontWeight: w,
  letterSpacing: ls,
  height: h,
);

ThemeData pfmTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    fontFamily: sans,
    fontFamilyFallback: sansFallback,
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.dark(
      primary: C.teal,
      secondary: C.amber,
      surface: C.dialog,
      onSurface: C.text,
      error: C.red,
    ),
    visualDensity: VisualDensity.compact,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    useMaterial3: true,
  );
  return base.copyWith(
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: C.teal,
      selectionColor: Color(0x8013A8A8),
      selectionHandleColor: C.teal,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF0C2033),
        border: Border.all(color: C.fieldEdge),
        borderRadius: BorderRadius.circular(3),
      ),
      textStyle: t(11, color: C.text),
      waitDuration: const Duration(milliseconds: 500),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: C.dialog,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: C.fieldEdge),
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: t(12),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(const Color(0xFF1E4460)),
      thickness: WidgetStateProperty.all(8),
      radius: const Radius.circular(4),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.clip,
      contentTextStyle: t(12),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: C.teal),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.dialog,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: C.teal, width: 2),
        borderRadius: BorderRadius.circular(5),
      ),
    ),
  );
}
