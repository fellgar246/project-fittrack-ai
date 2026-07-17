/// Redacts SAS query parameters from blob URLs for logs and error messages.
String redactSignedUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return '<invalid-url>';
  }
  if (uri.query.isEmpty) {
    return url;
  }
  return url.replaceFirst('?${uri.query}', '?<redacted>');
}
