import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha_ai/core/config/api_config.dart';

void main() {
  group('ApiConfig Tests', () {
    test('Default base URL returns a valid URL structure', () {
      final baseUrl = ApiConfig.baseUrl;
      expect(baseUrl.startsWith('http://') || baseUrl.startsWith('https://'), isTrue);
    });

    test('Endpoint getters format correct URL paths', () {
      expect(ApiConfig.healthUrl.endsWith('/health'), isTrue);
      expect(ApiConfig.registerUrl.endsWith('/api/v1/auth/register'), isTrue);
      expect(ApiConfig.loginUrl.endsWith('/api/v1/auth/login'), isTrue);
      expect(ApiConfig.meUrl.endsWith('/api/v1/auth/me'), isTrue);
    });

    test('Host address constants are properly formatted', () {
      expect(ApiConfig.androidEmulatorHost, 'http://10.0.2.2:8000');
      expect(ApiConfig.loopbackHost, 'http://127.0.0.1:8000');
      expect(ApiConfig.physicalDeviceHost, 'http://192.168.1.13:8000');
      expect(ApiConfig.productionHost, 'https://api.kharcha.ai');
    });
  });
}
