locals {

  deploy_stub_ucfs_export_server = {
    development = true
    qa          = true
    integration = true
    preprod     = true
    production  = false
  }

  stub_ucfs_export_server_ssmenabled = {
    development = true
    qa          = true
    integration = true
    preprod     = false
    production  = false
  }

  env_prefix = {
    development = "dev."
    qa          = "qa."
    stage       = "stg."
    integration = "int."
    preprod     = "pre."
    production  = ""
  }

  stub_ucfs_export_server_tags_asg = merge(
    local.common_tags,
    {
      Name        = local.stub_ucfs_export_server_name,
      Persistence = "Ignore",
    }
  )

  stub_ucfs_export_server_asg_min = {
    development = 0
    qa          = 0
    integration = 0
    preprod     = 0
    production  = 0
  }

  stub_ucfs_export_server_asg_desired = {
    development = 1
    qa          = 1
    integration = 1
    preprod     = 1
    production  = 0
  }

  stub_ucfs_export_server_asg_max = {
    development = 1
    qa          = 1
    integration = 1
    preprod     = 1
    production  = 0
  }

  stub_ucfs_export_server_truststore_aliases = {
    development = "ucfs_ca"
    qa          = "ucfs_ca"
    integration = "ucfs_ca"
    preprod     = "ucfs_ca"
    production  = "ucfs_ca"
  }

  stub_ucfs_export_server_truststore_certs = {
    development = "s3://${data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/ucfs/root_ca.pem"
    qa          = "s3://${data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/ucfs/root_ca.pem"
    integration = "s3://${data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/ucfs/root_ca.pem"
    preprod     = "s3://${data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/ucfs/root_ca.pem"
    production  = "s3://${data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/ucfs/root_ca.pem"
  }

  stub_ucfs_export_server_name               = "stub-ucfs-export-server"
  cw_stub_ucfs_export_server_agent_namespace = "/app/${local.stub_ucfs_export_server_name}"

  cw_agent_metrics_collection_interval                  = 60
  cw_agent_cpu_metrics_collection_interval              = 60
  cw_agent_disk_measurement_metrics_collection_interval = 60
  cw_agent_disk_io_metrics_collection_interval          = 60
  cw_agent_mem_metrics_collection_interval              = 60
  cw_agent_netstat_metrics_collection_interval          = 60
}


