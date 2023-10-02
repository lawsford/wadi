#!/usr/bin/env bash
set -e -o pipefail

declare TEKTON_PIPELINE_VERSION TEKTON_TRIGGERS_VERSION TEKTON_DASHBOARD_VERSION CONTAINER_RUNTIME

get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

TEKTON_PIPELINE_VERSION=$(get_latest_release tektoncd/pipeline)
TEKTON_TRIGGERS_VERSION=$(get_latest_release tektoncd/triggers)
TEKTON_DASHBOARD_VERSION=$(get_latest_release tektoncd/dashboard)

# Install Tekton Pipeline, Triggers and Dashboard
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/previous/${TEKTON_PIPELINE_VERSION}/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/previous/${TEKTON_TRIGGERS_VERSION}/release.yaml
kubectl wait --for=condition=Established --timeout=30s crds/clusterinterceptors.triggers.tekton.dev || true # Starting from triggers v0.13
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/previous/${TEKTON_TRIGGERS_VERSION}/interceptors.yaml || true
kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/previous/${TEKTON_DASHBOARD_VERSION}/release-full.yaml

# Wait until all pods are ready
sleep 10
kubectl wait -n tekton-pipelines --for=condition=ready pods --all --timeout=120s
kubectl port-forward service/tekton-dashboard -n tekton-pipelines 9097:9097 &> kind-tekton-dashboard.log &
echo “Tekton Dashboard available at http://localhost:9097”

until [ $(kubectl get pods -l app.kubernetes.io/component=controller -n ingress-nginx -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') == "True" ]; do
    echo "Waiting for Nginx Ingress Controller to be ready..."
    sleep 15
done

if kubectl get po -n ingress-nginx -o wide | grep controller | grep -q 'Running'; then
   kubectl apply -f resources/tekton/tekton-dashboard-ing.yaml
fi
