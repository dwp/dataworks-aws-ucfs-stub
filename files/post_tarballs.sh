#!/bin/bash

echo "Retrieving Synthetic Tarballs..."
aws s3 sync s3://${s3_input_bucket}/${s3_input_prefix} /srv/data/export

echo "Sending tarballs to ingestion server"
MINIO_ACCESS_KEY=$(aws secretsmanager get-secret-value --secret-id minio --query SecretString --output text | jq -r .MINIO_ACCESS_KEY)
MINIO_SECRET_KEY=$(aws secretsmanager get-secret-value --secret-id minio --query SecretString --output text | jq -r .MINIO_SECRET_KEY)
today=$(date "+%Y-%m-%d")
AWS_CA_BUNDLE=/etc/pki/tls/certs/ca-bundle.crt aws --endpoint https://${tarball_ingester_s3_endpoint} s3 sync /srv/data/export s3://${tarball_ingester_s3_bucket}/$today/
