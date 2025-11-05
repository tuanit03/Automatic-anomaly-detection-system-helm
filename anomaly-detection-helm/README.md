Anomaly Detection Helm chart

Tài liệu này mô tả nội dung và cách sử dụng Helm chart trong thư mục `anomaly-detection-helm` — một bundle Helm chứa nhiều subchart để triển khai hệ thống phát hiện bất thường (anomaly detection) gồm backend, frontend, Kafka và TimescaleDB.

## Tổng quan

`anomaly-detection-helm` là một Helm umbrella chart (bundle) chứa các subchart cần thiết để chạy hệ thống: backend (API & worker), frontend (UI), kafka (message broker) và timescaledb (database cho time-series). Mục tiêu của README này là cung cấp hướng dẫn toàn diện, thực tế để triển khai trên Kubernetes bằng Helm.

Lưu ý: README này được viết dựa trên cấu trúc thư mục hiện có (xem bên dưới). Một vài giá trị cụ thể (tên image, credentials, domain) có thể cần thay đổi theo môi trường. Tôi sẽ nêu rõ giả định nếu cần.

## Nội dung thư mục

- `Chart.yaml` - metadata của umbrella chart
- `sealed-gitlab-registry.yaml` - manifest đã được sealed (sử dụng Sealed Secrets) để cung cấp registry secret (nếu bạn dùng GitLab registry đã mã hoá)
- `backend/` - subchart cho backend
	- `Chart.yaml`, `values.yaml`, `templates/` (deployment, service, secret, configmap)
- `frontend/` - subchart cho frontend (UI)
- `kafka/` - subchart cho Kafka brokers & kafka-ui
- `timescaledb/` - subchart cho TimescaleDB (statefulset, PVC, secret)

Mỗi subchart có file `values.yaml` riêng để cấu hình (số replica, resources, persistence, ingress, image, v.v.).

## Kiến trúc tổng quan

- Users -> Frontend (Ingress / LoadBalancer)
- Frontend <-> Backend (REST API)
- Backend -> Kafka (publish/subscribe)
- Backend -> TimescaleDB (lưu time-series / anomaly results)

Bạn có thể triển khai toàn bộ bundle hoặc chỉ cài từng subchart nếu cần (ví dụ chỉ timescaledb để test DB).

## Yêu cầu trước khi cài

- Kubernetes cluster (v1.20+ khuyến nghị) với đủ tài nguyên.
- Helm v3.x
- kubectl cấu hình tới cluster
- (Tùy chọn) Sealed Secrets controller, nếu bạn sử dụng `sealed-gitlab-registry.yaml` để lưu registry credentials.
- Lưu ý về StorageClass: TimescaleDB dùng PVC; đảm bảo cluster có StorageClass mặc định hoặc cấu hình PVC tương ứng.