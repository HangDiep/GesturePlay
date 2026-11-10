import '../survival/round_result.dart';

class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.displayName,
    this.email = '',
    this.preview = false,
  });
  final String id, displayName, email;
  final bool preview;
  PlayerProfile renamed(String name) =>
      PlayerProfile(id: id, displayName: name, email: email, preview: preview);
}

/// The UI depends on this boundary; configure the online implementation once
/// the project's public URL/key and database are supplied.
abstract interface class AccountGateway {
  bool get configured;
  Future<PlayerProfile> signIn(String email, String password);
  Future<PlayerProfile> signUp(String name, String email, String password);
  Future<void> signOut();
  Future<PlayerProfile> rename(String name);
  Future<List<RoundResult>> history();

  /// Atomically upsert by (playerId, result.id). Verify the authenticated owner.
  /// A retry of an already committed round must return success, not insert again.
  Future<void> saveResult(RoundResult result, {required String playerId});
}

class AccountNotConfigured implements Exception {
  const AccountNotConfigured();
  @override
  String toString() =>
      'Chưa kết nối dữ liệu tài khoản. Bạn có thể chọn Trải nghiệm giao diện bên dưới.';
}

class PendingAccountGateway implements AccountGateway {
  const PendingAccountGateway();
  @override
  bool get configured => false;
  @override
  Future<PlayerProfile> signIn(String email, String password) async =>
      throw const AccountNotConfigured();
  @override
  Future<PlayerProfile> signUp(
    String name,
    String email,
    String password,
  ) async => throw const AccountNotConfigured();
  @override
  Future<PlayerProfile> rename(String name) async =>
      throw const AccountNotConfigured();
  @override
  Future<void> signOut() async {}
  @override
  Future<List<RoundResult>> history() async =>
      throw const AccountNotConfigured();
  @override
  Future<void> saveResult(
    RoundResult result, {
    required String playerId,
  }) async => throw const AccountNotConfigured();
}
