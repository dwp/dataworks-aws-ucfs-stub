#!/bin/bash

# Force LC update when any of these files are changed
echo "${s3_file_stub_ucfs_export_server_logrotate}" > /dev/null
echo "${s3_file_stub_ucfs_export_server_cloudwatch_sh}" > /dev/null
echo "${s3_file_stub_ucfs_export_server_post_tarballs_sh}" > /dev/null

export AWS_DEFAULT_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | cut -d'"' -f4)

/etc/init.d/awsagent stop
sleep 5
/etc/init.d/awsagent start

echo "Configuring startup scripts paths"
S3_URI_LOGROTATE="s3://${s3_scripts_bucket}/${s3_file_stub_ucfs_export_server_logrotate}"
S3_CLOUDWATCH_SHELL="s3://${s3_scripts_bucket}/${s3_file_stub_ucfs_export_server_cloudwatch_sh}"
S3_POST_TARBALLS="s3://${s3_scripts_bucket}/${s3_file_stub_ucfs_export_server_post_tarballs_sh}"

echo "Configuring startup file paths"
mkdir -p /opt/stub_ucfs_export_server/

echo "Installing startup scripts"
aws s3 cp "$S3_URI_LOGROTATE"          /etc/logrotate.d/stub_ucfs_export_server
aws s3 cp "$S3_CLOUDWATCH_SHELL"       /opt/stub_ucfs_export_server/stub_ucfs_export_server_cloudwatch.sh
aws s3 cp "$S3_POST_TARBALLS"          /opt/stub_ucfs_export_server/post_tarballs.sh

echo "Allow shutting down"
echo "stub_ucfs_export_server     ALL = NOPASSWD: /sbin/shutdown -h now" >> /etc/sudoers

echo "Creating directories"
mkdir -p /var/log/stub_ucfs_export_server
mkdir -p /srv/data/export

echo "Creating user dip_export"
useradd dip_export -m -s /sbin/nologin


echo "Setup cloudwatch logs"
chmod u+x /opt/stub_ucfs_export_server/stub_ucfs_export_server_cloudwatch.sh
/opt/stub_ucfs_export_server/stub_ucfs_export_server_cloudwatch.sh \
"${cwa_metrics_collection_interval}" "${cwa_namespace}" "${cwa_cpu_metrics_collection_interval}" \
"${cwa_disk_measurement_metrics_collection_interval}" "${cwa_disk_io_metrics_collection_interval}" \
"${cwa_mem_metrics_collection_interval}" "${cwa_netstat_metrics_collection_interval}" "${cwa_log_group_name}" \
"$AWS_DEFAULT_REGION"

echo "${environment_name}" > /opt/stub_ucfs_export_server/environment

export HTTP_PROXY="http://${internet_proxy}:3128"
export HTTPS_PROXY="$HTTP_PROXY"
export NO_PROXY="${non_proxied_endpoints}"

echo "Configure AWS Inspector"
cat > /etc/init.d/awsagent.env << AWSAGENTPROXYCONFIG
export HTTPS_PROXY=$HTTPS_PROXY
export HTTP_PROXY=$HTTP_PROXY
export NO_PROXY=$NO_PROXY
AWSAGENTPROXYCONFIG

# Retrieve certificates
ACM_KEY_PASSWORD=$(uuidgen -r)

echo "Retrieving acm certs"
acm-cert-retriever \
--acm-cert-arn "${acm_cert_arn}" \
--acm-key-passphrase "$ACM_KEY_PASSWORD" \
--private-key-alias "${private_key_alias}" \
--truststore-aliases "${truststore_aliases}" \
--truststore-certs "${truststore_certs}" >> /var/log/acm-cert-retriever.log 2>&1

unset HTTPS_PROXY HTTP_PROXY NO_PROXY
echo "Changing permissions"
chown dip_export:dip_export -R  /opt/stub_ucfs_export_server /var/log/stub_ucfs_export_server /srv/data/export

if [[ "${environment_name}" != "production" ]]; then
echo "Running script to post synthetic tarballs to endpoint"
chmod u+x /opt/stub_ucfs_export_server/post_tarballs.sh
su -s /bin/bash -c '/opt/stub_ucfs_export_server/post_tarballs.sh >> /var/log/stub_ucfs_export_server/stub_ucfs_export_server.out 2>&1' dip_export
fi
