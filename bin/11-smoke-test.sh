#!/bin/bash

export GCLOUD_BIN=/home/gcloud/google-cloud-sdk/bin/gcloud

kubectl create secret generic kubernetes-the-hard-way \
--from-literal="mykey=mydata"

$GCLOUD_BIN compute ssh controller-0 --command "sudo ETCDCTL_API=3 etcdctl get --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem /registry/secrets/default/kubernetes-the-hard-way | hexdump -C"

kubectl create deployment nginx --image=nginx
sleep 1
kubectl get pods -l app=nginx

# port forwarding
POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $POD_NAME 8080:80 &
sleep 1
curl --head http://127.0.0.1:8080
kill $!

# logs
kubectl logs $POD_NAME

# exec
kubectl exec -ti $POD_NAME -- nginx -v

# services
kubectl expose deployment nginx --port 80 --type NodePort

NODE_PORT=$(kubectl get svc nginx \
--output=jsonpath='{range .spec.ports[0]}{.nodePort}')

$GCLOUD_BIN compute firewall-rules create kubernetes-the-hard-way-allow-nginx-service \
--allow=tcp:${NODE_PORT} \
--network kubernetes-the-hard-way

EXTERNAL_IP=$($GCLOUD_BIN compute instances describe worker-0 \
--format 'value(networkInterfaces[0].accessConfigs[0].natIP)')

curl -I http://${EXTERNAL_IP}:${NODE_PORT}
