# === Default Variables ===
IMAGE_NAME=""
IMAGE_TAG="latest"
DOCKERFILE="Dockerfile"
DOCKER_CONTEXT="."
VERBOSE=false

# === Parse Options ===
set -e

while [ "$#" -gt 0 ]; do
  case "$1" in
    --image-name) IMAGE_NAME="$2"; shift 2 ;;
    --image-tag) IMAGE_TAG="${2:-$IMAGE_TAG}"; shift 2 ;;
    --dockerfile) DOCKERFILE="${2:-$DOCKERFILE}"; shift 2 ;;
    --docker-context) DOCKER_CONTEXT="${2:-$DOCKER_CONTEXT}"; shift 2 ;;
    --verbose) VERBOSE=true; shift 1 ;;
    *) echo "::error::Invalid option $1"; exit 1 ;;
  esac
done

# === Validate Options ===
if [ -z "$IMAGE_NAME" ]; then
  echo "::error::Usage: $0 --image-name <image_name> [--image-tag <image_tag>] [--dockerfile <dockerfile>] [--docker-context <docker_context>] [--verbose]"
  exit 1
fi

FULL_IMAGE_NAME="$IMAGE_NAME:$IMAGE_TAG"

# === BUILD IMAGE ===
echo "🔧 Building docker image..."
docker build -t "$FULL_IMAGE_NAME" -f "$DOCKERFILE" "$DOCKER_CONTEXT"
echo "✅ Docker image $FULL_IMAGE_NAME built successfully!"
