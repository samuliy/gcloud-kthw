#!/bin/bash

export GCLOUD_BIN=/home/gcloud/google-cloud-sdk/bin/gcloud

$GCLOUD_BIN compute ssh controller-0 --command="cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: \"true\"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - \"\"
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - \"*\"
EOF"

$GCLOUD_BIN compute ssh controller-0 --command="cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF"

# network load balancer
KUBERNETES_PUBLIC_ADDRESS=$($GCLOUD_BIN compute addresses describe kubernetes-the-hard-way \
--region $($GCLOUD_BIN config get-value compute/region) \
--format 'value(address)')

$GCLOUD_BIN compute http-health-checks create kubernetes \
--description "Kubernetes Health Check" \
--host "kubernetes.default.svc.cluster.local" \
--request-path "/healthz"

$GCLOUD_BIN compute firewall-rules create kubernetes-the-hard-way-allow-health-check \
--network kubernetes-the-hard-way \
--source-ranges 209.85.152.0/22,209.85.204.0/22,35.191.0.0/16 \
--allow tcp

$GCLOUD_BIN compute target-pools create kubernetes-target-pool \
--http-health-check kubernetes

$GCLOUD_BIN compute target-pools add-instances kubernetes-target-pool \
--instances controller-0,controller-1,controller-2

$GCLOUD_BIN compute forwarding-rules create kubernetes-forwarding-rule \
--address ${KUBERNETES_PUBLIC_ADDRESS} \
--ports 6443 \
--region $($GCLOUD_BIN config get-value compute/region) \
--target-pool kubernetes-target-pool

# verify
curl --cacert ca.pem https://${KUBERNETES_PUBLIC_ADDRESS}:6443/version
