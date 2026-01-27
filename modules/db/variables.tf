variable "remote_host" {
  type = string
}

variable "ssh_user" {
  type = string
}

variable "ssh_private_key_path" {
  type = string
}

variable "host_data_path" {
  type = string
}

variable "image" {
  type    = string
  default = "docker.1ms.run/library/mysql:8.0.32"
}

variable "env" {
  type    = list(string)
  default = [
    "MYSQL_ROOT_PASSWORD=",
    "MYSQL_ALLOW_EMPTY_PASSWORD=yes",
    "MYSQL_MAX_CONNECTIONS=2000"
  ]
}

variable "ports" {
  type = list(object({ internal = number, external = number }))
  default = [{ internal = 3306, external = 3306 }]
}

variable "config_files" {
  type = map(string)
}

variable "data_volumes" {
  type = map(string)
}

variable "healthcheck" {
  type = any
  default = {
    test         = ["CMD", "mysqladmin", "ping", "-h", "localhost"]
    interval     = "5s"
    timeout      = "10s"
    retries      = 30
    start_period = "60s"
  }
}
