#!/usr/bin/env bash
#
# Interactive script to generate a X.509 private key and corresponding
# Certificate Signing Request (CSR), or create a self-signed certificate.
# For increased security, the private key is not written to disk.
# 
# Can also use an existing private key, by piping the PEM formatted value to
# the script.
#
#
#
#
# Array variables - the first item in each variable is treated as the default.
SIGN_TYPES=(CA-signed Self-signed)
KEY_TYPES=(ECC RSA)
EC_CURVES=(prime256v1 secp384r1)
RSA_SIZES=(2048 3072 4096)

# Help message if not enough parameters are provided
if [ $# -lt 1 ]; then
  me=`basename ${BASH_SOURCE}`
  echo "Usage: $me cn <san_1 san_2 san_3 san_4 ... san_n>
The first argument is cn (Common Name).
Optional further arguments are treated as Subject Altenative Names.

It is also possible to reuse an existing private key by providing it
to STDIN.

Examples:

# Generate a new CSR and key for a hostname and a few SANs
$me www.uni.edu uni.edu old_uni.edu

# The same, but reuse an existing private key
cat privkey.pem | $me www.uni.edu uni.old other.tld

# Similar, but fetch the private key from an ansible vault
ansible-vault view privkey.vault | $me www.uni.edu uni.old other.tld

# Similar, but fetch the private key from a variable in an ansible vaulted YAML file
ansible-vault view vault.yml | yq -r .privkey | $me www.uni.edu uni.old other.tld

# Generate a self signed key pair for a SAML Service Provider
$me 'My Fancy New Service'

"
  exit 1
fi


# Supporting function, to mimic bash' "select"
function selectWithDefault() {
  local item i=0 numItems=$#
  # Print numbered menu items, based on the arguments passed.
  for item; do
    # Add an asterisk to the first (default) option
    printf '%s\n' "$((++i))) $item$([[ $i == 1 ]] && echo ' *')"
  done >&2 # Print to stderr, as `select` does.

  # Prompt the user for the index of the desired item.
  while :; do
    printf %s "${PS3-#? }" >&2 # Print the prompt string to stderr, as `select` does.
    read -r index < /dev/tty
    # Make sure that the input is either empty or that a valid index was entered.
    [[ -z $index ]] && break  # empty input
    (( index >= 1 && index <= numItems )) 2>/dev/null || { echo "Invalid selection. Please try again." >&2; continue; }
    break
  done

  # Output the selected item, if any.
  if [[ -n $index ]]; then
    printf %s "${@: index:1}"
  else
    # Default: first item
    printf %s "${1}"
  fi
}




# Check if we received a valid private key in STDIN
if ! test -t 0 ; then
  INPUT="$(< /dev/stdin)"
  if echo "$INPUT" | openssl pkey -noout; then
    PRIVATE_KEY=$(echo "$INPUT" | openssl pkey)
  else
    exit 1
  fi
fi


# Select how the certificate should be signed.
# Defaults to CA signed, which results in a CSR.
# It self-signed it selected, then the key type will default to RSA, as this is
# common, for instance for SAML certificates.
echo "Select signing type"
SIGN_TYPE=$(selectWithDefault "${SIGN_TYPES[@]}")
if [ $SIGN_TYPE = "Self-signed" ]; then
  KEY_TYPES=(RSA ECC)
fi


# Key generation flags
if [ -z "$PRIVATE_KEY" ]; then
  # This is only needed when we do NOT have a valid private key from STDIN
  echo "Select key type"
  KEY_TYPE=$(selectWithDefault "${KEY_TYPES[@]}")

  if [ "$KEY_TYPE" = "ECC" ]; then
    # Select ECC curve
    echo "Select curve"
    EC_CURVE=$(selectWithDefault "${EC_CURVES[@]}")
    EC_PARAMS=$(mktemp)
    openssl ecparam -name ${EC_CURVE} -out ${EC_PARAMS}
    KEY_SPEC="-newkey ec:${EC_PARAMS} -keyout /dev/stdout 2>/dev/null"
  elif [ "$KEY_TYPE" = "RSA" ]; then
    # Select RSA key size
    echo "Select RSA size"
    RSA_SIZE=$(selectWithDefault "${RSA_SIZES[@]}")
    KEY_SPEC="-newkey rsa:${RSA_SIZE} -keyout /dev/stdout 2>/dev/null"
  else
    echo "Not implemented yet"
  fi
else
  # We use the private key from STDIN
  KEY_SPEC="-new -key <(echo -n \"${PRIVATE_KEY}\")"
fi



if [ $SIGN_TYPE = "CA-signed" ]; then
  if [ $# -eq 1 ]; then
    # One argument => simple scenario
    eval "openssl req -nodes -subj /CN=${1}/ $KEY_SPEC"
  else
    # More than one argument => first arg is CN, the rest is the list of SANs
    s="subjectAltName="
    for san in `echo $@`; do s="${s}DNS:$san,"; done
    eval "openssl req -nodes -subj /CN=${1}/ ${KEY_SPEC} \
      -reqexts SAN -extensions SAN \
      -config <(printf \"[req]\ndistinguished_name=rdn\n[rdn]\n[SAN]\n`echo ${s} | sed 's/.$//'`\")"
  fi
elif [ $SIGN_TYPE = "Self-signed" ]; then
  all_args="${@}"

  # For self-signed there is ONLY "CN=blah", and NO SubjAltNames.
  eval "openssl req -nodes -days 3650 -x509 -subj '/CN=${all_args}/' ${KEY_SPEC}"
else
  echo "Not implemented yet"
fi


# Clean up temporary EC params file
if [ -n "$EC_PARAMS" ]; then
  rm "${EC_PARAMS}"
fi
