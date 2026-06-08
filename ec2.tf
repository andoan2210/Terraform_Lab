###############################################################
# AMI – Amazon Linux 2023
###############################################################
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

###############################################################
# EC2 Instance
###############################################################
resource "aws_instance" "this" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.this.key_name

  user_data = templatefile("${path.module}/userdata.sh.tpl", {
    node_port = var.node_port
  })

  user_data_replace_on_change = true

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  # Đảm bảo IGW sẵn sàng trước khi EC2 boot
  depends_on = [aws_internet_gateway.this]

  tags = { Name = "${var.project}-node" }
}
