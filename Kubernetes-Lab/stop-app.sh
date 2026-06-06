#!/bin/bash
set -e

kubectl scale deployment frontend-deployment --replicas=0 -n zkt26-z2
kubectl scale deployment backend-deployment --replicas=0 -n zkt26-z2
kubectl scale statefulset postgres-statefulset --replicas=0 -n zkt26-z2

echo "Application stopped."
