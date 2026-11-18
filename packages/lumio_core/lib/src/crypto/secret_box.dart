import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as c;

/// Phrase secrète erronée, ou contenu altéré / illisible : on ne distingue
/// volontairement pas les deux (un chiffrement authentifié ne le permet pas).
class WrongPassphraseException implements Exception {
  const WrongPassphraseException();

  @override
  String toString() => 'WrongPassphraseException';
}

/// Chiffrement côté client des secrets synchronisés (le serveur ne voit
/// qu'un texte opaque).
///
/// Format : `v1.<sel>.<nonce>.<texte chiffré + tag>`, chaque partie en
/// base64url sans remplissage. Clé : PBKDF2-HMAC-SHA256, 210 000 itérations,
/// sel aléatoire de 16 octets, 256 bits. Chiffrement : AES-256-GCM, nonce
/// aléatoire de 12 octets, tag de 16 octets. Les données associées (AAD)
/// sont le type de l'élément synchronisé (`addons`) : un blob ne peut pas
/// être rejoué sous un autre type.
///
/// La dérivation coûte cher : elle s'exécute dans un isolat, jamais sur le
/// fil d'interface.
abstract final class SecretBox {
  static const version = 'v1';
  static const iterations = 210000;
  static const saltLength = 16;
  static const nonceLength = 12;
  static const tagLength = 16;
  static const keyLength = 32;

  /// Données associées par défaut : le type d'élément des addons.
  static const defaultAad = 'addons';

  static Future<String> seal(
    String plaintext,
    String passphrase, {
    String aad = defaultAad,
  }) => Isolate.run(() => _seal(plaintext, passphrase, aad));

  /// Lève [WrongPassphraseException] pour toute entrée qui ne s'ouvre pas
  /// (mauvaise phrase, format inconnu, un seul caractère modifié).
  static Future<String> open(
    String sealed,
    String passphrase, {
    String aad = defaultAad,
  }) async {
    // Format vérifié avant la dérivation : une entrée malformée ne coûte rien.
    final parsed = _parse(sealed);
    return Isolate.run(() => _open(parsed, passphrase, aad));
  }

  /// PBKDF2-HMAC-SHA256 (exposé pour les tests de vecteurs).
  static Future<List<int>> pbkdf2(
    List<int> password,
    List<int> salt,
    int iter,
  ) async {
    final key = await c.Pbkdf2(
      macAlgorithm: c.Hmac.sha256(),
      iterations: iter,
      bits: keyLength * 8,
    ).deriveKey(secretKey: c.SecretKey(password), nonce: salt);
    return key.extractBytes();
  }

  static String _b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');

  /// Décodage strict : refuse les caractères hors alphabet, le remplissage et
  /// les bits de fin non nuls (deux textes différents ne donnent jamais les
  /// mêmes octets).
  static Uint8List? _unb64(String s) {
    if (s.isEmpty || s.length % 4 == 1) return null;
    try {
      final bytes = base64Url.decode(base64Url.normalize(s));
      return _b64(bytes) == s ? Uint8List.fromList(bytes) : null;
    } on FormatException {
      return null;
    }
  }

  static ({Uint8List salt, Uint8List nonce, Uint8List data}) _parse(
    String sealed,
  ) {
    final parts = sealed.split('.');
    if (parts.length != 4 || parts[0] != version) {
      throw const WrongPassphraseException();
    }
    final salt = _unb64(parts[1]);
    final nonce = _unb64(parts[2]);
    final data = _unb64(parts[3]);
    if (salt == null ||
        nonce == null ||
        data == null ||
        salt.length != saltLength ||
        nonce.length != nonceLength ||
        data.length < tagLength) {
      throw const WrongPassphraseException();
    }
    return (salt: salt, nonce: nonce, data: data);
  }

  static List<int> _random(int n) {
    final r = Random.secure();
    return [for (var i = 0; i < n; i++) r.nextInt(256)];
  }

  static final _aes = c.AesGcm.with256bits();

  static Future<String> _seal(
    String plaintext,
    String passphrase,
    String aad,
  ) async {
    final salt = _random(saltLength);
    final nonce = _random(nonceLength);
    final key = await pbkdf2(utf8.encode(passphrase), salt, iterations);
    final box = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: c.SecretKey(key),
      nonce: nonce,
      aad: utf8.encode(aad),
    );
    return '$version.${_b64(salt)}.${_b64(nonce)}.'
        '${_b64([...box.cipherText, ...box.mac.bytes])}';
  }

  static Future<String> _open(
    ({Uint8List salt, Uint8List nonce, Uint8List data}) p,
    String passphrase,
    String aad,
  ) async {
    try {
      final key = await pbkdf2(utf8.encode(passphrase), p.salt, iterations);
      final cut = p.data.length - tagLength;
      final clear = await _aes.decrypt(
        c.SecretBox(
          p.data.sublist(0, cut),
          nonce: p.nonce,
          mac: c.Mac(p.data.sublist(cut)),
        ),
        secretKey: c.SecretKey(key),
        aad: utf8.encode(aad),
      );
      return utf8.decode(clear);
    } on Object {
      throw const WrongPassphraseException();
    }
  }
}
