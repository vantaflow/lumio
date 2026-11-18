import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage des secrets (URL d'addons, jetons). Rien de ce qui passe ici ne
/// doit finir en clair dans SQLite ni dans les journaux.
abstract class SecretStore {
  Future<void> write(String k, String v);
  Future<String?> read(String k);
  Future<void> delete(String k);
}

/// Implémentation adossée au trousseau du système (Keystore Android,
/// Keychain, etc.).
class SecureSecretStore implements SecretStore {
  SecureSecretStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String k, String v) => _storage.write(key: k, value: v);

  @override
  Future<String?> read(String k) => _storage.read(key: k);

  @override
  Future<void> delete(String k) => _storage.delete(key: k);
}

/// Implémentation en mémoire, pour les tests.
class MemorySecretStore implements SecretStore {
  final Map<String, String> _data = {};

  /// Copie des entrées (pour les assertions de test).
  Map<String, String> get snapshot => Map.unmodifiable(_data);

  @override
  Future<void> write(String k, String v) async => _data[k] = v;

  @override
  Future<String?> read(String k) async => _data[k];

  @override
  Future<void> delete(String k) async => _data.remove(k);
}
