import 'id_scan.dart';

class IdTextParser {
  static IdCardData parse(List<String> lines) {
    final normalized = lines
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList(growable: false);

    String? idNumber;
    String? surname;
    String? firstNames;
    ParsedDate? dob;
    String? citizenship;
    String? placeOfBirth;
    String? gender;
    double? heightMeters;
    ParsedDate? dateOfIssue;

    String normalizeLabelLine(String line) {
      return line
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z\s]'), ' ')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
    }

    bool looksLikeAnotherLabel(String line) {
      final t = line.trim().toLowerCase();
      if (t.isEmpty) return false;
      if (t.endsWith(':')) return true;
      // Common Namibian ID label words.
      const labelTokens = <String>[
        'surname',
        'first names',
        'first name',
        'given names',
        'date of birth',
        'place of birth',
        'country of birth',
        'gender',
        'sex',
        'date of issue',
        'issue date',
        'issued',
        'height',
        'citizenship',
        'nationality',
        'id no',
        'id number',
        'identity number',
      ];
      for (final token in labelTokens) {
        if (t == token) return true;
        if (t.startsWith('$token:')) return true;
        if (t == '$token(s)' || t.startsWith('$token(s):')) return true;
      }
      return false;
    }

    bool isBadNameValue(String? v) {
      if (v == null) return true;
      final t = normalizeLabelLine(v);
      if (t.isEmpty) return true;
      if (t == 's') return true;
      if (looksLikeAnotherLabel(v)) return true;
      // Reject values that are too short to be real names.
      if (t.length < 2) return true;
      return false;
    }

    String? valueAfterLabelTokens(
      List<String> tokens, {
      bool Function(String value)? isSkippableValue,
    }) {
      for (var i = 0; i < normalized.length; i++) {
        final t = normalizeLabelLine(normalized[i]);
        if (t.isEmpty) continue;
        final isMatch = tokens.any(
          (tok) => t == tok || t.startsWith('$tok ') || t.contains(tok),
        );
        if (!isMatch) continue;

        for (var j = i + 1; j < normalized.length; j++) {
          final v = normalized[j].trim();
          if (v.isEmpty) continue;
          if (looksLikeAnotherLabel(v)) break;
          if (isSkippableValue != null && isSkippableValue(v)) continue;
          return v;
        }
      }
      return null;
    }

    // Sequential/ordered extraction: find label starting at [startAt], then take
    // next non-label line as the value. Returns (value, valueIndex).
    (String?, int?) valueAfterLabelTokensFromIndex(
      int startAt,
      List<String> tokens, {
      bool Function(String value)? isSkippableValue,
    }) {
      for (var i = startAt; i < normalized.length; i++) {
        final t = normalizeLabelLine(normalized[i]);
        if (t.isEmpty) continue;
        final isMatch = tokens.any(
          (tok) => t == tok || t.startsWith('$tok ') || t.contains(tok),
        );
        if (!isMatch) continue;

        for (var j = i + 1; j < normalized.length; j++) {
          final v = normalized[j].trim();
          if (v.isEmpty) continue;
          if (looksLikeAnotherLabel(v)) break;
          if (isSkippableValue != null && isSkippableValue(v)) continue;
          return (v, j);
        }
      }
      return (null, null);
    }

    String? findLabeledValue(List<RegExp> labels) {
      for (final line in normalized) {
        for (final label in labels) {
          final m = label.firstMatch(line);
          if (m == null) continue;
          final v = (m.groupCount >= 1 ? m.group(1) : null) ?? '';
          final candidate = v.trim().replaceAll(RegExp(r'^[\s:;.-]+'), '').trim();
          if (candidate.isEmpty) continue;
          // Guard: OCR sometimes produces "First Names Surname" on a single line.
          // In that case the capture group is another label word, not a value.
          if (looksLikeAnotherLabel(candidate)) continue;
          return candidate;
        }
      }

      // Try two-line labels: if a line matches label alone, take next line.
      for (var i = 0; i < normalized.length - 1; i++) {
        final line = normalized[i];
        for (final labelOnly in labels.map(_toLabelOnly).whereType<RegExp>()) {
          if (labelOnly.hasMatch(line)) {
            // Some scans have empty line(s) between label and value.
            for (var j = i + 1; j < normalized.length; j++) {
              final next = normalized[j].trim();
              if (next.isEmpty) continue;
              if (looksLikeAnotherLabel(next)) break;
              return next;
            }
          }
        }
      }

      return null;
    }

    idNumber = findLabeledValue([
      RegExp(r'\bID\s*(?:NO\.?|NUMBER)\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
      RegExp(r'\bIDENTITY\s*(?:NO\.?|NUMBER)\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
      RegExp(r'\bDOCUMENT\s*(?:NO\.?|NUMBER)\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
    ]);

    surname = findLabeledValue([
      RegExp(r'\bSURNAME\b(?:\s*\(S\))?\s*[:\-;]?\s*(.+)$', caseSensitive: false),
      RegExp(r'\bLAST\s*NAME\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
      RegExp(r'\bFAMILY\s*NAME\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
    ]);

    firstNames = findLabeledValue([
      RegExp(
        r'\bFIRST\s*NAME(?:S)?\s*\(\s*S\s*\)\s*[:\-;]?\s*(.+)$',
        caseSensitive: false,
      ),
      RegExp(
        r'\bFIRST\s*NAME(?:S)?\b\s*[:\-;]?\s*(.+)$',
        caseSensitive: false,
      ),
      RegExp(
        r'\bFIRST\s*NAMES?\b(?:\s*\(S\))?\s*[:\-;]?\s*(.+)$',
        caseSensitive: false,
      ),
      RegExp(r'\bGIVEN\s*NAMES?\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
      RegExp(r'\bFORENAMES?\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
      RegExp(r'\bNAME\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
    ]);

    citizenship = findLabeledValue([
      RegExp(r'\bCITIZENSHIP\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
      RegExp(r'\bNATIONALITY\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
    ]);

    placeOfBirth = findLabeledValue([
      RegExp(r'\bPLACE\s*(?:OF)?\s*BIRTH\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
      RegExp(r'\bCOUNTRY\s*(?:OF)?\s*BIRTH\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
    ]);

    final dobRaw = findLabeledValue([
      RegExp(r'\bDATE\s*OF\s*BIRTH\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
      RegExp(r'\bDOB\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
    ]);
    dob = _parseDate(dobRaw);

    final issueRaw = findLabeledValue([
      RegExp(r'\bDATE\s*OF\s*ISSUE\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
      RegExp(r'\bISSUE\s*DATE\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
      RegExp(r'\bISSUED\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
    ]);
    dateOfIssue = _parseDate(issueRaw);

    final sexRaw = findLabeledValue([
      RegExp(r'\bSEX\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
      RegExp(r'\bGENDER\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
    ]);
    gender = _normalizeGender(sexRaw) ?? _inferGenderFromLooseLines(normalized);

    final heightRaw = findLabeledValue([
      RegExp(r'\bHEIGHT\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
      RegExp(r'\bHT\b\s*[:\-;]?\s*(.+)$', caseSensitive: false),
    ]);
    heightMeters = _parseHeightMeters(heightRaw);

    // Namibia-style layout fallback: label on one line, value immediately below.
    // Use this to correct cases where OCR merges two labels into one line.
    bool skipNameNoise(String v) {
      final t = normalizeLabelLine(v);
      // Some IDs show "First Name(s)" then a dangling "S" line before the value.
      if (t == 's') return true;
      if (t == 'name s') return true;
      if (t == 'first name s') return true;
      if (t == 'first names s') return true;
      return false;
    }

    // First try ordered extraction so we respect the card order.
    final (surnameOrdered, surnameValueIndex) = valueAfterLabelTokensFromIndex(
      0,
      ['surname', 'surname s'],
      isSkippableValue: skipNameNoise,
    );
    final (firstNamesOrdered, _) = valueAfterLabelTokensFromIndex(
      (surnameValueIndex ?? 0) + 1,
      [
        'first names',
        'first name',
        'first name s',
        'first names s',
        'given names',
        'forenames',
      ],
      isSkippableValue: skipNameNoise,
    );

    if (isBadNameValue(surname)) surname = surnameOrdered;
    if (isBadNameValue(firstNames)) firstNames = firstNamesOrdered;

    // Also keep the older non-ordered fallback for other fields.
    citizenship ??= valueAfterLabelTokens(['citizenship', 'nationality']);
    placeOfBirth ??= valueAfterLabelTokens([
      'place of birth',
      'country of birth',
      'place country of birth',
    ]);
    dob ??= _parseDate(valueAfterLabelTokens(['date of birth', 'dob']));
    dateOfIssue ??= _parseDate(
      valueAfterLabelTokens(['date of issue', 'issue date', 'issued']),
    );
    gender ??= _normalizeGender(valueAfterLabelTokens(['gender', 'sex']));
    heightMeters ??= _parseHeightMeters(valueAfterLabelTokens(['height', 'ht']));
    idNumber ??= valueAfterLabelTokens([
      'id no',
      'id number',
      'identity number',
      'document number',
    ]);

    // Clean common OCR artifacts for name-ish fields.
    surname = _cleanupNameish(surname);
    firstNames = _cleanupNameish(firstNames);

    // Heuristic: if we didn't get ID number via label, try to find a plausible one.
    idNumber = _pickBestIdNumber(idNumber, normalized);

    // Intelligent inference for Namibia-style IDs.
    gender ??= _inferGenderFromLooseLines(normalized);

    final inferredHeight = heightMeters ?? _inferHeightMetersFromLines(normalized);
    heightMeters = inferredHeight;

    final inferredDates = _inferDobAndIssueFromLines(
      normalized,
      labeledDob: dob,
      labeledIssue: dateOfIssue,
    );
    dob = inferredDates.$1;
    dateOfIssue = inferredDates.$2;

    return IdCardData(
      idNumber: _cleanupIdNumber(idNumber),
      surname: surname,
      firstNames: firstNames,
      dateOfBirth: dob,
      citizenship: citizenship,
      placeOfBirth: placeOfBirth,
      gender: gender,
      heightMeters: heightMeters,
      dateOfIssue: dateOfIssue,
    );
  }

  static RegExp? _toLabelOnly(RegExp withValueCapture) {
    final p = withValueCapture.pattern;
    // Convert patterns ending with (.+)$ into label-only checks.
    // NOTE: we must escape '$' in Dart strings as '\$'.
    const suffix = '(.+)\$'; // literal string "(.+)$"
    if (!p.endsWith(suffix)) return null;

    final prefix = p.substring(0, p.length - suffix.length);
    // Prefix usually already ends with optional separators/whitespace.
    // Add end anchor back.
    final labelOnly = '$prefix\$';
    return RegExp(labelOnly, caseSensitive: withValueCapture.isCaseSensitive);
  }

  static String? _cleanupIdNumber(String? s) {
    if (s == null) return null;
    final cleaned = s
        .replaceAll(RegExp(r'\bID\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bNO\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^0-9A-Z]'), '')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static String? _cleanupNameish(String? s) {
    if (s == null) return null;
    var v = s.trim();
    v = v.replaceAll(RegExp(r"[^A-Z\s\-']", caseSensitive: false), '');
    v = v.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return v.isEmpty ? null : v;
  }

  static ParsedDate? _parseDate(String? raw) {
    if (raw == null) return null;
    final r = raw.trim();
    if (r.isEmpty) return null;

    final working = _normalizeOcrDigits(r);

    // yyyy-mm-dd or yyyy/mm/dd
    final iso = RegExp(r'\b(\d{4})[\-/\.](\d{1,2})[\-/\.](\d{1,2})\b');
    final isoM = iso.firstMatch(working);
    if (isoM != null) {
      final y = int.tryParse(isoM.group(1) ?? '');
      final m = int.tryParse(isoM.group(2) ?? '');
      final d = int.tryParse(isoM.group(3) ?? '');
      final dt = _safeDate(y, m, d);
      return ParsedDate(value: dt, raw: r);
    }

    // dd-mm-yyyy or dd/mm/yyyy
    final dmy = RegExp(r'\b(\d{1,2})[\-/\.](\d{1,2})[\-/\.](\d{2,4})\b');
    final dmyM = dmy.firstMatch(working);
    if (dmyM != null) {
      final d = int.tryParse(dmyM.group(1) ?? '');
      final m = int.tryParse(dmyM.group(2) ?? '');
      var y = int.tryParse(dmyM.group(3) ?? '');
      if (y != null && y < 100) {
        // Guess century.
        y += (y <= 30) ? 2000 : 1900;
      }
      final dt = _safeDate(y, m, d);
      return ParsedDate(value: dt, raw: r);
    }

    // Compact dates: yyyymmdd or ddmmyyyy
    final compact = RegExp(r'\b(\d{8})\b');
    final c = compact.firstMatch(working);
    if (c != null) {
      final digits = c.group(1) ?? '';
      if (digits.length == 8) {
        final a = int.tryParse(digits.substring(0, 4));
        if (a != null && a >= 1900 && a <= 2099) {
          final y = a;
          final m = int.tryParse(digits.substring(4, 6));
          final d = int.tryParse(digits.substring(6, 8));
          return ParsedDate(value: _safeDate(y, m, d), raw: r);
        }

        final d = int.tryParse(digits.substring(0, 2));
        final m = int.tryParse(digits.substring(2, 4));
        final y = int.tryParse(digits.substring(4, 8));
        return ParsedDate(value: _safeDate(y, m, d), raw: r);
      }
    }

    return ParsedDate(value: null, raw: r);
  }

  static String _normalizeOcrDigits(String input) {
    // Fix common OCR confusions in numeric fields.
    final upper = input.toUpperCase();
    return upper
        .replaceAll(RegExp(r'[OØ]'), '0')
        .replaceAll(RegExp(r'[IL\|]'), '1')
        .replaceAll('S', '5')
        .replaceAll('B', '8')
        .replaceAll('G', '6');
  }

  static DateTime? _safeDate(int? y, int? m, int? d) {
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12) return null;
    if (d < 1 || d > 31) return null;
    try {
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  static String? _normalizeGender(String? raw) {
    if (raw == null) return null;
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v == 'm' || v.startsWith('male')) return 'M';
    if (v == 'f' || v.startsWith('female')) return 'F';
    return null;
  }

  static String? _inferGenderFromLooseLines(List<String> lines) {
    for (final l in lines) {
      final t = l.trim().toLowerCase();
      if (t == 'm' || t == 'male') return 'M';
      if (t == 'f' || t == 'female') return 'F';
    }
    return null;
  }

  static double? _parseHeightMeters(String? raw) {
    if (raw == null) return null;
    final v = _normalizeOcrDigits(raw).toLowerCase().replaceAll(',', '.');

    final meters = RegExp(r'\b(\d+(?:\.\d+)?)\s*m\b');
    final mm = meters.firstMatch(v);
    if (mm != null) {
      return double.tryParse(mm.group(1) ?? '');
    }

    final cm = RegExp(r'\b(\d+(?:\.\d+)?)\s*cm\b');
    final cmM = cm.firstMatch(v);
    if (cmM != null) {
      final value = double.tryParse(cmM.group(1) ?? '');
      if (value == null) return null;
      return value / 100.0;
    }

    // Some IDs just show a bare number (e.g. 1.75). Pick the first plausible.
    final bare = RegExp(r'\b(\d\.\d{1,2})\b');
    for (final m in bare.allMatches(v)) {
      final parsed = double.tryParse(m.group(1) ?? '');
      if (parsed == null) continue;
      if (parsed >= 1.0 && parsed <= 2.5) return parsed;
    }

    return null;
  }

  static double? _inferHeightMetersFromLines(List<String> lines) {
    // Prefer explicit units, otherwise pick plausible values.
    final candidates = <double>[];
    for (final line in lines) {
      final v = _normalizeOcrDigits(line).toLowerCase();
      final h = _parseHeightMeters(v);
      if (h == null) continue;
      if (h >= 1.0 && h <= 2.5) candidates.add(h);
    }
    if (candidates.isEmpty) return null;
    // Choose median-ish to avoid outliers.
    candidates.sort();
    return candidates[candidates.length ~/ 2];
  }

  static (ParsedDate?, ParsedDate?) _inferDobAndIssueFromLines(
    List<String> lines, {
    required ParsedDate? labeledDob,
    required ParsedDate? labeledIssue,
  }) {
    var dob = labeledDob;
    var issue = labeledIssue;

    final all = <ParsedDate>[];
    for (final l in lines) {
      final p = _parseDate(l);
      if (p != null && p.value != null) all.add(p);
    }
    if (all.isEmpty) return (dob, issue);

    all.sort((a, b) => a.value!.compareTo(b.value!));
    final oldest = all.first;
    final newest = all.last;

    // If either date is missing or un-parseable, infer from ordering.
    if (dob == null || dob.value == null) dob = oldest;
    if (issue == null || issue.value == null) {
      // If only one date found, keep issue null.
      if (all.length >= 2) issue = newest;
    }

    if (dob?.value != null && issue?.value != null) {
      // DOB must be earlier than issue date.
      if (dob!.value!.isAfter(issue!.value!)) {
        final tmp = dob;
        dob = issue;
        issue = tmp;
      }
    }

    return (dob, issue);
  }

  static String? _pickBestIdNumber(String? labeled, List<String> lines) {
    final cleanedLabeled = _cleanupIdNumber(labeled);
    if (cleanedLabeled != null && cleanedLabeled.length >= 9) {
      return cleanedLabeled;
    }

    // Build a set of date digits to avoid selecting DOB/issue as the ID.
    final dateDigits = <String>{};
    for (final l in lines) {
      final working = _normalizeOcrDigits(l);
      for (final m in RegExp(r'\b(\d{8})\b').allMatches(working)) {
        final s = m.group(1);
        if (s != null) dateDigits.add(s);
      }
    }

    final candidates = <String>[];
    for (final l in lines) {
      final compact = _normalizeOcrDigits(l).replaceAll(RegExp(r'\s+'), '');
      for (final m in RegExp(r'\b[0-9]{9,13}\b').allMatches(compact)) {
        final s = m.group(0);
        if (s == null) continue;
        if (dateDigits.contains(s)) continue;
        candidates.add(s);
      }
    }
    if (candidates.isEmpty) return cleanedLabeled;

    // Prefer 11-13 digits, then longest.
    candidates.sort((a, b) {
      int score(String v) {
        if (v.length >= 11) return 3;
        if (v.length == 10) return 2;
        return 1;
      }

      final sa = score(a);
      final sb = score(b);
      if (sa != sb) return sb.compareTo(sa);
      return b.length.compareTo(a.length);
    });
    return candidates.first;
  }

  static String? _findLikelyIdNumber(List<String> lines) {
    // Very country-specific; we keep it conservative.
    // Looks for 9-13 digit contiguous numbers.
    final re = RegExp(r'\b\d{9,13}\b');
    for (final l in lines) {
      final m = re.firstMatch(l.replaceAll(' ', ''));
      if (m != null) return m.group(0);
    }
    return null;
  }
}
