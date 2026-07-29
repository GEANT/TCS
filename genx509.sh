#!/usr/bin/env bash

SIGN_TYPES=(CA-signed Self-signed)
KEY_TYPES=(ECC RSA)
EC_CURVES=(prime256v1 secp384r1)
RSA_SIZES=(2048 3072 4096)

function usage() {
  local me
  me=$(basename "${BASH_SOURCE[0]}")
  echo "Usage: $me <common_name> [san_1 san_2 ... san_n]

Interactive script to generate an X.509 private key and corresponding Certificate 
Signing Request (CSR), or create a self-signed certificate. For increased security, 
the private key is not written to disk.

An existing PEM-formatted private key can also be reused by piping it to STDIN.

Arguments:
  <common_name>   Primary domain name or Common Name (CN).
  [san_1 ... n]   Optional list of Subject Alternative Names (SANs).

Options:
  -h, --help      Display this help message and exit.

Examples:
  # Generate a CSR and private key with multiple SANs:
  $me www.uni.edu uni.edu old_uni.edu

  # Reuse an existing private key via STDIN:
  cat privkey.pem | $me www.uni.edu uni.old other.tld

  # Extract a private key from Ansible Vault and pass via STDIN:
  ansible-vault view privkey.vault | $me www.uni.edu uni.old other.tld

  # Extract a private key from a vaulted YAML file using yq:
  ansible-vault view vault.yml | yq -r .privkey | $me www.uni.edu uni.old other.tld

  # Generate a self-signed key pair (e.g., for a SAML Service Provider):
  $me 'My Service Provider'
"
}

if [[ $# -lt 1 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  usage
  exit 1
fi

function selectWithDefault() {
  local item i=0 numItems=$#
  for item; do
    printf '%s\n' "$((++i))) $item$([[ $i == 1 ]] && echo ' *')"
  done >&2

  while :; do
    printf %s "${PS3-#? }" >&2
    read -r index < /dev/tty
    [[ -z $index ]] && break
    (( index >= 1 && index <= numItems )) 2>/dev/null || { echo "Invalid selection. Please try again." >&2; continue; }
    break
  done

  if [[ -n $index ]]; then
    printf %s "${@: index:1}"
  else
    printf %s "${1}"
  fi
}

if ! test -t 0 ; then
  INPUT="$(< /dev/stdin)"
  if echo "$INPUT" | openssl pkey -noout >/dev/null 2>&1; then
    PRIVATE_KEY="$INPUT"
  else
    echo "Invalid private key provided on STDIN." >&2
    exit 1
  fi
fi

echo "Select signing type" >&2
SIGN_TYPE=$(selectWithDefault "${SIGN_TYPES[@]}")
if [[ "$SIGN_TYPE" == "Self-signed" ]]; then
  KEY_TYPES=(RSA ECC)
fi

OPENSSL_ARGS=(-nodes)

if [[ -z "$PRIVATE_KEY" ]]; then
  echo "Select key type" >&2
  KEY_TYPE=$(selectWithDefault "${KEY_TYPES[@]}")

  if [[ "$KEY_TYPE" == "ECC" ]]; then
    echo "Select curve" >&2
    EC_CURVE=$(selectWithDefault "${EC_CURVES[@]}")
    OPENSSL_ARGS+=(-newkey ec -pkeyopt "ec_paramgen_curve:${EC_CURVE}" -keyout /dev/stdout)
  elif [[ "$KEY_TYPE" == "RSA" ]]; then
    echo "Select RSA size" >&2
    RSA_SIZE=$(selectWithDefault "${RSA_SIZES[@]}")
    OPENSSL_ARGS+=(-newkey "rsa:${RSA_SIZE}" -keyout /dev/stdout)
  else
    echo "Not implemented yet" >&2
    exit 1
  fi
else
  OPENSSL_ARGS+=(-new -key /dev/stdin)
fi

CN="$1"
shift

if [[ "$SIGN_TYPE" == "CA-signed" ]]; then
  OPENSSL_ARGS+=(-subj "/CN=${CN}")
  if [[ $# -ge 1 ]]; then
    SAN_LIST=""
    for san in "$@"; do
      SAN_LIST="${SAN_LIST}DNS:${san},"
    done
    SAN_LIST="${SAN_LIST%,}"

    CONFIG_CONTENTS=$(printf "[req]\ndistinguished_name=rdn\n[rdn]\n[SAN]\nsubjectAltName=%s\n" "${SAN_LIST}")

    if [[ -n "$PRIVATE_KEY" ]]; then
      echo "$PRIVATE_KEY" | openssl req "${OPENSSL_ARGS[@]}" \
        -reqexts SAN -extensions SAN \
        -config <(printf "%s" "$CONFIG_CONTENTS")
    else
      openssl req "${OPENSSL_ARGS[@]}" \
        -reqexts SAN -extensions SAN \
        -config <(printf "%s" "$CONFIG_CONTENTS")
    fi
  else
    if [[ -n "$PRIVATE_KEY" ]]; then
      echo "$PRIVATE_KEY" | openssl req "${OPENSSL_ARGS[@]}"
    else
      openssl req "${OPENSSL_ARGS[@]}"
    fi
  fi
elif [[ "$SIGN_TYPE" == "Self-signed" ]]; then
  days=$(( ((2**31) - 1 - $(date +%s)) / 86400 ))
  OPENSSL_ARGS+=(-days "${days}" -x509 -subj "/CN=${CN}")

  if [[ -n "$PRIVATE_KEY" ]]; then
    echo "$PRIVATE_KEY" | openssl req "${OPENSSL_ARGS[@]}"
  else
    openssl req "${OPENSSL_ARGS[@]}"
  fi
fi
