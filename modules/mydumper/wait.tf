variable "timeout_seconds" {
  type    = number
  default = 120
}

resource "null_resource" "wait_for_mysql_health" {
  connection {
    type        = "ssh"
    host        = var.ssh_host
    user        = var.ssh_user
    private_key = file(var.ssh_key_path)
    agent       = false
    timeout     = "${var.timeout_seconds}s"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "cname='${var.mysql_container_name}'",
      "timeout='${var.timeout_seconds}'",
      "i=0",
      "while [ $i -lt $timeout ]; do",
      "  status=$(docker inspect -f '{{.State.Health.Status}}' \"$cname\" 2>/dev/null || true)",
      "  if [ \"$status\" = \"healthy\" ]; then exit 0; fi",
      "  sleep 1",
      "  i=$((i+1))",
      "done",
      "echo \"Timed out waiting for $cname to become healthy\" >&2",
      "exit 1",
    ]
  }
}
