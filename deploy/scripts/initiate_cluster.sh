#!/bin/bash

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  echo "Error: This script should be run from within a Git repository."
  exit 1
fi
CONFIG_PATH="$REPO_ROOT/deploy/config/config.yaml"

# Create the cluster volume directory if it doesn't exist
mkdir -p "$REPO_ROOT/cluster-volume"

# Create the Kind cluster using the specified config file
kind create cluster --name local --config "$CONFIG_PATH"

# Confirm cluster is up and running
kubectl cluster-info --context kind-local