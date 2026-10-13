# Phase 2 Synthetic Barcode Fixtures

These images contain only versioned synthetic values. They are approved for automated and physical-device verification of QR, EAN-13, and Code 128 behavior.

The fixture values are test inputs, not personal, customer, payment, identity, or production data. Test evidence should refer to fixture IDs and pass or fail results rather than copying decoded values into logs, screenshots, or reports.

Regenerate the PNG files with ZXing Core 3.5.3:

```bash
javac -cp /path/to/core-3.5.3.jar -d /tmp/adaire-fixture-tool tool/GenerateSyntheticFixtures.java
java -cp /tmp/adaire-fixture-tool:/path/to/core-3.5.3.jar GenerateSyntheticFixtures test/fixtures/v1
```

Any change to a payload, format, image, or expected value creates a new fixture version rather than overwriting evidence inputs already used by a candidate.
