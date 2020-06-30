#!/bin/bash

export GCLOUD_BIN=/home/gcloud/google-cloud-sdk/bin/gcloud

for instance in worker-0 worker-1 worker-2; do
	$GCLOUD_BIN compute ssh $instance --command="sudo apt-get update"
	$GCLOUD_BIN compute ssh $instance --command="sudo apt-get -y install socat conntrack ipset"
	$GCLOUD_BIN compute ssh $instance --command="sudo swapoff -a"
	$GCLOUD_BIN compute ssh $instance --command="wget -q --show-progress --https-only --timestamping https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.15.0/crictl-v1.15.0-linux-amd64.tar.gz https://github.com/opencontainers/runc/releases/download/v1.0.0-rc8/runc.amd64 https://github.com/containernetworking/plugins/releases/download/v0.8.2/cni-plugins-linux-amd64-v0.8.2.tgz https://github.com/containerd/containerd/releases/download/v1.2.9/containerd-1.2.9.linux-amd64.tar.gz https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-proxy https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubelet"
	$GCLOUD_BIN compute ssh $instance --command="sudo mkdir -p /etc/cni/net.d /opt/cni/bin /var/lib/kubelet /var/lib/kube-proxy /var/lib/kubernetes /var/run/kubernetes"
	$GCLOUD_BIN compute ssh $instance --command="mkdir containerd"
	$GCLOUD_BIN compute ssh $instance --command="tar -xvf crictl-v1.15.0-linux-amd64.tar.gz"
	$GCLOUD_BIN compute ssh $instance --command="tar -xvf containerd-1.2.9.linux-amd64.tar.gz -C containerd"
	$GCLOUD_BIN compute ssh $instance --command="sudo tar -xvf cni-plugins-linux-amd64-v0.8.2.tgz -C /opt/cni/bin/"
	$GCLOUD_BIN compute ssh $instance --command="sudo mv runc.amd64 runc"
	$GCLOUD_BIN compute ssh $instance --command="chmod +x crictl kubectl kube-proxy kubelet runc"
	$GCLOUD_BIN compute ssh $instance --command="sudo mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/"
	$GCLOUD_BIN compute ssh $instance --command="sudo mv containerd/bin/* /bin/"
	$GCLOUD_BIN compute ssh $instance --command="
POD_CIDR=\$(curl -s -H \"Metadata-Flavor: Google\" http://metadata.google.internal/computeMetadata/v1/instance/attributes/pod-cidr)
cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    \"cniVersion\": \"0.3.1\",
    \"name\": \"bridge\",
    \"type\": \"bridge\",
    \"bridge\": \"cnio0\",
    \"isGateway\": true,
    \"ipMasq\": true,
    \"ipam\": {
        \"type\": \"host-local\",
        \"ranges\": [
          [{\"subnet\": \"\${POD_CIDR}\"}]
        ],
        \"routes\": [{\"dst\": \"0.0.0.0/0\"}]
    }
}
EOF"
	$GCLOUD_BIN compute ssh $instance --command="cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    \"cniVersion\": \"0.3.1\",
    \"name\": \"lo\",
    \"type\": \"loopback\"
}
EOF"

	$GCLOUD_BIN compute ssh $instance --command="sudo mkdir -p /etc/containerd/"
	$GCLOUD_BIN compute ssh $instance --command="cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = \"overlayfs\"
    [plugins.cri.containerd.default_runtime]
      runtime_type = \"io.containerd.runtime.v1.linux\"
      runtime_engine = \"/usr/local/bin/runc\"
      runtime_root = \"\"
EOF"

	$GCLOUD_BIN compute ssh $instance --command="cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF"

	$GCLOUD_BIN compute ssh $instance --command="sudo mv \${HOSTNAME}-key.pem \${HOSTNAME}.pem /var/lib/kubelet/"
	$GCLOUD_BIN compute ssh $instance --command="sudo mv \${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig"
	$GCLOUD_BIN compute ssh $instance --command="sudo mv ca.pem /var/lib/kubernetes/"

	$GCLOUD_BIN compute ssh $instance --command="
POD_CIDR=\$(curl -s -H \"Metadata-Flavor: Google\" http://metadata.google.internal/computeMetadata/v1/instance/attributes/pod-cidr)
cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: \"/var/lib/kubernetes/ca.pem\"
authorization:
  mode: Webhook
clusterDomain: \"cluster.local\"
clusterDNS:
  - \"10.32.0.10\"
podCIDR: \"\${POD_CIDR}\"
resolvConf: \"/run/systemd/resolve/resolv.conf\"
runtimeRequestTimeout: \"15m\"
tlsCertFile: \"/var/lib/kubelet/\${HOSTNAME}.pem\"
tlsPrivateKeyFile: \"/var/lib/kubelet/\${HOSTNAME}-key.pem\"
EOF"

	$GCLOUD_BIN compute ssh $instance --command="
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF"

	$GCLOUD_BIN compute ssh $instance --command="sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig"
	$GCLOUD_BIN compute ssh $instance --command="cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: \"/var/lib/kube-proxy/kubeconfig\"
mode: \"iptables\"
clusterCIDR: \"10.200.0.0/16\"
EOF"

	$GCLOUD_BIN compute ssh $instance --command="cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF"

	$GCLOUD_BIN compute ssh $instance --command="sudo systemctl daemon-reload && sudo systemctl enable containerd kubelet kube-proxy"
done

for instance in worker-0 worker-1 worker-2; do
	$GCLOUD_BIN compute ssh $instance --command="sudo systemctl start containerd kubelet kube-proxy"
done

$GCLOUD_BIN compute ssh controller-0 --command "kubectl get nodes --kubeconfig admin.kubeconfig"
