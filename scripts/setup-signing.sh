#!/bin/bash
set -euo pipefail
umask 077

SIGNING_DIRECTORY="$HOME/Library/Application Support/LocalShot/Signing"
IDENTITY_FILE="$SIGNING_DIRECTORY/identity.sha1"
CERTIFICATE_NAME="LocalShot Local Code Signing"
KEYCHAIN_FILE="$HOME/Library/Keychains/login.keychain-db"
mkdir -p "$SIGNING_DIRECTORY"

if [ -s "$IDENTITY_FILE" ]; then
    SIGNING_IDENTITY="$(cat "$IDENTITY_FILE")"
    if [[ ! "$SIGNING_IDENTITY" =~ ^[A-Fa-f0-9]{40}$ ]]; then
        printf 'Invalid LocalShot signing identity file.\n' >&2
        exit 1
    fi
    if ! security find-identity -p codesigning "$KEYCHAIN_FILE" | /usr/bin/grep "$SIGNING_IDENTITY" >/dev/null; then
        printf 'The original LocalShot signing key is missing from the login keychain. Restore it before building; do not replace the identity silently.\n' >&2
        exit 1
    fi
    printf '%s\n' "$SIGNING_IDENTITY"
    exit 0
fi

EXISTING_IDENTITY="$(security find-identity -p codesigning "$KEYCHAIN_FILE" | awk -v label="\"$CERTIFICATE_NAME\"" 'index($0, label) { print $2; exit }')"
if [ -n "$EXISTING_IDENTITY" ]; then
    printf '%s\n' "$EXISTING_IDENTITY" > "$IDENTITY_FILE"
    printf '%s\n' "$EXISTING_IDENTITY"
    exit 0
fi

SIGNING_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/localshot-signing.XXXXXX")"
cleanup() {
    rm -f "$SIGNING_TEMP/key.pem" "$SIGNING_TEMP/cert.pem" "$SIGNING_TEMP/identity.p12" "$SIGNING_TEMP/password" "$SIGNING_TEMP/cert.conf"
    rmdir "$SIGNING_TEMP"
}
trap cleanup EXIT

cat > "$SIGNING_TEMP/cert.conf" <<'CONFIG'
[req]
prompt = no
distinguished_name = name
x509_extensions = signing
[name]
CN = LocalShot Local Code Signing
[signing]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
CONFIG

openssl req -new -x509 -newkey rsa:3072 -nodes -sha256 -days 36500 \
    -config "$SIGNING_TEMP/cert.conf" -keyout "$SIGNING_TEMP/key.pem" -out "$SIGNING_TEMP/cert.pem" 2>/dev/null
PKCS12_PASSWORD="$(openssl rand -hex 32)"
printf '%s' "$PKCS12_PASSWORD" > "$SIGNING_TEMP/password"
openssl pkcs12 -export -name "$CERTIFICATE_NAME" -inkey "$SIGNING_TEMP/key.pem" \
    -in "$SIGNING_TEMP/cert.pem" -out "$SIGNING_TEMP/identity.p12" -passout "file:$SIGNING_TEMP/password"
security import "$SIGNING_TEMP/identity.p12" -k "$KEYCHAIN_FILE" -f pkcs12 \
    -P "$PKCS12_PASSWORD" -T /usr/bin/codesign >/dev/null
unset PKCS12_PASSWORD
SIGNING_IDENTITY="$(openssl x509 -in "$SIGNING_TEMP/cert.pem" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')"
printf '%s\n' "$SIGNING_IDENTITY" > "$IDENTITY_FILE"
cp "$SIGNING_TEMP/cert.pem" "$SIGNING_DIRECTORY/certificate.pem"
printf '%s\n' "$SIGNING_IDENTITY"
