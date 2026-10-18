import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nalaro_seller_center/core/errors/ns_error_mapper.dart';

void main() {
  test('native platform errors do not expose Java stack traces to sellers', () {
    final message = NsErrorMapper.toUserMessage(
      PlatformException(
        code: 'PlatformException',
        message:
            'java.lang.NoSuchMethodError: SharedPreferencesApiRegistrar.getAll',
      ),
    );
    expect(message, contains('Perbarui aplikasi'));
    expect(message, isNot(contains('java.lang')));
    expect(message, isNot(contains('NoSuchMethodError')));
  });
}
