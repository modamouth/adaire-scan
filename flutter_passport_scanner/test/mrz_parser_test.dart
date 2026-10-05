import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_passport_scanner/flutter_passport_scanner.dart';

void main() {
  group('MrzParser.extractTd3Lines', () {
    test('does not treat "PASSEPORT ORDINAIRE" as MRZ line 1', () {
      // Real MRZ line 2 (example-like) but missing line 1.
      const mrzLine2 = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';

      final extracted = MrzParser.extractTd3Lines([
        'PASSEPORT ORDINAIRE',
        mrzLine2,
      ]);

      expect(extracted, isNull);
    });

    test('extracts TD3 lines when present', () {
      const mrzLine1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const mrzLine2 = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';

      final extracted = MrzParser.extractTd3Lines([
        'Some header text',
        mrzLine1,
        mrzLine2,
      ]);

      expect(extracted, isNotNull);
      expect(extracted!.line1, hasLength(44));
      expect(extracted.line2, hasLength(44));

      final parsed = MrzParser.parseTd3(extracted.line1, extracted.line2);
      expect(parsed.mrz, isNotNull);
      expect(parsed.mrz!.givenNames, contains('ANNA'));
      expect(parsed.mrz!.surnames, contains('ERIKSSON'));
    });
  });
}
