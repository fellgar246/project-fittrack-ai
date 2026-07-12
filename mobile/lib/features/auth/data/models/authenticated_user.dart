class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.email,
    required this.name,
    required this.goal,
  });

  final String id;
  final String email;
  final String name;
  final String goal;

  factory AuthenticatedUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    final name = json['name'];
    final goal = json['goal'];

    if (id == null || id.toString().isEmpty) {
      throw const FormatException('Missing id in user response.');
    }
    if (email is! String || email.isEmpty) {
      throw const FormatException('Missing email in user response.');
    }
    if (name is! String || name.isEmpty) {
      throw const FormatException('Missing name in user response.');
    }
    if (goal is! String || goal.isEmpty) {
      throw const FormatException('Missing goal in user response.');
    }

    return AuthenticatedUser(
      id: id.toString(),
      email: email,
      name: name,
      goal: goal,
    );
  }
}
