FROM archlinux/base

RUN pacman -Syu --noconfirm --quiet
RUN pacman -Sy --noconfirm --quiet python tar wget openssh

RUN useradd gcloud \
--home-dir /home/gcloud \
--create-home \
--uid 1000 \
--shell /bin/bash

USER gcloud
WORKDIR /home/gcloud

RUN curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-298.0.0-linux-x86_64.tar.gz
RUN tar zxvf google-cloud-sdk-298.0.0-linux-x86_64.tar.gz google-cloud-sdk

RUN wget -q --show-progress --https-only --timestamping \
https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/linux/cfssl \
https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/linux/cfssljson
RUN chmod +x cfssl cfssljson

RUN wget https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl
RUN chmod +x kubectl

USER root
RUN mv cfssl cfssljson /usr/local/bin/
RUN mv kubectl /usr/local/bin/

USER gcloud
