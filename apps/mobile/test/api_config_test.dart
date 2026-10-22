import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/api/api_config.dart';

void main() {
  test('default config uses the build address or emulator fallback', () {
    const expected = String.fromEnvironment(
      'EXPECTED_API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000',
    );
    expect(const ApiConfig().baseUrl, expected);
  });

  test('explicit override takes precedence over build configuration', () {
    const config = ApiConfig(baseUrl: 'https://example.test');
    expect(config.baseUrl, 'https://example.test');
  });
}
