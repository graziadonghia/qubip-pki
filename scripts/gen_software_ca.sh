#!/bin/bash

# This script automates the creation of the QUBIP PKI

# Set variables for directory structure
cd ..
CA="qubip-software-ca"
ROOT_CA="qubip-root-ca"
WORKING_DIR=$(pwd)
CA_DIR="$WORKING_DIR/certs"
ROOT_CA_DIR="$CA_DIR/$ROOT_CA"
SOFTWARE_CA_DIR="$CA_DIR/$CA"
CA_PRIVATE_DIR="$SOFTWARE_CA_DIR/private"
DB_DIR="$SOFTWARE_CA_DIR/db"
CONF_DIR="$WORKING_DIR/etc"
CONF_FILE="$CONF_DIR/$CA.conf"
ROOT_CONF_FILE="$CONF_DIR/$ROOT_CA.conf"
CSR_FILE="$SOFTWARE_CA_DIR/$CA.csr"
KEY_FILE="$CA_PRIVATE_DIR/$CA.key"
ROOT_CRT_FILE="$ROOT_CA_DIR/$ROOT_CA-cert.pem"
CHAIN_FILE="$SOFTWARE_CA_DIR/$CA-chain.pem"
CRT_FILE="$SOFTWARE_CA_DIR/$CA-cert.pem"
EXTENSIONS="signing_ca_ext"
CRL_DIR="$SOFTWARE_CA_DIR/crl"
CRL="$CRL_DIR/$CA.crl"
CERTS_DIR="$SOFTWARE_CA_DIR/newcerts"
PASS_FILE="$CA_PRIVATE_DIR/.$CA-passphrase.txt"
# Create necessary directories

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <algorithm>"
    exit 1
fi

echo -e "----------CREATE SOFTWARE CA--------------\n"
echo "Creating necessary directories..."
cd $WORKING_DIR
mkdir -p "$CA_PRIVATE_DIR" "$DB_DIR" "$CERTS_DIR" "$CRL_DIR"
chmod 700 $CA_PRIVATE_DIR

# Create database files
echo -e "Creating database files...\n"
touch "$DB_DIR/$CA.db"
echo "01" > "$DB_DIR/$CA.crt.srl"
echo "01" > "$DB_DIR/$CA.crl.srl"

echo "Generating CA private key and CSR..."
openssl rand -base64 32 > $PASS_FILE # generate a random passphrase to encrypt key
openssl genpkey -algorithm $1 -aes-256-cbc -out $KEY_FILE -pass file:$PASS_FILE
openssl req -new \
    -key $KEY_FILE \
    -passin file:$PASS_FILE \
    -sha256 \
    -config $CONF_FILE \
    -out $CSR_FILE

# Check if the CSR was created successfully
if [[ -f "$CSR_FILE" ]]; then
    echo "Successfully created SOFTWARE CA CSR: $CSR_FILE"
else
    echo "Failed to create SOFTWARE CA CSR!"
    exit 1
fi

# Generate certificate
echo -e "\nCreating SOFTWARE CA certificate issued by Root CA..."

openssl ca  \
    -config $ROOT_CONF_FILE \
    -keyfile $ROOT_CA_DIR/private/$ROOT_CA.key \
    -passin file:$ROOT_CA_DIR/private/.$ROOT_CA-passphrase.txt \
    -cert $ROOT_CRT_FILE \
    -in $CSR_FILE \
    -out $CRT_FILE \
    -extensions $EXTENSIONS \
    -days 7305 \
    -batch

# Check if the certificate was created successfully
if [[ -f "$CRT_FILE" ]]; then
    echo "Successfully created SOFTWARE CA certificate: $CRT_FILE"
else
    echo "Failed to create SOFTWARE CA certificate!"
    exit 1
fi

# Generate initial CRL
echo -e "Creating initial CRL..."
openssl ca -gencrl \
    -config $CONF_FILE \
    -out $CRL \
    -keyfile $KEY_FILE \
    -passin file:$PASS_FILE
# Check if the CRL was created successfully
if [[ -f "$CRL" ]]; then
    echo "Successfully created SOFTWARE CA CRL: $CRL"
else
    echo "Failed to create SOFTWARE CA CRL!"
    exit 1
fi
# Print completion message
echo "QUBIP SOFTWARE CA setup completed successfully!"
echo "---------------------------------"
echo "SOFTWARE CA Key: $KEY_FILE"
echo "SOFTWARE CA CSR: $CSR_FILE"
echo "SOFTWARE CA Certificate: $CRT_FILE"
echo "SOFTWARE CA Initial CRL: $CRL"
echo "---------------------------------"

echo -e "\nIn order to be published, certificates and CRLs must be converted to DER format"

echo "Converting certificate to DER format..."

openssl x509 \
    -in "$CRT_FILE" \
    -out "${CRT_FILE}.der" \
    -outform der

if [[ $? -eq 0 ]]; then
    echo "Certificate successfully converted to DER format."
else
    echo "Error converting certificate to DER format."
fi

echo "Converting CRL to DER format..."

openssl crl \
    -in "$CRL" \
    -out "${CRL}.der" \
    -outform der

if [[ $? -eq 0 ]]; then
    echo "CRL successfully converted to DER format."
else
    echo "Error converting CRL to DER format."
fi

echo -e "\n\nGenerating certifiate chain file\n"
cat $CRT_FILE $ROOT_CRT_FILE > \
    $CHAIN_FILE
cat ${CRT_FILE}.der ${ROOT_CRT_FILE}.der > \
    ${CHAIN_FILE}.der

echo -e "\n\nDone."

# Exit script
exit 0
