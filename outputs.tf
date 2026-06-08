output "alb_url" {
  description = "Mở URL này trên browser để xem app"
  value       = "http://${aws_lb.this.dns_name}"
}

output "ec2_public_ip" {
  description = "IP công khai của EC2"
  value       = aws_instance.this.public_ip
}

output "ssh_command" {
  description = "Lệnh SSH vào EC2 để debug"
  value       = "ssh -i ${var.project}-key.pem ec2-user@${aws_instance.this.public_ip}"
}
