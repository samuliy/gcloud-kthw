#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

cd $SCRIPT_DIR
docker rm gcloud
docker build -t gcloud .
docker run -it --rm \
--volume $(pwd)/bin:/home/gcloud/bin \
gcloud bash
