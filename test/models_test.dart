import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha_ai/models/auth_response.dart';
import 'package:kharcha_ai/models/user_model.dart';

void main() {
  group('UserModel Serialization Tests', () {
    test('UserModel.fromJson parses valid JSON correctly', () {
      final json = {
        'id': 42,
        'email': 'raja@kharcha.ai',
        'full_name': 'Raja Sulman',
        'is_active': true,
        'created_at': '2026-10-28T07:00:00Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 42);
      expect(user.email, 'raja@kharcha.ai');
      expect(user.fullName, 'Raja Sulman');
      expect(user.displayName, 'Raja Sulman');
      expect(user.isActive, true);
      expect(user.createdAt, DateTime.parse('2026-10-28T07:00:00Z'));
    });

    test('UserModel.displayName falls back to email username when full_name is null', () {
      final json = {
        'id': 1,
        'email': 'testuser@kharcha.ai',
        'full_name': null,
        'is_active': true,
        'created_at': '2026-10-28T07:00:00Z',
      };

      final user = UserModel.fromJson(json);
      expect(user.displayName, 'testuser');
    });

    test('AuthResponse.fromJson parses token and embedded user model', () {
      final json = {
        'access_token': 'jwt_sample_token_xyz',
        'token_type': 'bearer',
        'user': {
          'id': 7,
          'email': 'investor@kharcha.ai',
          'full_name': 'Ali Khan',
          'is_active': true,
          'created_at': '2026-10-28T07:00:00Z',
        }
      };

      final authResponse = AuthResponse.fromJson(json);
      expect(authResponse.accessToken, 'jwt_sample_token_xyz');
      expect(authResponse.tokenType, 'bearer');
      expect(authResponse.user.id, 7);
      expect(authResponse.user.email, 'investor@kharcha.ai');
    });
  });
}
