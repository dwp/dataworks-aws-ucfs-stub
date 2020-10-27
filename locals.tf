locals {

  deploy_ucfs_server_stub = {
    development = true
    qa          = true
    integration = false
    preprod     = false
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


