#!/usr/bin/env python3
"""Decrypt a Trail-encrypted export.

Trail's "Encrypt with passphrase" toggle wraps each GPX/CSV file in
an `EncryptedExportService` blob (see lib/services/encrypted_export_service.dart):

    magic[8] || salt[16] || nonce[12] || ciphertext || gcmTag[16]

Where:
  - magic = b"TRLENC01"
  - salt  = 16 random bytes (per export)
  - nonce = 12 random bytes (AES-GCM IV)
  - key   = PBKDF2-HMAC-SHA256(passphrase, salt, 210000 iterations, 32 bytes)
  - body  = AES-256-GCM(key, nonce, plaintext) — tag is the trailing 16 bytes

Usage:
    pip install cryptography
    python decrypt-export.py trail-2026-04.gpx.enc trail-2026-04.gpx
    # passphrase prompted interactively (no echo)

The output filename argument is optional; defaults to stripping `.enc`.
Exit code 1 on bad passphrase or corrupted file.
"""

from __future__ import annotations

import argparse
import getpass
import struct
import sys
from pathlib import Path

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes

MAGIC = b"TRLENC01"
SALT_LEN = 16
NONCE_LEN = 12
KEY_LEN = 32
PBKDF2_ITERS = 210000


def decrypt(blob: bytes, passphrase: str) -> bytes:
    if len(blob) < len(MAGIC) + SALT_LEN + NONCE_LEN + 16:
        raise ValueError("file too short to be a Trail export")
    if blob[: len(MAGIC)] != MAGIC:
        raise ValueError(f"bad magic; expected {MAGIC!r}")
    cursor = len(MAGIC)
    salt = blob[cursor : cursor + SALT_LEN]
    cursor += SALT_LEN
    nonce = blob[cursor : cursor + NONCE_LEN]
    cursor += NONCE_LEN
    ciphertext = blob[cursor:]

    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=KEY_LEN,
        salt=salt,
        iterations=PBKDF2_ITERS,
    )
    key = kdf.derive(passphrase.encode("utf-8"))
    aesgcm = AESGCM(key)
    return aesgcm.decrypt(nonce, ciphertext, associated_data=None)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("input", type=Path, help="path to .enc file")
    p.add_argument(
        "output",
        type=Path,
        nargs="?",
        help="output path (defaults to stripping .enc)",
    )
    p.add_argument(
        "--passphrase",
        help="passphrase (otherwise prompted)",
    )
    args = p.parse_args()

    if args.output is None:
        if args.input.suffix == ".enc":
            args.output = args.input.with_suffix("")
        else:
            args.output = args.input.with_suffix(args.input.suffix + ".decrypted")

    blob = args.input.read_bytes()
    passphrase = args.passphrase or getpass.getpass("Passphrase: ")
    try:
        plaintext = decrypt(blob, passphrase)
    except Exception as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    args.output.write_bytes(plaintext)
    print(f"wrote {args.output} ({len(plaintext)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
