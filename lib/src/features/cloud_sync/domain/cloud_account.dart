class CloudAccount {
  const CloudAccount({required this.id, required this.email});

  final String id;
  final String email;
}

abstract interface class CloudAuthRepository {
  Stream<CloudAccount?> watchAccount();

  Future<void> signIn({required String email, required String password});

  Future<void> signUp({required String email, required String password});

  Future<void> signOut();
}
