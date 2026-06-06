#!/bin/bash

set -e

echo "Running app ..."
docker compose up -d
echo "The app is available at http://localhost:8080"
echo "Adminer is available at http://localhost:8081"
echo "Backend API is available at http://localhost:5000"
