import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('versioned physical-test fixtures are synthetic and complete', () {
    final manifestFile = File('test/fixtures/v1/manifest.json');
    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    final fixtures = manifest['fixtures'] as List<dynamic>;

    expect(manifest['version'], 1);
    expect(manifest['synthetic_only'], isTrue);
    expect(
      fixtures.map((fixture) => (fixture as Map<String, dynamic>)['format']),
      containsAll(<String>['qr', 'ean13', 'code128']),
    );

    for (final value in fixtures) {
      final fixture = value as Map<String, dynamic>;
      expect(fixture['id'], isNotEmpty);
      expect(fixture['expected_value'], isNotEmpty);
      expect(fixture['sha256'], hasLength(64));
      expect(File('test/fixtures/v1/${fixture['file']}').existsSync(), isTrue);
    }
  });
}
