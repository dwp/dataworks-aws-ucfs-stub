#!/bin/bash

echo "Retrieving Synthetic Tarballs..."
aws s3 sync s3://${s3_input_bucket}/${s3_input_prefix} /srv/data/export

echo "Sending tarballs to ingestion server"
today=$(date "+%Y-%m-%d")
aws --endpoint https://${tarball_ingester_s3_endpoint} s3 sync /srv/data/export s3://${tarball_ingester_s3_bucket}/$today/
