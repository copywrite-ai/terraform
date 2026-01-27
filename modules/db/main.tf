module "mysql_container" {
  source = "../core_container"

  app_name             = "mysql"
  image                = var.image
  remote_host          = var.remote_host
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path

  env          = var.env
  ports        = var.ports
  config_files = var.config_files
  data_volumes = var.data_volumes
  healthcheck  = var.healthcheck
  network_mode = "host"
}
