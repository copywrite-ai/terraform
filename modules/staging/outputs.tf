output "remote_dir" {
  value = var.remote_dir
}

output "ensure_remote_dir_id" {
  value = try(null_resource.ensure_remote_dir[0].id, "")
}

output "stage_copy_id" {
  value = try(null_resource.stage_copy[0].id, "")
}
