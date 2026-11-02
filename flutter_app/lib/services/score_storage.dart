abstract interface class ScoreStorage {
  Future<String?> read();
  Future<void> write(String contents);
}
