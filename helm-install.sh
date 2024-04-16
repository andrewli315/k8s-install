#!/bin/bash

curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 /tmp/get_helm.sh
eval "/bin/bash /tmp/get_helm.sh"
echo "helm chart install complete"
rm -rf /tmp/get_helm.sh
