# TCS

Helper scripts for
[GÉANT TCS (Trusted Certificate
Service)](https://security.geant.org/trusted-certificate-services/).


# genx509.sh

```console
Usage: genx509.sh <common_name> [san_1 san_2 ... san_n]

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
  genx509.sh www.uni.edu uni.edu old_uni.edu

  # Reuse an existing private key via STDIN:
  cat privkey.pem | genx509.sh www.uni.edu uni.old other.tld

  # Extract a private key from Ansible Vault and pass via STDIN:
  ansible-vault view privkey.vault | genx509.sh www.uni.edu uni.old other.tld

  # Extract a private key from a vaulted YAML file using yq:
  ansible-vault view vault.yml | yq -r .privkey | genx509.sh www.uni.edu uni.old other.tld

  # Generate a self-signed key pair (e.g., for a SAML Service Provider):
  genx509.sh 'My Service Provider'
```


# cert-info.sh

```console
Usage: cert-info.sh [OPTIONS] [TARGET]

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
  cat cert.pem | ./cert-info.sh
  cat cert.pem | ./cert-info.sh -

  # Output details as structured JSON
  ./cert-info.sh --json www.geant.org
  ./cert-info.sh -j -c www.geant.org

  # Force connection using IPv4 or IPv6
  ./cert-info.sh -4 www.geant.org
  ./cert-info.sh -6 www.geant.org

  # Print certificate details along with the PEM certificate
  ./cert-info.sh --print-crt www.geant.org

  # Inspect using various protocol schemes
  ./cert-info.sh imaps://imap.domain.com
  ./cert-info.sh pop3s://pop.domain.com
  ./cert-info.sh ldaps://ldap.domain.com:636
  ./cert-info.sh ftps://ftp.domain.com

  # Override IP connection endpoint with IPv4 or IPv6
  ./cert-info.sh --ip 192.168.1.50 www.geant.org
  ./cert-info.sh --ip 2001:db8::1 www.geant.org

  # Print only CN and SANs space-separated on a single line
  ./cert-info.sh --only-sans www.geant.org

  # Print certificate details AND check CRL revocation status
  ./cert-info.sh -c www.geant.org
  ./cert-info.sh --crl /etc/ssl/certs/server.pem

EXIT CODES:
  0 - Success (Certificate valid, or NOT revoked when -c is specified)
  1 - Error encountered (missing file, network failure, missing CRL)
  2 - Certificate IS revoked (when -c is specified)
```


