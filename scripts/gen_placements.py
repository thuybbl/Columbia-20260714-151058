#!/usr/bin/env python3
"""Encrypt / verify the ad placement config shipped as app/src/main/assets/1.txt.

module-ads decrypts `assets/1.txt` at startup with the app's **applicationId** as the passphrase,
so a `1.txt` copied from another app (or generated with the wrong package name) silently fails to
decrypt: the placement map stays empty, the library's startup gate never opens, and every ad goes
quiet while the build stays green. Any app generated from this base must re-run this script with
its own applicationId after replacing the ad unit ids.

Format (see BBL-Module-Ads docs/encryption-algorithm.md):

    base64url(salt16) ":" base64url(iv12) ":" base64url(AES-256-GCM(ciphertext + tag))
    key = SHA-256(utf8(applicationId) + salt)

Plaintext source is `config/placements.json` — deliberately **outside** `src/main/assets/` so the
readable config never ships inside the APK. It carries Google's public test unit ids because the
base project is never published.

Usage
-----
    python3 scripts/gen_placements.py                      # applicationId read from app/build.gradle.kts
    python3 scripts/gen_placements.py --package com.example.myapp
    python3 scripts/gen_placements.py --input other.json --output app/src/main/assets/2.txt
    python3 scripts/gen_placements.py --decrypt            # print what the app will actually read
    python3 scripts/gen_placements.py --strict             # exit != 0 on test units / gates with no ad id

Requires the `cryptography` package (`python3 -m pip install cryptography`).
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import sys

try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
except ImportError:  # pragma: no cover - dependency hint only
    sys.exit("Missing dependency: python3 -m pip install cryptography")

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_INPUT = os.path.join(REPO_ROOT, "config", "placements.json")
DEFAULT_OUTPUT = os.path.join(REPO_ROOT, "app", "src", "main", "assets", "1.txt")
BUILD_GRADLE = os.path.join(REPO_ROOT, "app", "build.gradle.kts")

SALT_BYTES = 16
IV_BYTES = 12
TEST_UNIT_PREFIX = "ca-app-pub-3940256099942544"
AD_NAME, IS_SHOW, AD_IDS = "0", "2", "9"


def b64u_encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def b64u_decode(text: str) -> bytes:
    return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


def derive_key(package_name: str, salt: bytes) -> bytes:
    return hashlib.sha256(package_name.encode("utf-8") + salt).digest()


def encrypt(plaintext: str, package_name: str) -> str:
    salt = os.urandom(SALT_BYTES)
    iv = os.urandom(IV_BYTES)
    cipher_with_tag = AESGCM(derive_key(package_name, salt)).encrypt(
        iv, plaintext.encode("utf-8"), None
    )
    return f"{b64u_encode(salt)}:{b64u_encode(iv)}:{b64u_encode(cipher_with_tag)}"


def decrypt(encrypted: str, package_name: str) -> str:
    parts = encrypted.strip().split(":")
    if len(parts) != 3:
        raise ValueError("Invalid format: expected salt:iv:ciphertext")
    salt, iv, cipher_with_tag = (b64u_decode(part) for part in parts)
    if len(salt) != SALT_BYTES:
        raise ValueError(f"Invalid salt length: {len(salt)}")
    if len(iv) != IV_BYTES:
        raise ValueError(f"Invalid IV length: {len(iv)}")
    return AESGCM(derive_key(package_name, salt)).decrypt(iv, cipher_with_tag, None).decode("utf-8")


def read_application_id() -> str:
    with open(BUILD_GRADLE, encoding="utf-8") as handle:
        match = re.search(r'applicationId\s*=\s*"([^"]+)"', handle.read())
    if not match:
        raise SystemExit(f"applicationId not found in {BUILD_GRADLE}; pass --package explicitly")
    return match.group(1)


def audit(placements: list[dict]) -> list[str]:
    """Report the two failure modes that ship happily: test units and gates with no ad id."""
    problems = []

    fake_gates = sorted(
        str(entry.get(AD_NAME))
        for entry in placements
        if str(entry.get(IS_SHOW, 1)) != "0" and not (entry.get(AD_IDS) or [])
    )
    if fake_gates:
        problems.append(
            f"enabled but no ad_ids ({len(fake_gates)}): {', '.join(fake_gates)}\n"
            "    -> fake gate: the UI promises an ad, the request always fails."
        )

    test_units = sorted(
        str(entry.get(AD_NAME))
        for entry in placements
        if any(str(unit.get("0", "")).startswith(TEST_UNIT_PREFIX) for unit in entry.get(AD_IDS) or [])
    )
    if test_units:
        problems.append(
            f"Google test unit ids ({len(test_units)}): {', '.join(test_units)}\n"
            "    -> the APK runs and shows ads with zero revenue. Never in a release."
        )
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--package", help="applicationId used as the passphrase")
    parser.add_argument("--input", default=DEFAULT_INPUT, help="plaintext placement JSON")
    parser.add_argument("--output", default=DEFAULT_OUTPUT, help="encrypted output file")
    parser.add_argument("--decrypt", action="store_true", help="decrypt --output and print it")
    parser.add_argument("--strict", action="store_true", help="fail on test units / gates with no ad id")
    args = parser.parse_args()

    package_name = args.package or read_application_id()

    if args.decrypt:
        with open(args.output, encoding="utf-8") as handle:
            placements = json.loads(decrypt(handle.read(), package_name))
        print(json.dumps(placements, indent=2, ensure_ascii=False))
        print(f"\n{len(placements)} placements, decrypted with '{package_name}'", file=sys.stderr)
        return 0

    with open(args.input, encoding="utf-8") as handle:
        placements = json.load(handle)
    if not isinstance(placements, list):
        raise SystemExit("Placement config must be a JSON array (numeric-key schema)")

    # Compact: the file is parsed on the startup path, and whitespace is pure payload.
    plaintext = json.dumps(placements, separators=(",", ":"), ensure_ascii=False)
    encrypted = encrypt(plaintext, package_name)

    # Round-trip before writing: a bad 1.txt costs 100% of ad revenue and fails silently.
    if json.loads(decrypt(encrypted, package_name)) != placements:
        raise SystemExit("Round-trip check failed — nothing written")

    with open(args.output, "w", encoding="utf-8") as handle:
        handle.write(encrypted)

    names = [str(entry.get(AD_NAME)) for entry in placements]
    print(f"OK {args.input} -> {args.output}")
    print(f"  package: {package_name}")
    print(f"  placements ({len(names)}): {', '.join(names)}")

    problems = audit(placements)
    for problem in problems:
        print(f"  [!] {problem}")
    return 1 if (problems and args.strict) else 0


if __name__ == "__main__":
    sys.exit(main())
