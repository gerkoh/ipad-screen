#!/usr/bin/env bash
# Creates a self-signed code-signing identity in the login keychain, once. Signing with
# it gives iPadScreenCapture a designated requirement that survives rebuilds, so the
# Screen Recording grant does too (an ad-hoc signature is pinned to one exact build).
set -euo pipefail

name="iPadScreen Local Code Signing"
keychain="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$name" "$keychain" >/dev/null 2>&1; then
    echo "\"$name\" already exists."
    exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass="$(openssl rand -hex 16)"

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -subj "/CN=$name" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -addext "basicConstraints=critical,CA:false" \
    -keyout "$work/key.pem" -out "$work/cert.pem" 2>/dev/null
# -legacy: the Security framework can't read OpenSSL 3's default PKCS#12 encryption.
openssl pkcs12 -export -legacy -inkey "$work/key.pem" -in "$work/cert.pem" \
    -name "$name" -out "$work/identity.p12" -passout "pass:$pass" 2>/dev/null \
    || openssl pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" \
        -name "$name" -out "$work/identity.p12" -passout "pass:$pass"

# -T: only codesign may use the private key without asking.
security import "$work/identity.p12" -k "$keychain" -P "$pass" -T /usr/bin/codesign
echo "Created \"$name\"."
