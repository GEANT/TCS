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

Example session:

```console
debian@forky ~$ ./genx509.sh www.uni.edu uni.edu old_uni.edu
Select signing type
1) CA-signed *
2) Self-signed
#?
Select key type
1) ECC *
2) RSA
#?
Select curve
1) prime256v1 *
2) secp384r1
#?
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgajvTMgMxQGOzOUAI
eCqLxlfLfR0G+JqLeVIpmPtat32hRANCAAQH33l3ULu8RggqODX781UwzaL2cweB
c1lyLnhFJEEnCVcEz8+dOH5SgGgJ99//ZP3Z1NcvAMpqna/1BRyFOtGw
-----END PRIVATE KEY-----
-----
-----BEGIN CERTIFICATE REQUEST-----
MIIBAjCBqgIBADAWMRQwEgYDVQQDDAt3d3cudW5pLmVkdTBZMBMGByqGSM49AgEG
CCqGSM49AwEHA0IABAffeXdQu7xGCCo4NfvzVTDNovZzB4FzWXIueEUkQScJVwTP
z504flKAaAn33/9k/dnU1y8Aymqdr/UFHIU60bCgMjAwBgkqhkiG9w0BCQ4xIzAh
MB8GA1UdEQQYMBaCB3VuaS5lZHWCC29sZF91bmkuZWR1MAoGCCqGSM49BAMCA0cA
MEQCID6XrNmVbNbeCRVKLc86vt8OctIyhzfH0OPiGbYtLRBQAiAK2RRYJspGnYvT
8YyO+HtNDe1sNKxn4U3qhaaZtMtIyQ==
-----END CERTIFICATE REQUEST-----
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

Examples:

```console
debian@trixie ~$ ./cert-info.sh --crl -4 www.geant.org
[+] Fetching server certificate from https endpoint (www.geant.org:443, SNI: www.geant.org)...
[+] Connected IP: 162.159.135.42
[+] Subject: CN=www.geant.org
[+] Subject CN: www.geant.org
[+] Issuer: CN=GEANT TLS RSA 1,O=Hellenic Academic and Research Institutions CA,C=GR
[+] Issuer CN: GEANT TLS RSA 1
[+] Valid Dates: 2025-11-26T11:50:19Z to 2026-11-26T11:50:19Z
[+] Certificate Serial Number: 542bfb96e6dea4458696fad63454d6c2
[+] CN and Subject Alt Names (Line-Separated):
    - www.geant.org
    - xn--gant-bpa.org
    - educonf.geant.org
    - stage.geant.org
    - jobsboard.geant.org
    - itservices.geant.org
    - prod.geant.org
    - intranet.africaconnect2.net
    - intranet.geant.net
    - dev.geant.org
    - geant.org
    - intranet.geant.org
[+] CN and Subject Alt Names (Space-Separated): www.geant.org xn--gant-bpa.org educonf.geant.org stage.geant.org jobsboard.geant.org itservices.geant.org prod.geant.org intranet.africaconnect2.net intranet.geant.net dev.geant.org geant.org intranet.geant.org
[+] Found CRL URL: http://crl.harica.gr/HARICA-GEANT-TLS-R1.crl
[+] Fetching CRL...
[+] Parsing CRL and searching for serial number...
[+] Total Revoked Entries in CRL: 198607
[+] Certificate with serial 542bfb96e6dea4458696fad63454d6c2 is not in revocation list
```

```console
debian@forky ~$ ./cert-info.sh --crl -6 --print-crt www.geant.org --json
```
```json
{
  "crl": "http://crl.harica.gr/HARICA-GEANT-TLS-R1.crl",
  "crl_entries": 198607,
  "crl_file_size": 9580976,
  "crt": "-----BEGIN CERTIFICATE-----\nMIIHRDCCBaygAwIBAgIQVCv7lubepEWGlvrWNFTWwjANBgkqhkiG9w0BAQsFADBg\nMQswCQYDVQQGEwJHUjE3MDUGA1UECgwuSGVsbGVuaWMgQWNhZGVtaWMgYW5kIFJl\nc2VhcmNoIEluc3RpdHV0aW9ucyBDQTEYMBYGA1UEAwwPR0VBTlQgVExTIFJTQSAx\nMB4XDTI1MTEyNjExNTAxOVoXDTI2MTEyNjExNTAxOVowGDEWMBQGA1UEAwwNd3d3\nLmdlYW50Lm9yZzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALLeGIPv\n8P15nt6vOdHn0qOipwAa6vtUzBdh5L2SfhOf9wtx/jR/9ECkxsImTIOj3Ls/edRD\ncRvTqEBvQPXCvT8fUCK1yE8Yci7dDaNUz2jhG7AqIuFETVMlW7jcQLTyGkHlcHI7\nUjlx9W0kiDjeIhqVELqKaPa56gXTmD63Pbv9BjnLtnpFD+YIrS4G/Qp+7eXr/0SE\nYYxZjztpGnS9j3MNZM4gtdyltxapP2ZI3qT6yPOIA4sHvdaME2ps6dQSHl5tGgqw\nhk0Aqo+R/GYdyOLFfiBDd/Fa/nCOhBtWlb36HpnnpaI6QSea3b8KlGZKt7b3lWGj\nFUfxdcK+83CKcqECAwEAAaOCA8AwggO8MB8GA1UdIwQYMBaAFIYBcj+MqXDiMQZT\nFs4BX1t5yDw7MG8GCCsGAQUFBwEBBGMwYTA4BggrBgEFBQcwAoYsaHR0cDovL2Ny\ndC5oYXJpY2EuZ3IvSEFSSUNBLUdFQU5ULVRMUy1SMS5jZXIwJQYIKwYBBQUHMAGG\nGWh0dHA6Ly9vY3NwLXRscy5oYXJpY2EuZ3IwgeoGA1UdEQSB4jCB34INd3d3Lmdl\nYW50Lm9yZ4IQeG4tLWdhbnQtYnBhLm9yZ4IRZWR1Y29uZi5nZWFudC5vcmeCD3N0\nYWdlLmdlYW50Lm9yZ4ITam9ic2JvYXJkLmdlYW50Lm9yZ4IUaXRzZXJ2aWNlcy5n\nZWFudC5vcmeCDnByb2QuZ2VhbnQub3JnghtpbnRyYW5ldC5hZnJpY2Fjb25uZWN0\nMi5uZXSCEmludHJhbmV0LmdlYW50Lm5ldIINZGV2LmdlYW50Lm9yZ4IJZ2VhbnQu\nb3JnghJpbnRyYW5ldC5nZWFudC5vcmcwLQYDVR0gBCYwJDAIBgZngQwBAgEwCAYG\nBACPegEGMA4GDCsGAQQBgc8RAQEBATAdBgNVHSUEFjAUBggrBgEFBQcDAgYIKwYB\nBQUHAwEwPQYDVR0fBDYwNDAyoDCgLoYsaHR0cDovL2NybC5oYXJpY2EuZ3IvSEFS\nSUNBLUdFQU5ULVRMUy1SMS5jcmwwHQYDVR0OBBYEFBpwAX5W/vtona9d6nTh1LxX\nXkGcMA4GA1UdDwEB/wQEAwIFoDCCAX0GCisGAQQB1nkCBAIEggFtBIIBaQFnAHYA\nr2eIO1ewTt2Pptl+9i6o64EKx3Fg8CReVdYML+eFhzoAAAGawAk3ZwAABAMARzBF\nAiAdeTup4DY1Ynk+1ZpNiZaencOyPUtbvSSkvsuXrytAMAIhAMVq+kWptEdmQQJi\nYZjvV4AMi5myH8su6iCJF2X6RnKEAHUA2AlVO5RPev/IFhlvlE+Fq7D4/F6HVSYP\nFdEucrtFSxQAAAGawAk3PAAABAMARjBEAiA79iXbGtouLLAPzSA+feW4cGLWCBWn\n2VbkPvofv67cNgIgQSgfBo0DgQII2F9EZgf2TXE3dIoSGs7d08K6JCyIzwkAdgCs\nqzBwbOvshDH0E9L0kV8RHkIkQ7HypoxPPCs7px4CwwAAAZrACTduAAAEAwBHMEUC\nIQCAmJ4wkbKCsYpJ3RPBHpoeDZLKimSes9eTq/TglyE7ZwIgGZ1HPvOfx79D2XIV\n/oiW1YgrychH5/pYQicGIAkx/AIwDQYJKoZIhvcNAQELBQADggGBAHzS60j+VScI\nkU1aa6848xl3Qp5chgADCxlAu6MDfqiAXmG3y9HXFOHnVPfI0VcBotVSw5+hGNjr\nOUuadYyx/K6PRwdg0SMPX+eENAG2JAcDdlnszu61HpVcokdESM/qQ3loVOgVo+W8\naX9eOZXZp3lAPAto8IDlXSzcHPvlY5YgVpE/aHUyQ/zD7EZKfKoAcGvVzp5ZGbIn\ndIGUNoXCxYMXd0meEwv5L4t2avkH0kasXoNtTTdsBHxkxVduYZNRx+BEf1269RPv\nvRK4zFbmnzN3BuaXolHhkZkTDd8nBsDMXfl7bqncQSPgC9I6XkhszvyVrD+VU+Ad\nwdVntFLLs60eB6+RYjP0a7vrCcWXgHNB7l/nYCyESh9612GYaAlylX3EffVHjXTf\nVSa1BOffHRRO9OcEHD8/vpY23E7lzsBO83KWpTpG3aGM7Xep6bR/kKSMmju4v6bk\nQqzR0y+qpqj+xm7vrXR/CKrieaAH3DVZw3rfCSHlpOUGuGIVuPmZMg==\n-----END CERTIFICATE-----",
  "crt_in_crl": false,
  "ip": "2606:4700:7::a29f:872a",
  "issuer": "CN=GEANT TLS RSA 1,O=Hellenic Academic and Research Institutions CA,C=GR",
  "issuer_cn": "GEANT TLS RSA 1",
  "not_after": "2026-11-26T11:50:19Z",
  "not_before": "2025-11-26T11:50:19Z",
  "serial": "542bfb96e6dea4458696fad63454d6c2",
  "subject": "CN=www.geant.org",
  "subject_alt_names": [
    "www.geant.org",
    "xn--gant-bpa.org",
    "educonf.geant.org",
    "stage.geant.org",
    "jobsboard.geant.org",
    "itservices.geant.org",
    "prod.geant.org",
    "intranet.africaconnect2.net",
    "intranet.geant.net",
    "dev.geant.org",
    "geant.org",
    "intranet.geant.org"
  ],
  "subject_cn": "www.geant.org",
  "timestamp": "2026-07-29T14:08:58Z"
}
```

```console
debian@trixie ~$ ./cert-info.sh --crl --json perun.test.eduteams.org
```
```json
{
  "crl": "[http://crl.harica.gr/HARICA-GEANT-TLS-E1.crl](http://crl.harica.gr/HARICA-GEANT-TLS-E1.crl)",
  "crl_entries": 130861,
  "crl_file_size": 6356836,
  "ip": "2001:718:ff05:206::147",
  "issuer": "CN=GEANT TLS ECC 1,O=Hellenic Academic and Research Institutions CA,C=GR",
  "issuer_cn": "GEANT TLS ECC 1",
  "not_after": "2027-02-03T14:52:56Z",
  "not_before": "2026-07-19T14:52:57Z",
  "revocation_date": "2026-07-25T11:02:36Z",
  "revocation_reason": "Superseded",
  "revoked": true,
  "serial": "12fcc79b4e56a9650939c29288d0a1fe",
  "subject": "CN=*.test.eduteams.org",
  "subject_alt_names": [
    "*.test.eduteams.org",
    "test.eduteams.org"
  ],
  "subject_cn": "*.test.eduteams.org",
  "timestamp": "2026-07-29T14:53:41Z"
}
```
