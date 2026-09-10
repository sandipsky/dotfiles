#!/bin/bash
# Manages the encrypted copy of scripts/github.sh (the project-clone script,
# which carries a GitHub token and therefore never gets committed in plain
# text — it's gitignored; only scripts/github.sh.enc is in the repo).
#
#   ./scripts/secrets.sh encrypt   scripts/github.sh -> scripts/github.sh.enc
#   ./scripts/secrets.sh check     verify the password decrypts github.sh.enc
#   ./scripts/secrets.sh decrypt   print the decrypted script to stdout
#   ./scripts/secrets.sh run       decrypt and run it (clones into ~/Projects)
#
# The password is read from the SECRET_PASSWORD environment variable when set
# (that's how install.sh passes it), otherwise openssl prompts on the terminal.
# AES-256-CBC with a salted PBKDF2 key (600k iterations) — the .enc file is
# public, so the passphrase is the only thing protecting the token.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PLAIN="$ROOT/scripts/github.sh"
ENC="$PLAIN.enc"
CIPHER=(-aes-256-cbc -md sha256 -pbkdf2 -iter 600000 -salt)

if [[ -n "${SECRET_PASSWORD:-}" ]]; then
    PASS=(-pass env:SECRET_PASSWORD)
else
    PASS=()
fi

decrypt() {
    local out
    out=$(openssl enc -d "${CIPHER[@]}" "${PASS[@]}" -in "$ENC" 2>/dev/null | tr -d '\0') || return 1
    # A wrong password very rarely survives the padding check; make sure what
    # came out is actually the script before anyone executes it.
    [[ "$out" == '#!/bin/bash'* ]] || return 1
    printf '%s\n' "$out"
}

case "${1:-}" in
    encrypt)
        [[ -f "$PLAIN" ]] || { echo "$PLAIN not found — write the plaintext script first." >&2; exit 1; }
        openssl enc "${CIPHER[@]}" "${PASS[@]}" -in "$PLAIN" -out "$ENC"
        echo "Wrote ${ENC#$ROOT/}"
        ;;
    check)
        [[ -f "$ENC" ]] || { echo "$ENC not found." >&2; exit 1; }
        decrypt > /dev/null
        ;;
    decrypt)
        decrypt
        ;;
    run)
        script=$(decrypt) || { echo "Wrong password or corrupt ${ENC#$ROOT/}." >&2; exit 1; }
        bash -c "$script"
        ;;
    *)
        echo "Usage: $0 encrypt|check|decrypt|run" >&2
        exit 1
        ;;
esac
