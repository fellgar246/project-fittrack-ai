class RegisterRequest {
  const RegisterRequest({
    required this.email,
    required this.name,
    required this.password,
    this.goal = 'body recomposition',
  });

  final String email;
  final String name;
  final String password;
  final String goal;

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'password': password,
      'goal': goal,
    };
  }
}
