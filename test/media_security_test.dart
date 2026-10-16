import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nalaro_seller_center/data/services/seller_api_service.dart';

void main() {
  test(
    'private images authenticate only to configured API media origin',
    () async {
      final seen = <http.Request>[];
      final api = SellerApiService(
        baseUrl: 'https://beta.example.test',
        httpClient: MockClient((r) async {
          seen.add(r);
          return http.Response.bytes([1, 2, 3], 200);
        }),
      );
      final private = api.resolveMediaUri('/api/media/shop/p.png');
      expect(
        private.toString(),
        'https://beta.example.test/api/media/shop/p.png',
      );
      expect(
        await api.fetchMediaBytes(uri: private, bearerToken: 'test-token'),
        Uint8List.fromList([1, 2, 3]),
      );
      await api.fetchMediaBytes(
        uri: Uri.parse('https://images.example.test/api/media/photo.png'),
        bearerToken: 'test-token',
      );
      expect(seen.first.headers['authorization'], 'Bearer test-token');
      expect(seen.last.headers.containsKey('authorization'), false);
      expect(seen.first.followRedirects, false);
    },
  );
  test('reject insecure image URLs and links with embedded credentials', () {
    final api = SellerApiService();
    expect(
      () => api.resolveMediaUri('http://images.example.test/x.jpg'),
      throwsA(isA<Exception>()),
    );
    expect(
      () => api.resolveMediaUri('https://user:pass@example.test/x.jpg'),
      throwsA(isA<Exception>()),
    );
  });
  test('media failure exposes a recoverable message without returning HTML as image data', () async {
    final api = SellerApiService(
      httpClient: MockClient((r) async => http.Response('Access denied', 404)),
    );
    await expectLater(
      api.fetchMediaBytes(
        uri: api.resolveMediaUri('/api/media/missing.jpg'),
        bearerToken: 'x',
      ),
      throwsA(isA<Exception>()),
    );
  });
}
