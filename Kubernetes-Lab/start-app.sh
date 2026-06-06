#!/bin/bash
set -e

kubectl apply -f namespace.yaml
kubectl apply -f statefulset.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

echo "Application started."
echo "Frontend NodePort is 30080."
echo "For Minikube on WSL use: minikube service frontend-service -n zkt26-z2 --url"
