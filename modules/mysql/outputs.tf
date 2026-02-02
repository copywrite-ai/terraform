output "container_name" {
  value = docker_container.mysql.name
}

output "container_id" {
  value = docker_container.mysql.id
}
