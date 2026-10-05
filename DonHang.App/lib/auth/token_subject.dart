import 'dart:convert';

// lesson: frontend.l3.syncing-the-queue
// The `sub` claim of an access token: who the customer is. A JWT is three
// base64url parts joined by dots; the middle one is the JSON payload. The
// app only reads it to tell customers apart on this browser; checking the
// signature stays the API's job (backend.l2.validating-provider-tokens).
String? tokenSubject(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final claims = jsonDecode(payload);
    return claims is Map<String, dynamic> ? claims['sub'] as String? : null;
  } on FormatException {
    return null;
  }
}
