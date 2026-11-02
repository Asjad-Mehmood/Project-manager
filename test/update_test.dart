import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_folder_manager/src/brand.dart';
import 'package:project_folder_manager/src/update/update_check.dart';

void main() {
  test('latest.json is read, and anything else is not', () {
    final h = 'a' * 64;
    final i = UpdateInfo.parse('{"version":"7.0.1","sha256":"${h.toUpperCase()}"}')!;
    expect(i.version, '7.0.1');
    expect(i.sha256, h);
    for (final bad in [
      '',
      'nonsense',
      '[]',
      '{"version":"7.0","sha256":"$h"}',
      '{"version":"7.0.1","sha256":"abc"}',
      '{"version":7,"sha256":"$h"}',
    ]) {
      expect(UpdateInfo.parse(bad), isNull, reason: bad);
    }
  });

  test('versions compare by number, not by text', () {
    expect(isNewer('7.0.1', '7.0.0'), isTrue);
    expect(isNewer('7.2.10', '7.2.9'), isTrue);
    expect(isNewer('8.0.0', '7.9.9'), isTrue);
    expect(isNewer('7.0.0', '7.0.0'), isFalse);
    expect(isNewer('6.2.0', '7.0.0'), isFalse);
  });

  test('the download must match its SHA-256', () {
    final bytes = [1, 2, 3];
    final sum = sha256.convert(bytes).toString();
    expect(sha256Matches(bytes, sum.toUpperCase()), isTrue);
    expect(sha256Matches([1, 2, 4], sum), isFalse);
  });

  test('the release files are named as the release workflow makes them', () {
    expect(releaseBase, 'https://github.com/Asjad-Mehmood/Project-Folder-Manager/releases/latest/download/');
    expect(installerName, 'ProjectFolderManager-Setup.exe');
    expect(manifestName, 'latest.json');
    expect(RegExp(r'^\d+\.\d+\.\d+$').hasMatch(appVersion), isTrue);
  });
}
