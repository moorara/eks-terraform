#!/bin/bash

set -eu -x -o pipefail

/etc/eks/bootstrap.sh \
  --apiserver-endpoint '${cluster_endpoint}' \
  --b64-cluster-ca '${base64_cluster_ca}' \
  '${cluster_name}'
