import 'package:fittrack_ai/core/network/redact_signed_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('redacts query string from signed blob url', () {
    const url =
        'https://storage.example.test/container/blob?sv=2024&sig=fake-token';
    expect(
      redactSignedUrl(url),
      'https://storage.example.test/container/blob?<redacted>',
    );
  });

  test('returns url unchanged when query is empty', () {
    const url = 'https://storage.example.test/container/blob';
    expect(redactSignedUrl(url), url);
  });
}
