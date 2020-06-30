#!/bin/bash

export GCLOUD_BIN=/home/gcloud/google-cloud-sdk/bin/gcloud

for instance in controller-0 controller-1 controller-2; do
	$GCLOUD_BIN compute ssh $instance --command="wget -q --show-progress --https-only --timestamping https://github.com/etcd-io/etcd/releases/download/v3.4.0/etcd-v3.4.0-linux-amd64.tar.gz"

	$GCLOUD_BIN compute ssh $instance --command="tar -xvf etcd-v3.4.0-linux-amd64.tar.gz"
	$GCLOUD_BIN compute ssh $instance --command="sudo mv etcd-v3.4.0-linux-amd64/etcd* /usr/local/bin/"

	$GCLOUD_BIN compute ssh $instance --command="sudo mkdir -p /etc/etcd /var/lib/etcd"
	$GCLOUD_BIN compute ssh $instance --command="sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/"

	$GCLOUD_BIN compute ssh $instance --command="
INTERNAL_IP=\$(curl -s -H \"Metadata-Flavor: Google\" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
ETCD_NAME=\$(hostname -s)

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name \${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://\${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://\${INTERNAL_IP}:2380 \\
  --listen-client-urls https://\${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://\${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster controller-0=https://10.240.0.10:2380,controller-1=https://10.240.0.11:2380,controller-2=https://10.240.0.12:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
"

$GCLOUD_BIN compute ssh $instance --command="
  sudo systemctl daemon-reload &&
  sudo systemctl enable etcd
"

done

for instance in controller-0 controller-1 controller-2; do
	$GCLOUD_BIN compute ssh $instance --command="sudo systemctl start etcd"

	$GCLOUD_BIN compute ssh $instance --command="
	sudo ETCDCTL_API=3 etcdctl member list \
	--endpoints=https://127.0.0.1:2379 \
	--cacert=/etc/etcd/ca.pem \
	--cert=/etc/etcd/kubernetes.pem \
	--key=/etc/etcd/kubernetes-key.pem
	"
done
