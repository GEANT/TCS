#!/usr/bin/env bash

# Script name determined dynamically from invocation
SCRIPT_NAME=$(basename "$0")

# Function to display usage and examples
print_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] [TARGET]

Inspects X.509 certificate details (from stdin, a file, web endpoint, or mail server).
Optionally checks if the certificate has been revoked using its embedded CRL.

TARGET:
  -                              Read PEM-encoded certificate from stdin
  www.example.com                Bare hostname (assumes HTTPS on port 443)
  www.example.com:8443           Bare hostname with custom port
  /path/to/cert.pem              Local PEM-encoded certificate file
  https://example.com            HTTPS endpoint (defaults to port 443)
  https://example.com/cert.crt   Direct URL to a downloadable cert file
  starttls://mail.domain.com     SMTP STARTTLS endpoint (defaults to port 25)
  smtps://mail.domain.com        Implicit TLS mail endpoint (defaults to port 465)
  pop3s://mail.domain.com        POP3S implicit TLS endpoint (defaults to port 995)
  imaps://mail.domain.com        IMAPS implicit TLS endpoint (defaults to port 993)
  ldaps://directory.domain.com   LDAPS implicit TLS endpoint (defaults to port 636)
  mqtts://broker.domain.com      MQTTS implicit TLS endpoint (defaults to port 8883)
  sips://sip.domain.com          SIPS implicit TLS endpoint (defaults to port 5061)
  ircs://irc.domain.com          IRCS implicit TLS endpoint (defaults to port 6697)
  ftps://ftp.domain.com          FTPS implicit TLS endpoint (defaults to port 990)

OPTIONS:
  -c, --crl                      Enable CRL fetching and revocation checking
  --only-sans                    Output ONLY a space-separated list of CN + SANs
  --ip <IP>                      Override the target IP address to connect to (IPv4 or IPv6)
  -4                             Force IPv4 resolution and connection
  -6                             Force IPv6 resolution and connection
  --print-crt                    Include/print the raw PEM-encoded certificate
  -j, --json                     Output structured JSON (suppresses all other output)
  -h, --help                     Show this help message and exit

EXAMPLES:
  # Read certificate from stdin
  cat cert.pem | ./$SCRIPT_NAME
  cat cert.pem | ./$SCRIPT_NAME -

  # Output details as structured JSON
  ./$SCRIPT_NAME --json www.geant.org
  ./$SCRIPT_NAME -j -c www.geant.org

  # Force connection using IPv4 or IPv6
  ./$SCRIPT_NAME -4 www.geant.org
  ./$SCRIPT_NAME -6 www.geant.org

  # Print certificate details along with the PEM certificate
  ./$SCRIPT_NAME --print-crt www.geant.org

  # Inspect using various protocol schemes
  ./$SCRIPT_NAME imaps://imap.domain.com
  ./$SCRIPT_NAME pop3s://pop.domain.com
  ./$SCRIPT_NAME ldaps://ldap.domain.com:636
  ./$SCRIPT_NAME ftps://ftp.domain.com

  # Override IP connection endpoint with IPv4 or IPv6
  ./$SCRIPT_NAME --ip 192.168.1.50 www.geant.org
  ./$SCRIPT_NAME --ip 2001:db8::1 www.geant.org

  # Print only CN and SANs space-separated on a single line
  ./$SCRIPT_NAME --only-sans www.geant.org

  # Print certificate details AND check CRL revocation status
  ./$SCRIPT_NAME -c www.geant.org
  ./$SCRIPT_NAME --crl /etc/ssl/certs/server.pem

EXIT CODES:
  0 - Success (Certificate valid, or NOT revoked when -c is specified)
  1 - Error encountered (missing file, network failure, missing CRL)
  2 - Certificate IS revoked (when -c is specified)
EOF
}

# Capture command execution timestamp in ISO 8601 format
EXECUTION_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Default settings
CHECK_CRL=0
ONLY_SANS=0
OUTPUT_JSON=0
PRINT_CRT=0
OVERRIDE_IP=""
IP_VERSION_FLAG=""
INPUT=""
CONNECTED_IP=""

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--crl)
            CHECK_CRL=1
            shift
            ;;
        --only-sans)
            ONLY_SANS=1
            shift
            ;;
        -j|--json)
            OUTPUT_JSON=1
            shift
            ;;
        --print-crt)
            PRINT_CRT=1
            shift
            ;;
        -4)
            IP_VERSION_FLAG="-4"
            shift
            ;;
        -6)
            IP_VERSION_FLAG="-6"
            shift
            ;;
        --ip)
            if [ -n "$2" ] && [[ ! "$2" =~ ^- ]]; then
                OVERRIDE_IP="$2"
                shift 2
            else
                echo "Error: Argument '--ip' requires a non-empty IP address value." >&2
                exit 1
            fi
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            if [ -z "$INPUT" ]; then
                INPUT="$1"
            else
                echo "Error: Unexpected argument '$1'." >&2
                echo "Run '$SCRIPT_NAME --help' for usage instructions." >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# If no input parameter was passed, check if stdin is piped
if [ -z "$INPUT" ]; then
    if [ ! -t 0 ]; then
        INPUT="-"
    else
        print_help
        exit 0
    fi
fi

# Helper function to print verbose logs only when --only-sans and --json are NOT set
log() {
    if [ "$ONLY_SANS" -eq 0 ] && [ "$OUTPUT_JSON" -eq 0 ]; then
        echo "$@"
    fi
}

# Temporary directory for cert and CRL cleanup
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

CERT_FILE="$TMP_DIR/target_cert.pem"

# Step 1: Resolve input source (stdin vs. Local File vs. Remote URL vs. Bare Hostname)
if [ "$INPUT" = "-" ]; then
    log "[+] Reading certificate from stdin..."
    cat > "$CERT_FILE"
elif [ -f "$INPUT" ]; then
    log "[+] Reading local certificate file..."
    cp "$INPUT" "$CERT_FILE"
else
    # Normalize input: default bare hostnames to https:// scheme
    if [[ ! "$INPUT" =~ ^[a-zA-Z0-9+-.]+:// ]]; then
        INPUT="https://$INPUT"
    fi

    # Extract scheme (e.g., https, starttls, smtps, imaps, pop3s, ldaps, etc.)
    SCHEME=$(echo "$INPUT" | sed -e 's%://.*%%' | tr '[:upper:]' '[:lower:]')

    # Remove scheme prefix
    URL_PATH="${INPUT#*://}"

    # Extract raw target (host:port) before any path
    TARGET=$(echo "$URL_PATH" | cut -d'/' -f1)

    # Extract clean host and explicit port
    HOST=$(echo "$TARGET" | cut -d':' -f1)
    EXPLICIT_PORT=$(echo "$TARGET" | grep ':' | cut -d':' -f2)

    # Determine connection port and OpenSSL starttls option
    STARTTLS_CMD=()

    case "$SCHEME" in
        starttls)
            PORT=${EXPLICIT_PORT:-25}
            STARTTLS_CMD=(-starttls smtp)
            ;;
        smtps)
            PORT=${EXPLICIT_PORT:-465}
            ;;
        pop3s|pops)
            PORT=${EXPLICIT_PORT:-995}
            ;;
        imaps)
            PORT=${EXPLICIT_PORT:-993}
            ;;
        ldaps)
            PORT=${EXPLICIT_PORT:-636}
            ;;
        mqtts)
            PORT=${EXPLICIT_PORT:-8883}
            ;;
        sips)
            PORT=${EXPLICIT_PORT:-5061}
            ;;
        ircs)
            PORT=${EXPLICIT_PORT:-6697}
            ;;
        ftps)
            PORT=${EXPLICIT_PORT:-990}
            ;;
        http|https)
            PORT=${EXPLICIT_PORT:-443}
            ;;
        *)
            PORT=${EXPLICIT_PORT:-443}
            ;;
    esac

    # Strip existing brackets if provided in OVERRIDE_IP
    CLEAN_IP="${OVERRIDE_IP#[}"
    CLEAN_IP="${CLEAN_IP%]}"

    # Determine network target (Override IP or Hostname)
    CONNECT_HOST="${CLEAN_IP:-$HOST}"

    # Format IP connection string for openssl s_client (IPv6 needs brackets [addr]:port)
    if [ -n "$CLEAN_IP" ] && [[ "$CLEAN_IP" =~ : ]]; then
        CONNECT_TARGET="[${CLEAN_IP}]:${PORT}"
        CURL_RESOLVE_IP="[${CLEAN_IP}]"
    else
        CONNECT_TARGET="${CONNECT_HOST}:${PORT}"
        CURL_RESOLVE_IP="${CLEAN_IP}"
    fi

    # Set up OpenSSL/curl IP flags
    OPENSSL_IP_FLAG=""
    CURL_IP_FLAG=""
    if [ -n "$IP_VERSION_FLAG" ]; then
        OPENSSL_IP_FLAG="$IP_VERSION_FLAG"
        CURL_IP_FLAG="$IP_VERSION_FLAG"
    fi

    # If URL ends in a common cert extension, fetch directly via curl
    if [[ "$INPUT" =~ \.(pem|crt|cer|der)$ ]]; then
        log "[+] Downloading certificate file from URL via curl..."
        CURL_ARGS=(-s -L)
        if [ -n "$CURL_IP_FLAG" ]; then
            CURL_ARGS+=("$CURL_IP_FLAG")
        fi
        if [ -n "$CLEAN_IP" ]; then
            CURL_ARGS+=(--resolve "${HOST}:${PORT}:${CURL_RESOLVE_IP}")
        fi

        CONNECTED_IP=$(curl "${CURL_ARGS[@]}" -w "%{remote_ip}" "$INPUT" -o "$TMP_DIR/downloaded_raw" 2>/dev/null)
        if [ $? -ne 0 ] || [ ! -s "$TMP_DIR/downloaded_raw" ]; then
            echo "Error: Failed to download certificate from $INPUT" >&2
            exit 1
        fi

        # Convert DER to PEM if needed
        openssl x509 -in "$TMP_DIR/downloaded_raw" -out "$CERT_FILE" 2>/dev/null || \
        openssl x509 -inform DER -in "$TMP_DIR/downloaded_raw" -out "$CERT_FILE" 2>/dev/null
    else
        # Retrieve server cert via OpenSSL
        log "[+] Fetching server certificate from ${SCHEME:-tls} endpoint (${CONNECT_TARGET}, SNI: ${HOST})..."
        OPENSSL_ARGS=(-connect "${CONNECT_TARGET}" -servername "$HOST")
        if [ -n "$OPENSSL_IP_FLAG" ]; then
            OPENSSL_ARGS+=("$OPENSSL_IP_FLAG")
        fi
        OPENSSL_ARGS+=("${STARTTLS_CMD[@]}")

        echo Q | openssl s_client "${OPENSSL_ARGS[@]}" 2>/dev/null | \
        openssl x509 -outform PEM > "$CERT_FILE" 2>/dev/null

        # If --ip was not provided, determine the resolved IP
        if [ -n "$CLEAN_IP" ]; then
            CONNECTED_IP="$CLEAN_IP"
        elif [ "$SCHEME" = "http" ] || [ "$SCHEME" = "https" ]; then
            CURL_SCHEME="$SCHEME"
            CURL_IP_ARGS=(-s -o /dev/null -w "%{remote_ip}")
            if [ -n "$CURL_IP_FLAG" ]; then
                CURL_IP_ARGS+=("$CURL_IP_FLAG")
            fi
            CONNECTED_IP=$(curl "${CURL_IP_ARGS[@]}" "${CURL_SCHEME}://${HOST}:${PORT}" 2>/dev/null)
        else
            # For non-HTTP services like LDAPS, resolve IP address using standard tools
            if command -v getent >/dev/null 2>&1; then
                CONNECTED_IP=$(getent ahosts "$HOST" 2>/dev/null | awk '{print $1; exit}')
            elif command -v host >/dev/null 2>&1; then
                CONNECTED_IP=$(host "$HOST" 2>/dev/null | awk '/has address/ {print $4; exit}')
            elif command -v nslookup >/dev/null 2>&1; then
                CONNECTED_IP=$(nslookup "$HOST" 2>/dev/null | awk '/^Address: / {print $2; exit}')
            fi
        fi
    fi
fi

# Fallback connected IP if manual override was supplied
CONNECTED_IP="${CONNECTED_IP:-$CLEAN_IP}"

# Verify the certificate payload was successfully parsed
if [ ! -s "$CERT_FILE" ] || ! openssl x509 -in "$CERT_FILE" -noout 2>/dev/null; then
    echo "Error: Failed to obtain a valid X.509 certificate from '$INPUT'." >&2
    exit 1
fi

# Step 2: Extract Certificate Metadata
SUBJECT_RAW=$(openssl x509 -in "$CERT_FILE" -noout -subject -nameopt RFC2253 | sed 's/^subject=//')
ISSUER_RAW=$(openssl x509 -in "$CERT_FILE" -noout -issuer -nameopt RFC2253 | sed 's/^issuer=//')

SUBJECT_CN=$(echo "$SUBJECT_RAW" | grep -o 'CN=[^,]*' | cut -d'=' -f2)
ISSUER_CN=$(echo "$ISSUER_RAW" | grep -o 'CN=[^,]*' | cut -d'=' -f2)

# Extract and convert dates to ISO 8601 (1970-01-01T00:00:00Z format)
NOT_BEFORE_RAW=$(openssl x509 -in "$CERT_FILE" -noout -startdate | cut -d'=' -f2)
NOT_AFTER_RAW=$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d'=' -f2)

NOT_BEFORE=$(date -u -d "$NOT_BEFORE_RAW" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -j -f "%b %e %H:%M:%S %Y %Z" "$NOT_BEFORE_RAW" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$NOT_BEFORE_RAW")
NOT_AFTER=$(date -u -d "$NOT_AFTER_RAW" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -j -f "%b %e %H:%M:%S %Y %Z" "$NOT_AFTER_RAW" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$NOT_AFTER_RAW")

# Collect Subject Alternative Names (SANs)
SANS_LIST=()
SANS_RAW=$(openssl x509 -in "$CERT_FILE" -noout -ext subjectAltName 2>/dev/null | grep -A 1 "Subject Alternative Name" | tail -n 1)
if [ -n "$SANS_RAW" ]; then
    while IFS= read -r san; do
        san_clean=$(echo "$san" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^DNS://' -e 's/^IP Address://')
        if [ -n "$san_clean" ]; then
            SANS_LIST+=("$san_clean")
        fi
    done < <(echo "$SANS_RAW" | tr ',' '\n')
fi

# Deduplicate SANs list while preserving order
UNIQUE_SANS=()
for name in "${SANS_LIST[@]}"; do
    skip=0
    for u in "${UNIQUE_SANS[@]}"; do
        if [ "$u" = "$name" ]; then
            skip=1
            break
        fi
    done
    if [ "$skip" -eq 0 ]; then
        UNIQUE_SANS+=("$name")
    fi
done

# Collect combined CN + SAN list for standard mode
NAMES_LIST=()
if [ -n "$SUBJECT_CN" ]; then
    NAMES_LIST+=("$SUBJECT_CN")
fi
NAMES_LIST+=("${UNIQUE_SANS[@]}")

UNIQUE_NAMES=()
for name in "${NAMES_LIST[@]}"; do
    skip=0
    for u in "${UNIQUE_NAMES[@]}"; do
        if [ "$u" = "$name" ]; then
            skip=1
            break
        fi
    done
    if [ "$skip" -eq 0 ]; then
        UNIQUE_NAMES+=("$name")
    fi
done

SERIAL=$(openssl x509 -in "$CERT_FILE" -noout -serial | cut -d'=' -f2 | tr '[:upper:]' '[:lower:]')
SPACE_SEPARATED_NAMES="${UNIQUE_NAMES[*]}"

if [ "$ONLY_SANS" -eq 1 ]; then
    echo "$SPACE_SEPARATED_NAMES"
    exit 0
fi

log "[+] Connected IP: ${CONNECTED_IP:-N/A}"
log "[+] Subject: ${SUBJECT_RAW:-N/A}"
log "[+] Subject CN: ${SUBJECT_CN:-N/A}"
log "[+] Issuer: ${ISSUER_RAW:-N/A}"
log "[+] Issuer CN: ${ISSUER_CN:-N/A}"
log "[+] Valid Dates: $NOT_BEFORE to $NOT_AFTER"
log "[+] Certificate Serial Number: $SERIAL"
log "[+] CN and Subject Alt Names (Line-Separated):"
for name in "${UNIQUE_NAMES[@]}"; do
    log "    - $name"
done
log "[+] CN and Subject Alt Names (Space-Separated): $SPACE_SEPARATED_NAMES"

if [ "$PRINT_CRT" -eq 1 ] && [ "$OUTPUT_JSON" -eq 0 ]; then
    log "[+] PEM Encoded Certificate:"
    cat "$CERT_FILE"
fi

# Step 3: Extract the CRL URL from the X509v3 CRL Distribution Points extension
CRL_URL=$(openssl x509 -in "$CERT_FILE" -noout -text | grep -A 4 "CRL Distribution Points" | grep -Eo 'http(s)?://[^"]+' | head -n 1)

CRL_SIZE_BYTES=0
TOTAL_ENTRIES=0
CRT_IN_CRL="false"
EXIT_CODE=0

if [ -n "$CRL_URL" ]; then
    log "[+] Found CRL URL: $CRL_URL"

    # Step 4: Fetch the CRL (only if -c/--crl is active)
    if [ "$CHECK_CRL" -eq 1 ]; then
        TMP_CRL="$TMP_DIR/target_crl.crl"
        log "[+] Fetching CRL..."
        CRL_CURL_ARGS=(-s -L)
        if [ -n "$CURL_IP_FLAG" ]; then
            CRL_CURL_ARGS+=("$CURL_IP_FLAG")
        fi

        if curl "${CRL_CURL_ARGS[@]}" "$CRL_URL" -o "$TMP_CRL"; then
            # Step 5: Get CRL File Metadata & Parse Text
            if [ -f "$TMP_CRL" ]; then
                CRL_SIZE_BYTES=$(wc -c < "$TMP_CRL" | tr -d ' ')
            fi

            log "[+] Parsing CRL and searching for serial number..."

            if ! CRL_TEXT=$(openssl crl -inform DER -in "$TMP_CRL" -text -noout 2>/dev/null); then
                CRL_TEXT=$(openssl crl -inform PEM -in "$TMP_CRL" -text -noout 2>/dev/null)
            fi

            if [ -n "$CRL_TEXT" ]; then
                TOTAL_ENTRIES=$(echo "$CRL_TEXT" | grep -c -i "Serial Number:")
                log "[+] Total Revoked Entries in CRL: $TOTAL_ENTRIES"

                # Step 6: Match serial number against CRL and extract entry details
                CLEAN_SERIAL="${SERIAL#"${SERIAL%%[!0]*}"}"
                REV_DETAILS=$(echo "$CRL_TEXT" | grep -i -A 4 -E "Serial Number: (0*)?${CLEAN_SERIAL}$")

                if [ -n "$REV_DETAILS" ]; then
                    CRT_IN_CRL="true"
                    EXIT_CODE=2
                    REV_DATE=$(echo "$REV_DETAILS" | grep -i "Revocation Date:" | head -n 1 | sed 's/^[[:space:]]*Revocation Date:[[:space:]]*//')
                    REV_REASON=$(echo "$REV_DETAILS" | grep -A 1 "CRL Reason Code:" | tail -n 1 | sed 's/^[[:space:]]*//')

                    log "[+] Certificate with serial $SERIAL IS REVOKED"
                    log "[+] Revocation Date: ${REV_DATE:-Unknown}"
                    if [ -n "$REV_REASON" ] && [[ ! "$REV_REASON" =~ "Revocation Date" ]]; then
                        log "[+] Reason Code: $REV_REASON"
                    fi
                else
                    log "[+] Certificate with serial $SERIAL is not in revocation list"
                fi
            else
                if [ "$OUTPUT_JSON" -eq 0 ]; then
                    echo "Error: Unable to parse downloaded CRL with OpenSSL." >&2
                    exit 1
                fi
            fi
        else
            if [ "$OUTPUT_JSON" -eq 0 ]; then
                echo "Error: Failed to download CRL from $CRL_URL" >&2
                exit 1
            fi
        fi
    fi
else
    if [ "$CHECK_CRL" -eq 1 ] && [ "$OUTPUT_JSON" -eq 0 ]; then
        echo "Error: No HTTP/HTTPS CRL Distribution Point found in certificate." >&2
        exit 1
    fi
fi

# Step 7: Output JSON if requested
if [ "$OUTPUT_JSON" -eq 1 ]; then
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: 'jq' command not found. Please install jq to use --json." >&2
        exit 1
    fi

    # Build base JSON object
    BASE_JSON=$(jq -n -S \
      --arg timestamp "$EXECUTION_TIMESTAMP" \
      --arg ip "$CONNECTED_IP" \
      --arg issuer "$ISSUER_RAW" \
      --arg issuer_cn "$ISSUER_CN" \
      --arg not_before "$NOT_BEFORE" \
      --arg not_after "$NOT_AFTER" \
      --arg serial "$SERIAL" \
      --arg subject "$SUBJECT_RAW" \
      --arg subject_cn "$SUBJECT_CN" \
      --arg crl "$CRL_URL" \
      --argjson crl_file_size "$CRL_SIZE_BYTES" \
      --argjson crl_entries "$TOTAL_ENTRIES" \
      --argjson crt_in_crl "$CRT_IN_CRL" \
      --argjson check_crl "$CHECK_CRL" \
      '
      {
        timestamp: $timestamp,
        ip: $ip,
        issuer: $issuer,
        issuer_cn: $issuer_cn,
        not_before: $not_before,
        not_after: $not_after,
        serial: $serial,
        subject: $subject,
        subject_cn: $subject_cn,
        subject_alt_names: $ARGS.positional
      }
      + if $check_crl == 1 then {
        crl: $crl,
        crl_file_size: $crl_file_size,
        crl_entries: $crl_entries,
        crt_in_crl: $crt_in_crl
      } else {} end
      ' --args "${UNIQUE_SANS[@]}")

    # Optionally add 'crt' key only when --print-crt is specified
    if [ "$PRINT_CRT" -eq 1 ]; then
        CRT_CONTENT=$(cat "$CERT_FILE")
        jq -S --arg crt "$CRT_CONTENT" '. + {crt: $crt}' <<< "$BASE_JSON"
    else
        echo "$BASE_JSON"
    fi

    exit $EXIT_CODE
fi

exit $EXIT_CODE
