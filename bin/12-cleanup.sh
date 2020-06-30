#!/bin/bash

export GCLOUD_BIN=/home/gcloud/google-cloud-sdk/bin/gcloud

$GCLOUD_BIN compute instances delete \
controller-0 controller-1 controller-2 \
worker-0 worker-1 worker-2 \
--zone $($GCLOUD_BIN config get-value compute/zone)

$GCLOUD_BIN compute forwarding-rules delete kubernetes-forwarding-rule \
--region $($GCLOUD_BIN config get-value compute/region)

$GCLOUD_BIN compute target-pools delete kubernetes-target-pool

$GCLOUD_BIN compute http-health-checks delete kubernetes

$GCLOUD_BIN compute addresses delete kubernetes-the-hard-way

$GCLOUD_BIN compute firewall-rules delete \
kubernetes-the-hard-way-allow-nginx-service \
kubernetes-the-hard-way-allow-internal \
kubernetes-the-hard-way-allow-external \
kubernetes-the-hard-way-allow-health-check

$GCLOUD_BIN compute routes delete \
kubernetes-route-10-200-0-0-24 \
kubernetes-route-10-200-1-0-24 \
kubernetes-route-10-200-2-0-24

$GCLOUD_BIN compute networks subnets delete kubernetes

$GCLOUD_BIN compute networks delete kubernetes-the-hard-way
