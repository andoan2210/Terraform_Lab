# K8s on AWS — Terraform 1-Click

Dựng 1 EC2 trên AWS, cài **kind** để chạy Kubernetes cluster, deploy app vào trong đó, expose ra internet qua **ALB** — tất cả bằng một lệnh Terraform duy nhất.

---

## Kiến trúc

```
Internet → ALB :80 → EC2 t3.medium :30080 → kind cluster → nginx pod
```

- **EC2** chạy Amazon Linux 2023, cài Docker + kind + kubectl qua user-data
- **kind** tạo K8s cluster bên trong Docker, map NodePort 30080 ra host
- **ALB** nhận traffic từ internet, forward vào EC2:30080
- App là nginx trả về trang HTML tĩnh

---

## Providers sử dụng (≥2)

| Provider | Mục đích |
|---|---|
| `hashicorp/aws` | EC2, ALB, VPC, Security Groups, IAM |
| `hashicorp/tls` | Tự generate SSH key pair — không cần tạo .pem thủ công |

**Cách wire provider thứ 2:**
`hashicorp/tls` generate RSA key pair ngay trong Terraform. Public key được đẩy lên AWS làm EC2 Key Pair (`aws_key_pair`). Private key được dùng bởi `null_resource` để SSH vào EC2 (`remote-exec`) sau khi cluster sẵn sàng — toàn bộ không cần file `.pem` bên ngoài, hoàn toàn reproducible.

---

## Cấu trúc thư mục

```
Day_3/
├── main.tf          # terraform block, providers, tls key pair
├── variables.tf     # region, ports, instance type
├── networking.tf    # VPC, IGW, subnet, route table, security groups
├── ec2.tf           # AMI, EC2 instance
├── provision.tf     # null_resource: SSH chờ cloud-init, verify app
├── alb.tf           # ALB, Target Group, Listener
├── outputs.tf       # in ra alb_url và ssh_command sau khi apply
└── userdata.sh.tpl  # script bootstrap EC2: Docker → kind → kubectl → deploy app
```

---

## Yêu cầu

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.6
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) đã configure (`aws configure`)

---

## Chạy (1-click)

```bash
terraform init
terraform apply -auto-approve
```

Sau khoảng 10–12 phút, Terraform in ra:

```
alb_url     = "http://k8s-lab-alb-xxxxxxxxx.us-east-1.elb.amazonaws.com"
ssh_command = "ssh -i k8s-lab-key.pem ec2-user@x.x.x.x"
```

Mở `alb_url` trên browser là thấy app.

---

## Dọn dẹp

```bash
terraform destroy -auto-approve
```

---

## Lý do chọn thiết kế này

**kind thay vì minikube**
kind chạy hoàn toàn trong Docker, không cần VM driver. Trên EC2 Linux không có GUI, kind bootstrap nhanh và ổn định hơn. `extraPortMappings` cho phép map NodePort ra host một cách declarative.

**tls provider làm provider thứ 2**
Tự generate SSH key trong Terraform, không phụ thuộc vào file `.pem` tạo thủ công bên ngoài. Toàn bộ infra reproducible từ con số 0.

**VPC tự tạo thay vì default VPC**
Tự tạo VPC + IGW + route table đảm bảo EC2 luôn có internet connectivity. Default VPC có thể thiếu subnet hoặc route, gây lỗi SSH không kết nối được.

**NodePort + ALB thay vì LoadBalancer service**
K8s `LoadBalancer` service trên kind cần cloud-controller-manager — phức tạp không cần thiết. NodePort đơn giản, ALB lo phần public-facing load balancing.

**cloud-init status --wait làm tín hiệu đồng bộ**
user-data chạy async sau khi EC2 boot. `cloud-init status --wait` trong `remote-exec` đảm bảo Terraform chờ toàn bộ bootstrap xong hẳn trước khi verify app.
