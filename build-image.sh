#!/bin/bash
# Build script for Morea Docker image on Raspberry Pi
# Usage: ./build-image.sh [registry_url] [tag]
# Example: ./build-image.sh 192.168.1.80:5000 latest
# or: ./build-image.sh morea-registry.local latest

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Config
REGISTRY=${1:-""}
TAG=${2:-"latest"}
IMAGE_NAME="morea-app"
DOCKERFILE="./Dockerfile"

# Validate Dockerfile exists
if [ ! -f "$DOCKERFILE" ]; then
    echo -e "${RED}Error: Dockerfile not found at $DOCKERFILE${NC}"
    exit 1
fi

# Print config
echo -e "${YELLOW}=== Morea Docker Build Configuration ===${NC}"
echo "Image Name: $IMAGE_NAME"
echo "Tag: $TAG"
if [ -z "$REGISTRY" ]; then
    FULL_IMAGE="$IMAGE_NAME:$TAG"
    echo "Registry: (local only)"
else
    FULL_IMAGE="$REGISTRY/$IMAGE_NAME:$TAG"
    echo "Registry: $REGISTRY"
fi
echo "Full Image: $FULL_IMAGE"
echo ""

# Step 1: Build image
echo -e "${YELLOW}[1/3] Building Docker image...${NC}"
docker build -t "$FULL_IMAGE" -f "$DOCKERFILE" .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Build successful${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

echo ""

# Step 2: Tag as latest (if tag is not latest)
if [ "$TAG" != "latest" ]; then
    echo -e "${YELLOW}[2/3] Tagging image as 'latest'...${NC}"
    if [ -z "$REGISTRY" ]; then
        docker tag "$FULL_IMAGE" "$IMAGE_NAME:latest"
    else
        docker tag "$FULL_IMAGE" "$REGISTRY/$IMAGE_NAME:latest"
    fi
    echo -e "${GREEN}✓ Tagged${NC}"
    echo ""
fi

# Step 3: Push to registry (if registry provided)
if [ -z "$REGISTRY" ]; then
    echo -e "${YELLOW}[3/3] Skipping push (no registry specified)${NC}"
    echo -e "${GREEN}Image available locally: $FULL_IMAGE${NC}"
else
    echo -e "${YELLOW}[3/3] Pushing to registry...${NC}"
    docker push "$FULL_IMAGE"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Push successful${NC}"
        echo -e "${GREEN}Image ready: $FULL_IMAGE${NC}"
    else
        echo -e "${RED}✗ Push failed (registry may not be accessible or not running)${NC}"
        echo -e "${YELLOW}Image is available locally: $FULL_IMAGE${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}=== Build Complete ===${NC}"
echo "Next steps:"
if [ ! -z "$REGISTRY" ]; then
    echo "1. Update docker-stack.yml to use image: $FULL_IMAGE"
fi
echo "2. Deploy stack: docker stack deploy -c docker-stack.yml morea"
echo "3. Monitor: docker service ls && docker service ps morea_web"

