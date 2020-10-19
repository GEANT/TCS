# TCS

Helper scripts for
[GÉANT TCS (Trusted Certificate
Service)](https://www.geant.org/Services/Trust_identity_and_security/Pages/TCS.aspx).


# genx509.sh

Generates a private key, and either a corresponding Certificate Signing
Request, or a self-signed certificate.
The output is sent to `stdout` to prevent key materials from leaking to disk,
and to allow copy/pasting into more secure storage such as HashiCorp Vault,
ansible vault, hiera-eyaml, etc.

The first argument is cn (Common Name).
Optional further arguments are treated as Subject Altenative Names.

## Example: create an ECC private key and Certificate Signing Request

```sh
dnmvisser@NUC8i5BEK TCS$ ./genx509.sh www.uni.edu www.uni.edu www.uni.org
Select generation type
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
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgO1PhIaqkzNMZ7//h
hyown2feBkY4GDWVxg63svoiSAehRANCAASIg2T3Ix8M8cekQAY2m+KPv/3naG5U
MWq8eBDsZMm8IeiQAAbauIlIfaySwaoo2jhSsBpc4ORZq0RpJiPzb8K0
-----END PRIVATE KEY-----
-----BEGIN CERTIFICATE REQUEST-----
MIIBFTCBuwIBADAWMRQwEgYDVQQDDAt3d3cudW5pLmVkdTBZMBMGByqGSM49AgEG
CCqGSM49AwEHA0IABIiDZPcjHwzxx6RABjab4o+//edoblQxarx4EOxkybwh6JAA
Btq4iUh9rJLBqijaOFKwGlzg5FmrRGkmI/NvwrSgQzBBBgkqhkiG9w0BCQ4xNDAy
MDAGA1UdEQQpMCeCC3d3dy51bmkuZWR1ggt3d3cudW5pLmVkdYILd3d3LnVuaS5v
cmcwCgYIKoZIzj0EAwIDSQAwRgIhAL6bGP35cu2ARg2THoW46ZEXyGDeCLtTsb4F
zlqBRt8lAiEAweFgBxXFIs2/S5m+8CtRsbZhICq4dZopuzXgvHxofNY=
-----END CERTIFICATE REQUEST-----
```

Use this CSR to get a signed certificate from your certificate provider.


## Example 2: create a self-signed key pair for a SAML Service Provider

```sh
dnmvisser@NUC8i5BEK TCS$ ./genx509.sh "My first SAML service"
Select generation type
1) CA-signed *
2) Self-signed
#? 2
Select key type
1) RSA *
2) ECC
#? 
Select RSA size
1) 2048 *
2) 3072
3) 4096
#? 
-----BEGIN PRIVATE KEY-----
MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQC7TipE9MIH/OWN
SCDdA8m3Uw1o6MEurWtH3XzjjQaIm+oCWVoP4uOW4vebJZnpkdtFSwoEJtsHbpm/
UWcRvaMhPbQPO7OyHPfmN2KcdnEDVdwMV0ZcN0eqHG9FUBs/5rsiF4veF38JlLDX
X4TTYx/fqhJEq4KJHYG7m+oTVmlVzmdaZLyXyCD69hGG3Qgg3bSbmWU4INlzEa/C
ekZBkTUb9Gscuno/l/bYLtV1YIWiidmOey7WSC4BMS2A5g5LCRzUet7Uo5sG9ltH
7j+tUZElIDNmuw/w6gBvRu/4Yop+VYutcGgL8LCyh3JbpHndeFa+HsG968cEw32k
y7nFPUiLAgMBAAECggEAP1kHWL0C5pq0tFzBqJ5AWb1AGswlkfjbALo7I+atYASD
V3oKyLauzHhEz/cen+1RoJTpdVAC4feZDiik2E4v3u00ebZyZvn/KaBvvIUeYcdn
HdFinYugtDrbszCNlsYdYkFeb6W4tG/Sg3TtwmSTAh1OAmWTR3ZwSxhHSXT/OSJ6
MMmqN8oZgwoABWm+vCQE4uZwGp6nDGZR9LS33AIh6XU8II4JNCJVKbFqu1KjzYnG
FQhUGnGl/MLV4Go9+U3ZmdXnew1aaHiVLPTMOnNa6SsEKw4+JTMTbyts3gip5zvH
U3kF4ETOdiqtRoOdB2A2ueDNG1HNeZcQv3wK6m3mwQKBgQDr2zFxncZReFkaspkW
YhY0p5L93jZnDGqZqJWHN2VYgU8D0D0W6Pz6BT7BgbNmczCljoJPOEipQ44wT6GB
PZGZ3TB5MqSnEw4I3/xgFHeWhlCZrEgctS6EaSPjdja4uXk+ET3dcjIJ1C0qRbcW
rACFZmOJra4Hf3Dju5ecn17aawKBgQDLTXIcoj+cGcgi69pJG9mWHjxOaihVj4jV
XVMe3v+dl+suJzGc7GBSsi0RNL5Cmx+8aoZ7ueHOvyzCLpNH9Kvs52F7NU2f3HM5
IQSmsz9YzW0xXTERbkh0Ck7YVT+DL4yXiYGDtqtAWnbubzJPX767YrWDe1rDcXNr
8rwJwxMSYQKBgQCGXaGVcKUC1OUuaID+V3L/HFiJeIbVviUc1QYaulxqR4CUU5X5
71Hvvf06kIF75DPanY1vRElg5LOkojkIP+MrHO/4m/lhlWFxfOlyczaN8ocIhTWv
5ShTFvLzKu2R31hLG9d6yQvovY/dfUoJCIRjeylJzkBO1TOjCcQd3k1TcQKBgQCa
GmlOFRpcbBqNhfPfiPHE3cReuA880+Enwmb4NpbR0U8em+z6gx58cLzClxVFDarf
umuYK41jlvwJcR6I44jSuYzlxMDDVWotur540dRJruV/DqHcEZlwBERBrVTITumm
EEARJAzpaelO0RD0o6HDDo6CTKW/Eicog0VPrQOu4QKBgQC9OM0fQ17YJpAMBlkk
wms745qJ35s92swQaMnOte3bjvMy3t24MLJtLwOk/+ljMmYdxHuVk+0Me6mJCpS3
ggySqH7pd9etnNvyqhVyywNK+c25K6vQEgJbiZzEeMboTuZroyd1MDemtwJFjgsJ
NG6voCBZFedXfDCxhnGdzoTJ0A==
-----END PRIVATE KEY-----
-----BEGIN CERTIFICATE-----
MIIDITCCAgmgAwIBAgIUMKPiIQs2wbsHtjWRDP2nvmOYxDgwDQYJKoZIhvcNAQEL
BQAwIDEeMBwGA1UEAwwVTXkgZmlyc3QgU0FNTCBzZXJ2aWNlMB4XDTIwMDcxMzIx
NDcwMloXDTMwMDcxMTIxNDcwMlowIDEeMBwGA1UEAwwVTXkgZmlyc3QgU0FNTCBz
ZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAu04qRPTCB/zl
jUgg3QPJt1MNaOjBLq1rR918440GiJvqAllaD+LjluL3myWZ6ZHbRUsKBCbbB26Z
v1FnEb2jIT20Dzuzshz35jdinHZxA1XcDFdGXDdHqhxvRVAbP+a7IheL3hd/CZSw
11+E02Mf36oSRKuCiR2Bu5vqE1ZpVc5nWmS8l8gg+vYRht0IIN20m5llOCDZcxGv
wnpGQZE1G/RrHLp6P5f22C7VdWCFoonZjnsu1kguATEtgOYOSwkc1Hre1KObBvZb
R+4/rVGRJSAzZrsP8OoAb0bv+GKKflWLrXBoC/CwsodyW6R53XhWvh7BvevHBMN9
pMu5xT1IiwIDAQABo1MwUTAdBgNVHQ4EFgQU3dl8VRN/9TCAqIjGdv+njcOEMBww
HwYDVR0jBBgwFoAU3dl8VRN/9TCAqIjGdv+njcOEMBwwDwYDVR0TAQH/BAUwAwEB
/zANBgkqhkiG9w0BAQsFAAOCAQEAj6Kw2ruLNiaXFS/eP+F7ZqKOhpQ+KIzMqPVH
I0Mm4+b/0zid3mIgsfC9jlfx2PFIHF9GwlP9udOkFzAZ6xE8ITVDyXLvvsCCkh7r
fJMWsNPPx01xoyvJyHEeUHWfSeiCZ10QpSFtTVTrXpFxrm4NHFP3Y43US6bQ6z+L
kv7OzRIxMRiDBXbw+QLUTov9+sj9DK7pBnBfzEw6216d9A6zqHC4bkvnFO2im+k7
BDcohttF4wrv6Di3UvdS0WkntEwtvirSC4eCpfba0s+tCDqcpGZjjUye5ZAl6g/S
YerhOD88muzC8va2r2tjpCOoJFW8nZTiye05BQI2pW/zqzilhQ==
-----END CERTIFICATE-----
```

# Example 3: Use an existing key to generate a new Certificate Signing Request

Assuming the key is encrypted, pipe the decrypted PEM formatted private key to
STDIN of the script:

```
dnmvisser@NUC8i5BEK TCS$ ansible-vault view ~/git/ansible/certs/uni.key.pem |
  ./genx509.sh www.uni.edu www.uni.edu www.uni.org www2.uni.edu
Select signing type
1) CA-signed *
2) Self-signed
#? 
-----BEGIN CERTIFICATE REQUEST-----
MIIBIjCByQIBADAWMRQwEgYDVQQDDAt3d3cudW5pLmVkdTBZMBMGByqGSM49AgEG
CCqGSM49AwEHA0IABEvfacCBszcm4fZymwlmXsAtpwe2c39ghMzU71RBJu8fNvXI
yvpU6/Se8nDLb2EitGh/s1Y5ESuEBPuUv1p6YqSgUTBPBgkqhkiG9w0BCQ4xQjBA
MD4GA1UdEQQ3MDWCC3d3dy51bmkuZWR1ggt3d3cudW5pLmVkdYILd3d3LnVuaS5v
cmeCDHd3dzIudW5pLmVkdTAKBggqhkjOPQQDAgNIADBFAiBk1SFW5EHOcBYlx3oK
ofihX9a4WC6Tjd52wWa/ddxsxAIhAL8AjbF8yZC0Ul9waPQzxoc0QqndNcFNOPas
QXhLwZeE
-----END CERTIFICATE REQUEST-----
```
