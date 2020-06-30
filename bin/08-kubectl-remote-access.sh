#!/bin/bash

export GCLOUD_BIN=/home/gcloud/google-cloud-sdk/bin/gcloud

KUBERNETES_PUBLIC_ADDRESS=$($GCLOUD_BIN compute addresses describe kubernetes-the-hard-way \
--region $($GCLOUD_BIN config get-value compute/region) \
--format 'value(address)')

kubectl config set-cluster kubernetes-the-hard-way \
--certificate-authority=ca.pem \
--embed-certs=true \
--server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443

kubectl config set-credentials admin \
--client-certificate=admin.pem \
--client-key=admin-key.pem

kubectl config set-context kubernetes-the-hard-way \
--cluster=kubernetes-the-hard-way \
--user=admin

kubectl config use-context kubernetes-the-hard-way

kubectl get componentstatuses

kubectl get nodes
