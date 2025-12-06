#!/bin/bash
# deploy-swarm.sh - Script para build e deploy no Docker Swarm
# Use: ./deploy-swarm.sh [build|deploy|remove]

set -e

PROJECT_NAME="morea"
IMAGE_NAME="morea-ds-web"
IMAGE_TAG="latest"
REGISTRY="${REGISTRY:-}"  # Se usar registry privado, defina: export REGISTRY=myregistry.com

SWARM_MANAGER_IP="192.168.1.80"
ACTION="${1:-deploy}"

echo "=== Morea Docker Swarm Deployment ==="
echo "Action: $ACTION"
echo "Image: $IMAGE_NAME:$IMAGE_TAG"

case "$ACTION" in
  build)
    echo "Building Docker image..."
    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
    if [ ! -z "$REGISTRY" ]; then
      echo "Tagging for registry: $REGISTRY/${IMAGE_NAME}:${IMAGE_TAG}"
      docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
      echo "Pushing to registry..."
      docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
    fi
    echo "✓ Build completed"
    ;;

  deploy)
    echo "Checking if Swarm is initialized..."
    if ! docker info | grep -q "Swarm: active"; then
      echo "Error: Docker Swarm not active. Initialize with: docker swarm init"
      exit 1
    fi
    
    echo "Deploying stack..."
    docker stack deploy -c docker-stack.yml ${PROJECT_NAME}
    
    echo "Waiting for services to stabilize (10s)..."
    sleep 10
    
    echo "Stack status:"
    docker stack ps ${PROJECT_NAME}
    echo "✓ Stack deployed"
    ;;

  remove)
    echo "Removing stack..."
    docker stack rm ${PROJECT_NAME}
    echo "✓ Stack removed"
    ;;

  logs)
    SERVICE="${2:-web}"
    echo "Logs for service: $SERVICE"
    docker service logs ${PROJECT_NAME}_${SERVICE} -f
    ;;

  *)
    echo "Usage: $0 {build|deploy|remove|logs [service]}"
    exit 1
    ;;
esac
