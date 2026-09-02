class UserArguments {
  final String userId;
  final String userName;
  final String email;

  const UserArguments({
    required this.userId,
    required this.userName,
    this.email = '',
  });
}
