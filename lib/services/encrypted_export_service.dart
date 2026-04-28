import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Encrypts an export blob with a user-chosen passphrase.
///
/// Format (`TRLENC01`):
///   `magic[8] || salt[16] || nonce[12] || ciphertext || gcmTag[16]`
///
///   - magic: ASCII "TRLENC01" — version-bumped by changing the last
///     two bytes when the format ever changes.
///   - salt: 16 random bytes; per-export so the same passphrase never
///     produces the same key for two exports.
///   - nonce: 12 random bytes; AES-GCM's standard 96-bit IV.
///   - key: PBKDF2-HMAC-SHA256(passphrase, salt, 210000 iterations,
///     32 bytes). Same iteration count as `PassphraseService` so an
///     attacker doesn't get an easier path here than against the DB
///     key.
///   - ciphertext + gcmTag: AES-256-GCM. Tag is appended to the
///     ciphertext by pointycastle's GCM mode.
///
/// The companion script `docs/decrypt-export.py` reverses this with
/// `cryptography` from PyPI — no Trail-specific tooling needed on the
/// recipient side.
class EncryptedExportService {
  static const _magic = 'TRLENC01';
  static const _saltBytes = 16;
  static const _nonceBytes = 12;
  static const _keyBytes = 32;
  static const _gcmTagBytes = 16;
  static const _pbkdf2Iterations = 210000;

  /// Encrypts [plaintext] with [passphrase]. The returned bytes can
  /// be written to disk as a `.enc` companion to the original export
  /// (e.g. `trail-2026-04.gpx.enc`).
  static Uint8List encrypt(Uint8List plaintext, String passphrase) {
    final rng = _random();
    final salt = Uint8List(_saltBytes);
    for (var i = 0; i < salt.length; i++) {
      salt[i] = rng.nextInt(256);
    }
    final nonce = Uint8List(_nonceBytes);
    for (var i = 0; i < nonce.length; i++) {
      nonce[i] = rng.nextInt(256);
    }

    final key = _deriveKey(passphrase, salt);
    final ciphertext = _aesGcmEncrypt(key, nonce, plaintext);

    final out = BytesBuilder(copy: false)
      ..add(ascii.encode(_magic))
      ..add(salt)
      ..add(nonce)
      ..add(ciphertext);
    return out.toBytes();
  }

  static Uint8List _deriveKey(String passphrase, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyBytes));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(passphrase)));
  }

  static Uint8List _aesGcmEncrypt(
    Uint8List key,
    Uint8List nonce,
    Uint8List plaintext,
  ) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          _gcmTagBytes * 8,
          nonce,
          Uint8List(0), // no associated data
        ),
      );
    return cipher.process(plaintext);
  }

  static Random _random() {
    try {
      return Random.secure();
    } catch (_) {
      return Random();
    }
  }

  /// Sane heuristic for the passphrase prompt — accepts anything
  /// the user has the patience to type, but warns below 8 chars
  /// because PBKDF2 is the only thing standing between the file
  /// and a determined offline attacker.
  static String? validatePassphrase(String? input) {
    final t = input ?? '';
    if (t.isEmpty) return 'Required';
    if (t.length < 8) return 'Use at least 8 characters';
    return null;
  }
}
