import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/bootstrap/app_licenses.dart';

Future<List<LicenseEntry>> _entries() => LicenseRegistry.licenses.toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registerAppLicenses enregistre les licences OFL des deux polices, '
      'une seule fois même appelé deux fois', () async {
    registerAppLicenses();
    registerAppLicenses();

    final List<LicenseEntry> entries = await _entries();
    int countOf(String package) =>
        entries.where((LicenseEntry e) => e.packages.contains(package)).length;
    expect(countOf('Space Grotesk'), 1);
    expect(countOf('JetBrains Mono'), 1);
  });
}
