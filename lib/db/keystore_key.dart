import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages the DB passphrase used by SQLCipher.
///
/// On first launch we generate a cryptographically-strong random 32-byte key,
/// base64-encode it, and store it in Android Keystore via
/// [FlutterSecureStorage]. Subsequent launches read it back out. The user
/// never sees or sets this — there is no in-app "change passphrase" flow
/// (PLAN.md explicitly rejects user-set passphrases).
///
/// Consequences:
/// - `android:allowBackup="false"` in the manifest prevents the Keystore
///   entry from being restored onto a different device. If it were restored,
///   the key would be re-wrapped under a new device key and the DB would
///   become unreadable.
/// - If Keystore is cleared (factory reset, secure-erase), the DB becomes
///   unreadable. We surface this in [KeystoreKey.hasExisting] so the UI can
///   offer a "reset DB" path.
class KeystoreKey {
  static const _storageKey = 'trail_db_passphrase_v1';
  static final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Returns the existing passphrase or generates + persists a new one.
  static Future<String> getOrCreate() async {
    final existing = await _secure.read(key: _storageKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    final key = base64UrlEncode(bytes);
    await _secure.write(key: _storageKey, value: key);
    return key;
  }

  /// Whether a passphrase is already stored. Used by the "reset DB"
  /// diagnostic flow (Phase 6).
  static Future<bool> hasExisting() async {
    final v = await _secure.read(key: _storageKey);
    return v != null && v.isNotEmpty;
  }

  /// Deletes the stored passphrase. Caller is responsible for also deleting
  /// the DB file — otherwise the app will be stuck unable to decrypt it.
  static Future<void> reset() => _secure.delete(key: _storageKey);
}
