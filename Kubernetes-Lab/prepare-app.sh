#!/bin/bash
set -e

echo "Building backend image..."
docker build -t z2-backend:v2 ./backend

echo "Building frontend image..."
docker build -t z2-frontend:latest ./frontend

if command -v minikube >/dev/null 2>&1; then
  echo "Loading images into minikube..."
  minikube image load z2-backend:v2
  minikube image load z2-frontend:latest
else
  echo "minikube not found, skipping image load step."
fi

echo "Preparation finished."
