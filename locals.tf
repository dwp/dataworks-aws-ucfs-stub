locals {

  deploy_ucfs_server_stub = {
    development = true
    qa          = true
    integration = false
    preprod     = false
  }

  ucfs_server_stub_ssmenabled = {
    development = true
    qa          = true
    integration = true
    preprod     = false
  }

  env_prefix = {
    development = "dev."
    qa          = "qa."
    stage       = "stg."
    integration = "int."
    preprod     = "pre."
  }

  ucfs_server_stub_tags_asg = merge(
  local.common_tags,
  {
    Name        = local.ucfs_server_stub_name,
    Persistence = "Ignore",
  }
  )

  ucfs_server_stub_asg_min = {
    development = 0
    qa          = 0
    integration = 0
    preprod     = 0
  }

  ucfs_server_stub_asg_desired = {
      development = 1
      qa          = 1
      integration = 1
      preprod     = 1
  }

  ucfs_server_stub_asg_max = {
      development = 1
      qa = 1
      integration = 1
      preprod = 1
      production = 1
  }

  ucfs_server_stub_truststore_aliases = {
    development = "ucfs_ca"
    qa          = "ucfs_ca"
    integration = "ucfs_ca"
    preprod     = "ucfs_ca"
  }

  ucfs_server_stub_truststore_certs = {
    development = "s3://${data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/ucfs/root_ca.pem"
    qa          = "s3://${data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/ucfs/root_ca.pem"
    integration = "s3://${data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/ucfs/root_ca.pem"
    preprod     = "s3://${data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/ucfs/root_ca.pem"
  }
  
  ucfs_server_stub_name               = "ucfs-server-stub"
  cw_ucfs_server_stub_agent_namespace = "/app/${local.ucfs_server_stub_name}"

  cw_agent_metrics_collection_interval                  = 60
  cw_agent_cpu_metrics_collection_interval              = 60
  cw_agent_disk_measurement_metrics_collection_interval = 60
  cw_agent_disk_io_metrics_collection_interval          = 60
  cw_agent_mem_metrics_collection_interval              = 60
  cw_agent_netstat_metrics_collection_interval          = 60
}


