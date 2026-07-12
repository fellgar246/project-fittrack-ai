class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.tokenType,
  });

  final String accessToken;
  final String tokenType;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final accessToken = json['access_token'];
    final tokenType = json['token_type'];

    if (accessToken is! String || accessToken.isEmpty) {
      throw const FormatException('Missing access_token in auth response.');
    }
    if (tokenType is! String || tokenType.isEmpty) {
      throw const FormatException('Missing token_type in auth response.');
    }

    return AuthResponse(
      accessToken: accessToken,
      tokenType: tokenType,
    );
  }
}
