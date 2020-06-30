#!/bin/bash

export GCLOUD_BIN=/home/gcloud/google-cloud-sdk/bin/gcloud
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

for instance in controller-0 controller-1 controller-2; do
  $GCLOUD_BIN compute scp encryption-config.yaml ${instance}:~/
done
