#!/bin/bash

export GCLOUD_BIN=/home/gcloud/google-cloud-sdk/bin/gcloud

/home/gcloud/google-cloud-sdk/install.sh

$GCLOUD_BIN init

$GCLOUD_BIN compute networks create kubernetes-the-hard-way --subnet-mode custom

$GCLOUD_BIN compute networks subnets create kubernetes \
--network kubernetes-the-hard-way \
--range 10.240.0.0/24

$GCLOUD_BIN compute firewall-rules create kubernetes-the-hard-way-allow-internal \
--allow tcp,udp,icmp \
--network kubernetes-the-hard-way \
--source-ranges 10.240.0.0/24,10.200.0.0/16

$GCLOUD_BIN compute firewall-rules create kubernetes-the-hard-way-allow-external \
--allow tcp:22,tcp:6443,icmp \
--network kubernetes-the-hard-way \
--source-ranges 0.0.0.0/0

$GCLOUD_BIN compute firewall-rules list --filter="network:kubernetes-the-hard-way"

$GCLOUD_BIN compute addresses create kubernetes-the-hard-way \
--region $($GCLOUD_BIN config get-value compute/region)


for i in 0 1 2; do
	$GCLOUD_BIN compute instances create controller-${i} \
	--async \
	--boot-disk-size 200GB \
	--can-ip-forward \
	--image-family ubuntu-1804-lts \
	--image-project ubuntu-os-cloud \
	--machine-type n1-standard-1 \
	--private-network-ip 10.240.0.1${i} \
	--scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
	--subnet kubernetes \
	--tags kubernetes-the-hard-way,controller
done

for i in 0 1 2; do
	$GCLOUD_BIN compute instances create worker-${i} \
	--async \
	--boot-disk-size 200GB \
	--can-ip-forward \
	--image-family ubuntu-1804-lts \
	--image-project ubuntu-os-cloud \
	--machine-type n1-standard-1 \
	--metadata pod-cidr=10.200.${i}.0/24 \
	--private-network-ip 10.240.0.2${i} \
	--scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
	--subnet kubernetes \
	--tags kubernetes-the-hard-way,worker
done

$GCLOUD_BIN compute instances list
