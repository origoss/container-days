#!/usr/bin/env bash
# Container Days 2026 - Calico v3.32.0 Demo Setup
# Run this inside: nix develop
set -euo pipefail

# --- Preflight checks ---
echo "=== Preflight checks ==="

if [ -z "${IN_NIX_SHELL:-}" ]; then
    echo "ERROR: Run this inside 'nix develop'." >&2
    exit 1
fi

for cmd in kind kubectl docker; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd not found. Make sure you are in the nix develop shell." >&2
        exit 1
    fi
done

echo "Tools OK: kind=$(kind --version 2>&1), kubectl=$(kubectl version --client --short 2>/dev/null || kubectl version --client 2>&1 | head -1)"

# --- 1. Dummy network interface ---
echo ""
echo "=== 1. Dummy network interface ==="

if ip link show whisker &>/dev/null; then
    echo "Interface 'whisker' already exists — skipping."
else
    sudo ip link add dev whisker type dummy
    sudo ip addr add 3.14.137.65/28 dev whisker
    echo "Created dummy interface 'whisker' with 3.14.137.65/28."
fi

# --- 2. Pull and save Calico images ---
echo ""
echo "=== 2. Pull and save Calico images ==="

CALICO_VERSION="v3.32.0"
CALICO_IMAGES=("typha" "kube-controllers" "node" "csi")
OPERATOR_VERSION="v1.42.0"

for IMAGE in "${CALICO_IMAGES[@]}"; do
    TAR="${IMAGE}.tar"
    if [ -f "$TAR" ]; then
        echo "${IMAGE}:${CALICO_VERSION} already saved — skipping."
    else
        echo "Pulling ${IMAGE}:${CALICO_VERSION}..."
        docker pull "quay.io/calico/${IMAGE}:${CALICO_VERSION}"
        docker save "quay.io/calico/${IMAGE}:${CALICO_VERSION}" -o "$TAR"
    fi
done

if [ -f operator.tar ]; then
    echo "operator:${OPERATOR_VERSION} already saved — skipping."
else
    echo "Pulling operator:${OPERATOR_VERSION}..."
    docker pull "quay.io/tigera/operator:${OPERATOR_VERSION}"
    docker save "quay.io/tigera/operator:${OPERATOR_VERSION}" -o operator.tar
fi

# --- 3. Build and save the compromised Postgres image ---
echo ""
echo "=== 3. Build compromised Postgres image ==="

if [ -f postgres_16.tar ]; then
    echo "postgres_16.tar already exists — skipping build."
else
    docker build 2026/postgresql/ -t postgresql/postgresql:16
    docker save postgresql/postgresql:16 -o postgres_16.tar
    echo "Built and saved postgresql/postgresql:16."
fi

# --- 4. Create the kind cluster ---
echo ""
echo "=== 4. Create kind cluster ==="

if kind get clusters 2>/dev/null | grep -q "whisker-the-game"; then
    echo "Cluster 'whisker-the-game' already exists — skipping."
else
    kind create cluster \
        --name whisker-the-game \
        --config kind-config.yaml \
        --kubeconfig kubeconfig
    echo "Cluster created. Kubeconfig written to ./kubeconfig."
fi

kubectl cluster-info

# --- 5. Load container images into kind nodes ---
echo ""
echo "=== 5. Load container images ==="

IMAGES=("typha" "kube-controllers" "node" "csi" "operator" "postgres_16")
NODES="whisker-the-game-control-plane,whisker-the-game-worker,whisker-the-game-worker2"

for IMAGE in "${IMAGES[@]}"; do
    if [ ! -f "${IMAGE}.tar" ]; then
        echo "ERROR: ${IMAGE}.tar not found. Place it in the working directory first." >&2
        exit 1
    fi
    echo "Uploading ${IMAGE}..."
    kind load image-archive "${IMAGE}.tar" \
        --name whisker-the-game \
        --nodes "$NODES"
done

echo "All images loaded."

# --- 6. Install Calico ---
echo ""
echo "=== 6. Install Calico ==="

# operator-crds.yaml is multi-MB; client-side `kubectl create`/`apply` chokes
# (CRDs exceed the last-applied-config annotation limit) and isn't re-runnable
# (errors AlreadyExists on a second run, aborting under `set -e`). Server-side
# apply avoids both and is idempotent.
kubectl apply --server-side --force-conflicts -f operator-crds.yaml
kubectl apply -f tigera-operator.yaml
kubectl create ns calico-system 2>/dev/null || true
kubectl apply -f custom-resources.yaml
kubectl apply -f tier.yaml

echo "Waiting for the Calico operator to roll out..."
kubectl -n tigera-operator rollout status deployment/tigera-operator --timeout=180s

echo "Waiting for Calico to finish installing..."
# The operator reconciles the Installation/APIServer/Goldmane/Whisker CRs
# asynchronously, so calico-system pods don't exist the instant the applies
# above return. `kubectl wait pods --all` errors out with "no matching
# resources found" against the still-empty namespace, so we wait on the
# operator's own readiness signal (TigeraStatus) instead. We retry the whole
# `kubectl wait` because (a) the status objects don't exist the moment the
# operator boots and (b) `kubectl wait --all` snapshots the object set at
# start, so a component that appears mid-wait would otherwise be missed.
deadline=$((SECONDS + 300))
until kubectl get tigerastatus --no-headers 2>/dev/null | grep -q . \
   && kubectl wait --for=condition=Available --timeout=60s tigerastatus --all; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "ERROR: Calico did not become ready within the timeout" >&2
    kubectl get tigerastatus || true
    exit 1
  fi
  sleep 5
done
kubectl get pods -n calico-system

# --- 7. Install Postgres ---
echo ""
echo "=== 7. Install Postgres ==="

kubectl create ns postgres --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f postgres.yaml

echo "Waiting for Postgres pod to be ready..."
# Same race as stage 5: `kubectl wait pods --all` errors with "no matching
# resources found" before the StatefulSet controller creates the pod. Wait on
# the rollout instead, which blocks until release-name-postgres-0 is Ready.
kubectl rollout status statefulset/release-name-postgres -n postgres --timeout=180s
kubectl get pods -n postgres

# --- 8. Verify exfiltration ---
echo ""
echo "=== 8. Verify exfiltration is running ==="

if kubectl exec -n postgres release-name-postgres-0 -- ps -C nc &>/dev/null; then
    echo "netcat exfiltration process is running inside the postgres pod."
else
    echo "WARNING: netcat process not found inside postgres pod." >&2
    echo "The stat_collector.sh may have failed. Check:" >&2
    echo "  kubectl logs -n postgres release-name-postgres-0" >&2
fi

# --- 9. Start the exfiltration sink ---
echo ""
echo "=== Setup complete ==="
echo ""
echo "Starting exfiltration sink — attacker C2 listener."
echo "Data flowing here is the evidence for the whole demo."
echo "Leave this terminal running."
echo ""

NC_PATH="$(command -v nc)"
exec sudo "$NC_PATH" -kl 3.14.137.65 137 | pv > /dev/null
