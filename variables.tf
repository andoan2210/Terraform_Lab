variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Tên project, dùng làm prefix cho tất cả resources"
  type        = string
  default     = "k8s-lab"
}

variable "vpc_cidr" {
  description = "CIDR block cho VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "2 public subnet CIDRs cho ALB"
  type        = list(string)
  default     = ["10.10.1.0/24", "10.10.2.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type (t3.medium khuyến nghị cho kind)"
  type        = string
  default     = "t3.medium"
}

variable "node_port" {
  description = "NodePort expose từ K8s Service ra host EC2"
  type        = number
  default     = 30080
}

variable "root_volume_size" {
  description = "Dung lượng ổ đĩa EC2 (GiB)"
  type        = number
  default     = 20
}
