import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trail/services/encrypted_export_service.dart';

void main() {
  group('EncryptedExportService.encrypt', () {
    test('begins with the TRLENC01 magic and includes salt + nonce', () {
      final out = EncryptedExportService.encrypt(
        Uint8List.fromList(utf8.encode('hello world')),
        'correct horse battery staple',
      );
      // 8 magic + 16 salt + 12 nonce + ciphertext + 16 GCM tag
      expect(out.length >= 8 + 16 + 12 + 11 + 16, isTrue,
          reason: 'short output cannot fit header + tag');
      expect(utf8.decode(out.sublist(0, 8)), 'TRLENC01');
    });

    test('produces different ciphertext on each call (random salt+nonce)',
        () {
      final pt = Uint8List.fromList(utf8.encode('repeat me'));
      final a = EncryptedExportService.encrypt(pt, 'passphrase');
      final b = EncryptedExportService.encrypt(pt, 'passphrase');
      expect(a, isNot(equals(b)),
          reason:
              'identical output across calls would mean no per-export salt/nonce');
      // But the magic prefix is the same.
      expect(a.sublist(0, 8), b.sublist(0, 8));
    });

    test('ciphertext length is plaintext + 16 (GCM tag)', () {
      final pt = Uint8List(123);
      final out = EncryptedExportService.encrypt(pt, 'p');
      // Header: magic(8) + salt(16) + nonce(12) = 36
      expect(out.length, 36 + pt.length + 16);
    });
  });

  group('EncryptedExportService.validatePassphrase', () {
    test('rejects empty + short, accepts >=8 chars', () {
      expect(EncryptedExportService.validatePassphrase(''), isNotNull);
      expect(EncryptedExportService.validatePassphrase(null), isNotNull);
      expect(EncryptedExportService.validatePassphrase('abc'), isNotNull);
      expect(EncryptedExportService.validatePassphrase('exactly8'), isNull);
      expect(
        EncryptedExportService.validatePassphrase('a much longer phrase'),
        isNull,
      );
    });
  });
}
