#!/bin/bash

# Force LC update when any of these files are changed
echo "${s3_file_ucfs_server_stub_logrotate}" > /dev/null
echo "${s3_file_ucfs_server_stub_cloudwatch_sh}" > /dev/null

export AWS_DEFAULT_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | cut -d'"' -f4)
export INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)

export http_proxy="http://${internet_proxy}:3128"
export HTTP_PROXY="$http_proxy"
export https_proxy="$http_proxy"
export HTTPS_PROXY="$https_proxy"
export no_proxy="${non_proxied_endpoints}"
export NO_PROXY="$no_proxy"

echo "Configure AWS Inspector"
cat > /etc/init.d/awsagent.env << AWSAGENTPROXYCONFIG
export https_proxy=$https_proxy
export http_proxy=$http_proxy
export no_proxy=$no_proxy
AWSAGENTPROXYCONFIG

/etc/init.d/awsagent stop
sleep 5
/etc/init.d/awsagent start

echo "Configuring startup scripts paths"
S3_URI_LOGROTATE="s3://${s3_scripts_bucket}/${s3_file_ucfs_server_stub_logrotate}"
S3_CLOUDWATCH_SHELL="s3://${s3_scripts_bucket}/${s3_file_ucfs_server_stub_cloudwatch_sh}"

echo "Configuring startup file paths"
mkdir -p /opt/ucfs_server_stub/

echo "Installing startup scripts"
$(which aws) s3 cp "$S3_URI_LOGROTATE"          /etc/logrotate.d/ucfs_server_stub
$(which aws) s3 cp "$S3_CLOUDWATCH_SHELL"       /opt/ucfs_server_stub/ucfs_server_stub_cloudwatch.sh

echo "Allow shutting down"
echo "ucfs_server_stub     ALL = NOPASSWD: /sbin/shutdown -h now" >> /etc/sudoers

echo "Creating directories"
mkdir -p /var/log/ucfs_server_stub

echo "Creating user ucfs_server_stub"
useradd ucfs_server_stub -m

echo "Setup cloudwatch logs"
chmod u+x /opt/ucfs_server_stub/ucfs_server_stub_cloudwatch.sh
/opt/ucfs_server_stub/ucfs_server_stub_cloudwatch.sh \
"${cwa_metrics_collection_interval}" "${cwa_namespace}" "${cwa_cpu_metrics_collection_interval}" \
"${cwa_disk_measurement_metrics_collection_interval}" "${cwa_disk_io_metrics_collection_interval}" \
"${cwa_mem_metrics_collection_interval}" "${cwa_netstat_metrics_collection_interval}" "${cwa_log_group_name}" \
"$AWS_DEFAULT_REGION"

echo "${environment_name}" > /opt/ucfs_server_stub/environment

#TODO verify if we needs these certs
# Retrieve certificates
#ACM_KEY_PASSWORD=$(uuidgen -r)

#acm-cert-retriever \
#--acm-cert-arn "${acm_cert_arn}" \
#--acm-key-passphrase "$ACM_KEY_PASSWORD" \
#--private-key-alias "${private_key_alias}" \
#--truststore-aliases "${truststore_aliases}" \
#--truststore-certs "${truststore_certs}" >> /var/log/acm-cert-retriever.log 2>&1

echo "Retrieving Tarball Ingester artefact..."
$(which aws) s3 cp s3://${s3_artefact_bucket}/ucfs-server-stub/ucfs-server-stub-${ucfs_server_stub_release}.zip

echo "Changing permissions and moving files"
chown ucfs_server_stub:ucfs_server_stub -R  /opt/ucfs_server_stub
chown ucfs_server_stub:ucfs_server_stub -R  /var/log/ucfs_server_stub

if [[ "${environment_name}" != "production" ]]; then
echo "Running script to post synthetic tarballs to endpoint"
echo "Execute placeholder script to post tarballs" >> /var/log/ucfs_server_stub/ucfs_server_stub.out 2>&1
fi
