#!/usr/bin/env bash

set -e

helm upgrade --install postgres postgres \
  --repo https://groundhog2k.github.io/helm-charts \
  --namespace postgres \
  --create-namespace \
  -f postgres-values.yaml \
  --version 1.5.7
