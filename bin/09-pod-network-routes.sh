#!/bin/bash

export GCLOUD_BIN=/home/gcloud/google-cloud-sdk/bin/gcloud

for instance in worker-0 worker-1 worker-2; do
	$GCLOUD_BIN compute instances describe ${instance} \
	--format 'value[separator=" "](networkInterfaces[0].networkIP,metadata.items[0].value)'
done

for i in 0 1 2; do
	$GCLOUD_BIN compute routes create kubernetes-route-10-200-${i}-0-24 \
	--network kubernetes-the-hard-way \
	--next-hop-address 10.240.0.2${i} \
	--destination-range 10.200.${i}.0/24
done

$GCLOUD_BIN compute routes list --filter "network: kubernetes-the-hard-way"
