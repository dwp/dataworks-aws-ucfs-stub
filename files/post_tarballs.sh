#!/bin/bash

echo "Retrieving Synthetic Tarballs..."
aws s3 sync s3://${s3_input_bucket}/${s3_input_prefix} /srv/data/export

export AWS_DEFAULT_REGION=eu-west-2
aws configure set default.s3.signature_version s3v4

echo "Obtaining MinIO Credentials..."
export MINIO_ACCESS_KEY_ID=$(aws secretsmanager get-secret-value --secret-id minio --query SecretString --output text | jq -r .MINIO_ACCESS_KEY)
export MINIO_SECRET_ACCESS_KEY=$(aws secretsmanager get-secret-value --secret-id minio --query SecretString --output text | jq -r .MINIO_SECRET_KEY)
export AWS_ACCESS_KEY_ID=${MINIO_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${MINIO_SECRET_ACCESS_KEY}

echo "Sending tarballs to ingestion server..."
today=$(date "+%Y-%m-%d")
AWS_CA_BUNDLE=/etc/pki/tls/certs/ca-bundle.crt aws --endpoint https://${tarball_ingester_s3_endpoint} s3 sync /srv/data/export s3://${tarball_ingester_s3_bucket}/$today/
