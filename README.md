# Hướng dẫn triển khai Anomaly Detection trên Kubernetes bằng Helm & ArgoCD

## Mục tiêu
Tài liệu này hướng dẫn từng bước để triển khai hệ thống Anomaly Detection lên Kubernetes cluster bằng Helm chart và quản lý GitOps với ArgoCD. Bao gồm các bước chuẩn bị môi trường, tạo secret (đã seal), cài Ingress, cài ArgoCD, và kiểm tra dịch vụ.

## Yêu cầu
- Docker (local /.remote registry access)
- kubectl (kết nối tới cluster)
- Helm (để cài chart nếu cần)
- Quyền tạo namespace, secret, serviceaccount trên cluster

Kiểm tra:
- docker --version
- kubectl version
- helm version

## Tổng quan kiến trúc
- Namespace chính: `anomaly-system`
- Ingress: `ingress-nginx` (controller)
- GitOps: ArgoCD (namespace `argocd`)
- Secrets lưu registry và repo credentials (sealed secrets để lưu vào repo)

## Chuẩn bị môi trường (local / workstation)
1. Cài các công cụ cần thiết trên máy local:
   - curl, gpg, apt-transport-https (nếu dùng Debian/Ubuntu)
2. Cài Helm (ví dụ trên Debian/Ubuntu):
   - Thêm kho, cài helm (hoặc dùng curl theo trang chính thức)

Ví dụ (Ubuntu):
```bash
sudo apt-get update
sudo apt-get install curl gpg apt-transport-https --yes
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

## Sealed Secrets (tạo secret an toàn để lưu vào git)
1. Cài kubeseal (binary):
```bash
curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.23.0/kubeseal-0.23.0-linux-amd64.tar.gz"
tar -xvzf kubeseal-0.23.0-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
rm -f kubeseal-0.23.0-linux-amd64.tar.gz kubeseal
```
2. Tạo Docker registry secret (chạy local, sau đó seal để commit vào repo):
```bash
kubectl create secret docker-registry gitlab-registry \
  --docker-server=registry.gitlab.com \
  --docker-username=<YOUR_USERNAME> \
  --docker-password=<YOUR_GITLAB_TOKEN> \
  --docker-email=<YOUR_USER_EMAIL> \
  -n anomaly-system \
  --dry-run=client -o yaml > secret.yaml
```
3. Seal secret (sử dụng controller Sealed Secrets đang chạy trên cluster):
```bash
kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller \
  --format yaml < secret.yaml > sealed-gitlab-registry.yaml
```
- Lưu file `sealed-gitlab-registry.yaml` vào repo `anomaly-detection-helm` (an toàn để commit).

## Cài Ingress Controller (NGINX)
Cài NGINX ingress controller từ manifests chính thức:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
```
Chờ controller ready (timeout ví dụ 120s):
```bash
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

## Cài ArgoCD
1. Tạo namespace:
```bash
kubectl create namespace argocd
```
2. Cài ArgoCD:
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## Thiết lập ArgoCD để truy cập repository (GitLab)
Tạo secret cho ArgoCD biểu thị repo Git (đổi thông tin tương ứng):
```bash
kubectl create secret generic gitlab-repo-secret \
  --from-literal=type=git \
  --from-literal=url=https://gitlab.com/<YOUR_USERNAME>/anomaly-detection-helm.git \
  --from-literal=username=<YOUR_USERNAME> \
  --from-literal=password=<YOUR_GITLAB_TOKEN> \
  -n argocd
kubectl label secret gitlab-repo-secret argocd.argoproj.io/secret-type=repository -n argocd
```

## Triển khai ứng dụng qua ArgoCD
1. Chuẩn bị manifest ứng dụng ArgoCD (`argocd-application.yaml`) trong repo (tham chiếu tới chart / path trong repo).
2. Áp dụng manifest (nếu muốn tạo thủ công):
```bash
kubectl apply -f argocd-application.yaml
```
3. Kiểm tra applications:
```bash
kubectl get applications -n argocd
```

## Truy cập ArgoCD UI & ứng dụng
1. Port-forward ArgoCD server (tại local):
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
```
2. Lấy tài khoản admin password (mặn mặc định):
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
3. Truy cập: https://localhost:8080
   - Username: admin
   - Password: output từ lệnh trên

4. Port-forward frontend service (namespace anomaly-system) để truy cập UI ứng dụng:
```bash
kubectl port-forward svc/frontend 3000:80 -n anomaly-system &
# Truy cập: http://localhost:3000
```

## Kiểm tra sau triển khai
- Kiểm tra pods, services, ingress trong namespace `anomaly-system`:
```bash
kubectl get pods,svc,ingress -n anomaly-system
kubectl describe pod <pod-name> -n anomaly-system
kubectl logs <pod-name> -n anomaly-system
```
- Kiểm tra ArgoCD sync status trong UI hoặc:
```bash
kubectl get applications -n argocd
```

## Dọn dẹp (ví dụ)
- Xóa ArgoCD:
```bash
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete namespace argocd
```
- Xóa ingress:
```bash
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
```

## Xử lý sự cố (một số gợi ý)
- ArgoCD không kết nối repo: kiểm tra secret repo, network, SSH keys hoặc token.
- Sealed secret không apply được: kiểm tra phiên bản kubeseal, khóa public của controller và namespace controller.
- Ingress không route được: kiểm tra service targetPort, ingress rules, và external IP của controller.

## Tài liệu tham khảo
- ArgoCD: https://argo-cd.readthedocs.io/
- Sealed Secrets: https://github.com/bitnami-labs/sealed-secrets
- ingress-nginx: https://kubernetes.github.io/ingress-nginx/

## Ghi chú
- Thay tất cả placeholder như `<YOUR_USERNAME>`, `<YOUR_GITLAB_TOKEN>`, `<YOUR_USER_EMAIL>` bằng giá trị thật trước khi chạy lệnh.
- Tùy môi trường cluster (cloud provider, bare-metal) có thể cần điều chỉnh cấu hình Ingress/LoadBalancer.
