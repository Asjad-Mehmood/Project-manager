// The self-update's rules, kept apart from Windows so they can be tested: reading latest.json,
// comparing versions and checking the download's SHA-256 (the same as Slope Calculator's).
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Where installed copies look: the newest release of the public repository
const releaseBase = 'https://github.com/Asjad-Mehmood/Project-manager/releases/latest/download/';
const manifestName = 'latest.json';
const installerName = 'ProjectFolderManager-Setup.exe';

class UpdateInfo {
  const UpdateInfo(this.version, this.sha256);
  final String version;
  final String sha256;

  /// latest.json: {"version":"7.0.1","sha256":"…64 hex…"}; null when it isn't one
  static UpdateInfo? parse(String text) {
    try {
      final j = jsonDecode(text);
      if (j is! Map) return null;
      final v = j['version'], h = j['sha256'];
      if (v is! String || h is! String) return null;
      if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(v) || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(h)) return null;
      return UpdateInfo(v, h.toLowerCase());
    } on FormatException {
      return null;
    }
  }
}

/// True when [candidate] (7.2.10) is a higher version than [current] (7.2.9)
bool isNewer(String candidate, String current) {
  List<int> parts(String v) => [for (final p in v.split('.')) int.tryParse(p) ?? 0];
  final a = parts(candidate), b = parts(current);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

bool sha256Matches(List<int> bytes, String expected) => sha256.convert(bytes).toString() == expected.toLowerCase();
