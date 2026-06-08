#!/bin/bash
set -euxo pipefail

exec > >(tee -a /var/log/k8s-bootstrap.log) 2>&1

NODE_PORT="${node_port}"

###############################################################
# 0. Swap (hỗ trợ instance nhỏ)
###############################################################
if [ ! -f /swapfile ]; then
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo "/swapfile none swap sw 0 0" >> /etc/fstab
fi

###############################################################
# 1. Packages
###############################################################
yum update -y
yum install -y docker conntrack socat
# curl đã có sẵn trên Amazon Linux 2023, không cần cài thêm

systemctl enable docker
systemctl start docker

###############################################################
# 2. Install kind
###############################################################
curl -Lo /usr/local/bin/kind \
  "https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64"
chmod +x /usr/local/bin/kind

###############################################################
# 3. Install kubectl
###############################################################
curl -Lo /usr/local/bin/kubectl \
  "https://dl.k8s.io/release/v1.29.3/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl

###############################################################
# 4. Tạo kind cluster với NodePort mapping
###############################################################
cat > /tmp/kind-config.yaml <<KINDCFG
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: $NODE_PORT
        hostPort: $NODE_PORT
        listenAddress: "0.0.0.0"
        protocol: TCP
KINDCFG

kind create cluster \
  --name k8s-lab \
  --config /tmp/kind-config.yaml \
  --wait 120s

mkdir -p /root/.kube
kind get kubeconfig --name k8s-lab > /root/.kube/config
export KUBECONFIG=/root/.kube/config

###############################################################
# 5. Deploy app vào K8s
###############################################################
cat > /tmp/app.yaml <<MANIFEST
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-html
data:
  index.html: |
    <!DOCTYPE html>
    <html lang="vi">
    <head>
      <meta charset="UTF-8">
      <title>Lab</title>
    </head>
    <body>
      <p>Lab thực hiện bởi An</p>
    </body>
    </html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:1.25-alpine
          ports:
            - containerPort: 80
          volumeMounts:
            - name: html
              mountPath: /usr/share/nginx/html
      volumes:
        - name: html
          configMap:
            name: web-html
---
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
      nodePort: $NODE_PORT
MANIFEST

kubectl apply -f /tmp/app.yaml
kubectl rollout status deployment/web --timeout=180s
kubectl wait --for=condition=ready pod -l app=web --timeout=180s

###############################################################
# 6. Verify NodePort từ host
###############################################################
for i in $(seq 1 60); do
  if curl -fsSI "http://127.0.0.1:$NODE_PORT" > /dev/null 2>&1; then
    echo "NodePort $NODE_PORT is responding"
    break
  fi
  sleep 5
  if [ "$i" -eq 60 ]; then
    echo "ERROR: NodePort $NODE_PORT did not respond in time"
    exit 1
  fi
done

kubectl get nodes -o wide
kubectl get deploy,pods,svc

# Signal hoàn tất
touch /var/log/k8s-ready
echo "=== Bootstrap hoàn tất ==="
