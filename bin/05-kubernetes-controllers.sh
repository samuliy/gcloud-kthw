#!/bin/bash

export GCLOUD_BIN=/home/gcloud/google-cloud-sdk/bin/gcloud

for instance in controller-0 controller-1 controller-2; do
	$GCLOUD_BIN compute ssh $instance --command="sudo mkdir -p /etc/kubernetes/config"
	$GCLOUD_BIN compute ssh $instance --command="wget -q --show-progress --https-only --timestamping 'https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-apiserver' 'https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-controller-manager' 'https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-scheduler' 'https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl'"
	$GCLOUD_BIN compute ssh $instance --command="chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl"
	$GCLOUD_BIN compute ssh $instance --command="sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/"
	$GCLOUD_BIN compute ssh $instance --command="sudo mkdir -p /var/lib/kubernetes/"
	$GCLOUD_BIN compute ssh $instance --command="sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pem encryption-config.yaml /var/lib/kubernetes/"

	$GCLOUD_BIN compute ssh $instance --command="
INTERNAL_IP=\$(curl -s -H \"Metadata-Flavor: Google\" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)

cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=\${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://10.240.0.10:2379,https://10.240.0.11:2379,https://10.240.0.12:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
"
	$GCLOUD_BIN compute ssh $instance --command="sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/"
	$GCLOUD_BIN compute ssh $instance --command="cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
"
	$GCLOUD_BIN compute ssh $instance --command="sudo mv kube-scheduler.kubeconfig /var/lib/kubernetes/"
	$GCLOUD_BIN compute ssh $instance --command="cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: \"/var/lib/kubernetes/kube-scheduler.kubeconfig\"
leaderElection:
  leaderElect: true
EOF
"
	$GCLOUD_BIN compute ssh $instance --command="cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
"

$GCLOUD_BIN compute ssh $instance --command="
  sudo systemctl daemon-reload &&
  sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
"
done

for instance in controller-0 controller-1 controller-2; do
	$GCLOUD_BIN compute ssh $instance --command="sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler"
done
sleep 10

for instance in controller-0 controller-1 controller-2; do
	$GCLOUD_BIN compute ssh $instance --command="sudo apt-get update && sudo apt-get install -y nginx"
	$GCLOUD_BIN compute ssh $instance --command="cat > kubernetes.default.svc.cluster.local <<EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF
"
	$GCLOUD_BIN compute ssh $instance --command="sudo mv kubernetes.default.svc.cluster.local /etc/nginx/sites-available/kubernetes.default.svc.cluster.local"
	$GCLOUD_BIN compute ssh $instance --command="sudo ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/"
	$GCLOUD_BIN compute ssh $instance --command="sudo systemctl enable nginx"
	$GCLOUD_BIN compute ssh $instance --command="sudo systemctl restart nginx"
done
