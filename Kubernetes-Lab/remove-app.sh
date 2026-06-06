#!/bin/bash
set -e

kubectl delete -f service.yaml --ignore-not-found
kubectl delete -f deployment.yaml --ignore-not-found
kubectl delete -f statefulset.yaml --ignore-not-found
kubectl delete -f namespace.yaml --ignore-not-found

echo "Application removed."
