// MRZ parsing based on ICAO 9303 (TD3 passport format).

class PassportMrz {
  final String documentCode;
  final String issuingCountry;
  final String surnames;
  final String givenNames;
  final String passportNumber;
  final String nationality;
  final DateParts? dateOfBirth;
  final String sex;
  final DateParts? dateOfExpiry;
  final String personalNumber;

  /// Raw 2-line MRZ (sanitized to [A-Z0-9<]).
  final String mrzLine1;
  final String mrzLine2;

  /// Whether all check digits validated.
  final bool isValid;

  /// Validation errors (empty when [isValid] is true).
  final List<String> errors;

  const PassportMrz({
    required this.documentCode,
    required this.issuingCountry,
    required this.surnames,
    required this.givenNames,
    required this.passportNumber,
    required this.nationality,
    required this.dateOfBirth,
    required this.sex,
    required this.dateOfExpiry,
    required this.personalNumber,
    required this.mrzLine1,
    required this.mrzLine2,
    required this.isValid,
    required this.errors,
  });

  Map<String, Object?> toMap() => <String, Object?>{
        'documentCode': documentCode,
        'issuingCountry': issuingCountry,
        'surnames': surnames,
        'givenNames': givenNames,
        'passportNumber': passportNumber,
        'nationality': nationality,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'sex': sex,
        'dateOfExpiry': dateOfExpiry?.toIso8601String(),
        'personalNumber': personalNumber,
        'mrzLine1': mrzLine1,
        'mrzLine2': mrzLine2,
        'isValid': isValid,
        'errors': errors,
      };
}

class DateParts {
  final int year;
  final int month;
  final int day;

  const DateParts(this.year, this.month, this.day);

  String toIso8601String() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class MrzParseResult {
  final PassportMrz? mrz;
  final List<String> errors;

  const MrzParseResult({required this.mrz, required this.errors});
}

class MrzParser {
  /// Extract the best TD3 (passport) MRZ from text lines.
  /// Returns a 2-line tuple or null.
  static ({String line1, String line2})? extractTd3Lines(Iterable<String> lines) {
    final sanitized = <String>[];
    for (final raw in lines) {
      final s = _sanitizeMrzLine(raw);
      if (s.isEmpty) continue;
      // Keep shorter fragments too; MRZ often gets split.
      if (s.length >= 18) sanitized.add(s);
    }

    // 1) Try exact-ish pairs first.
    ({String line1, String line2, int score})? best;
    for (var i = 0; i < sanitized.length; i++) {
      for (var j = i + 1; j < sanitized.length; j++) {
        final l1 = _padOrTrim(sanitized[i], 44);
        final l2 = _padOrTrim(sanitized[j], 44);
        if (!_looksLikeTd3(l1, l2)) continue;
        final score = _scoreTd3(l1) + _scoreTd3(l2);
        if (best == null || score > best.score) best = (line1: l1, line2: l2, score: score);
        break;
      }
    }
    if (best != null) return (line1: best.line1, line2: best.line2);

    // 2) Try reconstructing 44-char lines by concatenating adjacent fragments.
    ({String line1, String line2, int score})? bestRebuilt;
    for (var i = 0; i < sanitized.length; i++) {
      final l1 = _buildFixedLengthFromFragments(sanitized, start: i, length: 44, maxFragments: 4);
      if (l1 == null) continue;
      for (var j = i + 1; j < sanitized.length; j++) {
        final l2 = _buildFixedLengthFromFragments(sanitized, start: j, length: 44, maxFragments: 4);
        if (l2 == null) continue;
        if (!_looksLikeTd3(l1, l2)) continue;
        final score = _scoreTd3(l1) + _scoreTd3(l2);
        if (bestRebuilt == null || score > bestRebuilt.score) {
          bestRebuilt = (line1: l1, line2: l2, score: score);
        }
        break;
      }
    }
    if (bestRebuilt != null) return (line1: bestRebuilt.line1, line2: bestRebuilt.line2);

    // 3) As a last resort, search within the full text stream for 2x44 chars.
    final joined = sanitized.join('<');
    if (joined.length >= 88) {
      for (var i = 0; i <= joined.length - 88; i++) {
        final segment = joined.substring(i, i + 88);
        final l1 = segment.substring(0, 44);
        final l2 = segment.substring(44, 88);
        if (_looksLikeTd3(l1, l2)) return (line1: l1, line2: l2);
      }
    }

    return null;
  }

  static MrzParseResult parseTd3(String mrzLine1, String mrzLine2, {DateTime? now}) {
    final errors = <String>[];
    final l1 = _padOrTrim(_sanitizeMrzLine(mrzLine1), 44);
    var l2 = _padOrTrim(_sanitizeMrzLine(mrzLine2), 44);

    if (!_looksLikeTd3(l1, l2)) {
      return MrzParseResult(mrz: null, errors: ['MRZ does not look like TD3 passport format']);
    }

    // Some OCR engines confuse O/I with 0/1 in numeric-only fields.
    l2 = _fixNumericFieldsInLine2(l2);

    final documentCode = l1.substring(0, 2);
    final issuingCountry = l1.substring(2, 5).replaceAll('<', '');

    final namesField = l1.substring(5);
    final nameParts = namesField.split('<<');
    final surnames = (nameParts.isNotEmpty ? nameParts[0] : '').replaceAll('<', ' ').trim();
    final givenNames = (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '').replaceAll('<', ' ').trim();

    final passportNumber = l2.substring(0, 9).replaceAll('<', '').trim();
    final passportNumberCd = l2.substring(9, 10);
    final nationality = l2.substring(10, 13).replaceAll('<', '');

    final dobRaw = l2.substring(13, 19);
    final dobCd = l2.substring(19, 20);
    final sex = l2.substring(20, 21).replaceAll('<', '');
    final expRaw = l2.substring(21, 27);
    final expCd = l2.substring(27, 28);

    final personalNumber = l2.substring(28, 42).replaceAll('<', '').trim();
    final personalNumberCd = l2.substring(42, 43);
    final compositeCd = l2.substring(43, 44);

    // Check digits.
    final pnOk = _checkDigit(l2.substring(0, 9)) == passportNumberCd;
    if (!pnOk) errors.add('Passport number check digit mismatch');

    final dobOk = _checkDigit(dobRaw) == dobCd;
    if (!dobOk) errors.add('Date of birth check digit mismatch');

    final expOk = _checkDigit(expRaw) == expCd;
    if (!expOk) errors.add('Date of expiry check digit mismatch');

    final pnField = l2.substring(0, 10);
    final dobField = l2.substring(13, 20);
    final expField = l2.substring(21, 28);
    final optField = l2.substring(28, 43);
    final compositeData = pnField + dobField + expField + optField;
    final compOk = _checkDigit(compositeData) == compositeCd;
    if (!compOk) errors.add('Composite check digit mismatch');

    final optOk = _checkDigit(l2.substring(28, 42)) == personalNumberCd;
    // Optional data can be blank; only treat mismatch as error if it is non-empty.
    if (!optOk && l2.substring(28, 42).contains(RegExp(r'[A-Z0-9]'))) {
      errors.add('Personal number check digit mismatch');
    }

    final dateOfBirth = _parseMrzDate(dobRaw, now: now, isExpiry: false);
    final dateOfExpiry = _parseMrzDate(expRaw, now: now, isExpiry: true);

    final mrz = PassportMrz(
      documentCode: documentCode,
      issuingCountry: issuingCountry,
      surnames: surnames,
      givenNames: givenNames,
      passportNumber: passportNumber,
      nationality: nationality,
      dateOfBirth: dateOfBirth,
      sex: sex,
      dateOfExpiry: dateOfExpiry,
      personalNumber: personalNumber,
      mrzLine1: l1,
      mrzLine2: l2,
      isValid: errors.isEmpty,
      errors: List.unmodifiable(errors),
    );

    return MrzParseResult(mrz: mrz, errors: List.unmodifiable(errors));
  }

  static String _sanitizeMrzLine(String raw) {
    final upper = raw.toUpperCase();
    final buf = StringBuffer();
    for (final codeUnit in upper.codeUnits) {
      var ch = String.fromCharCode(codeUnit);
      // Common OCR variants of the filler char.
      if (ch == '«' || ch == '‹' || ch == '›' || ch == '⟨' || ch == '⟩' || ch == '＜' || ch == '>' || ch == '_') {
        ch = '<';
      }
      if (RegExp(r'[A-Z0-9<]').hasMatch(ch)) buf.write(ch);
    }
    return buf.toString();
  }

  static String? _buildFixedLengthFromFragments(List<String> fragments, {required int start, required int length, required int maxFragments}) {
    if (start < 0 || start >= fragments.length) return null;
    final buf = StringBuffer();
    var used = 0;
    for (var i = start; i < fragments.length && used < maxFragments && buf.length < length; i++) {
      buf.write(fragments[i]);
      used++;
      if (buf.length >= length) break;
    }
    final s = buf.toString();
    if (s.length < length) return null;
    return s.substring(0, length);
  }

  static String _padOrTrim(String s, int len) {
    if (s.length == len) return s;
    if (s.length > len) return s.substring(0, len);
    return s.padRight(len, '<');
  }

  static bool _looksLikeTd3(String l1, String l2) {
    if (l1.length != 44 || l2.length != 44) return false;

    // TD3 passport MRZ line 1 starts with "P<" (document code + filler).
    // Requiring the '<' prevents false positives like "PASSEPORT ORDINAIRE".
    if (!l1.startsWith('P<')) return false;

    // Issuing country should be 3 letters.
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(l1.substring(2, 5))) return false;

    // Reject very short OCR fragments padded with '<' (another common source of
    // false positives).
    final core1 = l1.replaceAll(RegExp(r'<+$'), '');
    final core2 = l2.replaceAll(RegExp(r'<+$'), '');
    if (core1.length < 30 || core2.length < 30) return false;

    // MRZ line 1 should contain multiple filler chars inside the line, not just
    // trailing padding.
    final coreLt1 = '<'.allMatches(core1).length;
    if (coreLt1 < 3) return false;

    if (l2.substring(13, 19).contains(RegExp(r'[^0-9]'))) return false;
    if (l2.substring(21, 27).contains(RegExp(r'[^0-9]'))) return false;
    return true;
  }

  static int _scoreTd3(String l) {
    // Score based on the non-padding portion to avoid bias toward short strings
    // that were padded with many '<' characters.
    final core = l.replaceAll(RegExp(r'<+$'), '');
    final lt = '<'.allMatches(core).length;
    final lenScore = core.length; // prefer fuller lines
    return lt * 2 + lenScore;
  }

  static String _checkDigit(String input) {
    const weights = [7, 3, 1];
    var sum = 0;
    for (var i = 0; i < input.length; i++) {
      final v = _mrzValue(input.codeUnitAt(i));
      sum += v * weights[i % 3];
    }
    return (sum % 10).toString();
  }

  static int _mrzValue(int codeUnit) {
    final ch = String.fromCharCode(codeUnit);
    if (ch == '<') return 0;
    final d = int.tryParse(ch);
    if (d != null) return d;
    final c = ch.codeUnitAt(0);
    if (c >= 65 && c <= 90) return c - 55; // A=10
    return 0;
  }

  static String _fixNumericFieldsInLine2(String l2) {
    final chars = l2.split('');
    void fixRange(int start, int endExclusive) {
      for (var i = start; i < endExclusive; i++) {
        chars[i] = chars[i].replaceAll('O', '0').replaceAll('I', '1');
        // Some OCR engines output lowercase.
        chars[i] = chars[i].toUpperCase();
      }
    }

    // Dates + check digits are numeric.
    fixRange(9, 10);
    fixRange(13, 20);
    fixRange(21, 28);
    fixRange(42, 44);
    return chars.join();
  }

  static DateParts? _parseMrzDate(String yymmdd, {DateTime? now, required bool isExpiry}) {
    if (!RegExp(r'^\d{6}$').hasMatch(yymmdd)) return null;
    final yy = int.parse(yymmdd.substring(0, 2));
    final mm = int.parse(yymmdd.substring(2, 4));
    final dd = int.parse(yymmdd.substring(4, 6));
    if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;

    final ref = now ?? DateTime.now();
    final currentYY = ref.year % 100;

    // Heuristic century resolution.
    int year;
    if (isExpiry) {
      // Expiry typically in near future.
      year = 2000 + yy;
      if (year < ref.year - 10) year += 100;
    } else {
      // Birth typically in past.
      year = (yy > currentYY) ? (1900 + yy) : (2000 + yy);
    }
    return DateParts(year, mm, dd);
  }
}
