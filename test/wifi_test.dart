import 'package:flutter_test/flutter_test.dart';
import 'package:autopunch/service/wifi.dart';

void main() {
  test('normalizeSsid strips Android quotes and hides unknown names', () {
    expect(normalizeSsid('"Office-5G"'), 'Office-5G');
    expect(normalizeSsid('Office'), 'Office');
    expect(normalizeSsid('<unknown ssid>'), isNull);
    expect(normalizeSsid('""'), isNull);
    expect(normalizeSsid(null), isNull);
  });
}
