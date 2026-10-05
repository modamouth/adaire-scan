import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_id_scanner/src/id_text_parser.dart';

void main() {
  test('parses labeled fields on same line', () {
    final data = IdTextParser.parse(<String>[
      'ID NO: 1234567890',
      'SURNAME: SMITH',
      'FIRST NAMES: JOHN MICHAEL',
      'DATE OF BIRTH: 1990-01-02',
      'CITIZENSHIP: USA',
      'PLACE OF BIRTH: NEW YORK',
      'SEX: M',
      'HEIGHT: 1.75 m',
      'DATE OF ISSUE: 2020/12/31',
    ]);

    expect(data.idNumber, '1234567890');
    expect(data.surname, 'SMITH');
    expect(data.firstNames, 'JOHN MICHAEL');
    expect(data.dateOfBirth, isNotNull);
    expect(data.dateOfBirth!.raw, '1990-01-02');
    expect(data.citizenship, 'USA');
    expect(data.placeOfBirth, 'NEW YORK');
    expect(data.gender, 'M');
    expect(data.heightMeters, closeTo(1.75, 0.0001));
    expect(data.dateOfIssue, isNotNull);
    expect(data.dateOfIssue!.raw, '2020/12/31');
  });

  test('parses labeled fields when value is on next line', () {
    final data = IdTextParser.parse(<String>[
      'SURNAME:',
      'Smith',
      'FIRST NAMES(S):',
      'John Michael',
      'DATE OF BIRTH:',
      '02/01/1990',
      'CITIZENSHIP:',
      'USA',
      'PLACE OF BIRTH:',
      'New York',
      'GENDER:',
      'Male',
      'HEIGHT:',
      '175 cm',
      'DATE OF ISSUE:',
      '31-12-2020',
      'ID NUMBER:',
      '1234567890',
    ]);

    expect(data.idNumber, '1234567890');
    expect(data.surname, 'Smith');
    expect(data.firstNames, 'John Michael');
    expect(data.dateOfBirth, isNotNull);
    expect(data.dateOfBirth!.raw, '02/01/1990');
    expect(data.citizenship, 'USA');
    expect(data.placeOfBirth, 'New York');
    expect(data.gender, 'M');
    expect(data.heightMeters, closeTo(1.75, 0.0001));
    expect(data.dateOfIssue, isNotNull);
    expect(data.dateOfIssue!.raw, '31-12-2020');
  });

  test('normalizes OCR digit confusions in dates', () {
    final data = IdTextParser.parse(<String>[
      'DATE OF BIRTH:',
      '2ooL-01-02',
      'DATE OF ISSUE:',
      '2O2O-12-31',
    ]);

    expect(data.dateOfBirth?.value, DateTime(2001, 1, 2));
    expect(data.dateOfIssue?.value, DateTime(2020, 12, 31));
  });

  test('Namibia layout: skips dangling "S" after First Name(s)', () {
    final data = IdTextParser.parse(<String>[
      'SURNAME',
      'David',
      'FIRST NAME(S)',
      'S',
      'Apollos Ndinomwaami',
      'PLACE/COUNTRY OF BIRTH',
      'Eenhana',
      'HEIGHT',
      '1.65',
    ]);

    expect(data.surname, 'David');
    expect(data.firstNames, 'Apollos Ndinomwaami');
    expect(data.placeOfBirth, 'Eenhana');
    expect(data.heightMeters, closeTo(1.65, 0.0001));
  });
}
