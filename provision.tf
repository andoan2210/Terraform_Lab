###############################################################
# Chờ EC2 bootstrap xong rồi verify
# Dùng cloud-init status --wait — giống pattern dự án minikube
###############################################################

resource "null_resource" "wait_for_app" {
  triggers = {
    instance_id = aws_instance.this.id
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    host        = aws_instance.this.public_ip
    private_key = tls_private_key.ssh.private_key_pem
    timeout     = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '[1/3] Waiting for cloud-init to finish...'",
      "sudo cloud-init status --wait || (echo 'cloud-init failed'; sudo tail -n 100 /var/log/k8s-bootstrap.log; exit 1)",
      "echo '[2/3] Checking bootstrap marker...'",
      "test -f /var/log/k8s-ready || (sudo tail -n 100 /var/log/k8s-bootstrap.log; exit 1)",
      "echo '[3/3] Checking app...'",
      "curl -fsSI http://127.0.0.1:${var.node_port}",
      "echo 'App is live!'"
    ]
  }

  depends_on = [aws_lb_target_group_attachment.this]
}
