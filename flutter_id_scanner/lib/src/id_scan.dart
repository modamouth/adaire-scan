enum IdCaptureSide { front, back }

typedef IdScanProgressCallback = void Function(IdCaptureSide side);

class IdScanOptions {
  final bool allowGalleryImport;
  final bool performOcr;

  /// If false (default), cancelling on the back capture returns `null`.
  /// If true, returns a partial result containing the front capture.
  final bool returnPartialOnCancel;

  const IdScanOptions({
    this.allowGalleryImport = false,
    this.performOcr = true,
    this.returnPartialOnCancel = false,
  });
}

class ParsedDate {
  final DateTime? value;
  final String? raw;

  const ParsedDate({this.value, this.raw});

  @override
  String toString() {
    final v = value;
    if (v == null) return raw ?? '';
    // Date-only, consistent and easy to consume.
    return v.toIso8601String().split('T').first;
  }
}

class IdCardData {
  final String? idNumber;
  final String? surname;
  final String? firstNames;
  final ParsedDate? dateOfBirth;
  final String? citizenship;
  final String? placeOfBirth;
  final String? gender;
  final double? heightMeters;
  final ParsedDate? dateOfIssue;

  const IdCardData({
    this.idNumber,
    this.surname,
    this.firstNames,
    this.dateOfBirth,
    this.citizenship,
    this.placeOfBirth,
    this.gender,
    this.heightMeters,
    this.dateOfIssue,
  });

  IdCardData copyWith({
    String? idNumber,
    String? surname,
    String? firstNames,
    ParsedDate? dateOfBirth,
    String? citizenship,
    String? placeOfBirth,
    String? gender,
    double? heightMeters,
    ParsedDate? dateOfIssue,
  }) {
    return IdCardData(
      idNumber: idNumber ?? this.idNumber,
      surname: surname ?? this.surname,
      firstNames: firstNames ?? this.firstNames,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      citizenship: citizenship ?? this.citizenship,
      placeOfBirth: placeOfBirth ?? this.placeOfBirth,
      gender: gender ?? this.gender,
      heightMeters: heightMeters ?? this.heightMeters,
      dateOfIssue: dateOfIssue ?? this.dateOfIssue,
    );
  }
}

class IdScanResult {
  final String frontImagePath;
  final String? backImagePath;

  final String? frontRawOcrText;
  final String? backRawOcrText;

  final IdCardData data;

  const IdScanResult({
    required this.frontImagePath,
    required this.backImagePath,
    required this.frontRawOcrText,
    required this.backRawOcrText,
    required this.data,
  });
}
