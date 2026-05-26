# === Default Variables ===
IMAGE_NAME=""
IMAGE_TAG="latest"
USER=""
HOST=""
REMOTE_PATH=""
CONTAINER_STOP_TIMEOUT=20
CONTAINER_SKIP_IF_RUNNING=false
VERBOSE=false

# === Parse Options ===
set -e

while [ "$#" -gt 0 ]; do
  case "$1" in
    --image-name) IMAGE_NAME="$2"; shift 2 ;;
    --image-tag) IMAGE_TAG="${2:-$IMAGE_TAG}"; shift 2 ;;
    --user) USER="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --remote-path) REMOTE_PATH="$2"; shift 2 ;;
    --container-stop-timeout) CONTAINER_STOP_TIMEOUT="${2:-$CONTAINER_STOP_TIMEOUT}"; shift 2 ;;
    --container-skip-if-running) CONTAINER_SKIP_IF_RUNNING="${2:-$CONTAINER_SKIP_IF_RUNNING}"; shift 2 ;;
    --verbose) VERBOSE=true; shift 1 ;;
    *) echo "::error::Invalid option $1"; exit 1 ;;
  esac
done

# === Validate Options ===
if [ -z "$IMAGE_NAME" ] || [ -z "$USER" ] || [ -z "$HOST" ] || [ -z "$REMOTE_PATH" ]; then
  echo "::error::Usage: $0 --image-name <image_name> --user <user> --host <host> --remote-path <remote_path> [--image-tag <image_tag>] [--container-stop-timeout <seconds>] [--container-skip-if-running <true|false>] [--verbose]"
  exit 1
fi

FULL_IMAGE_NAME="$IMAGE_NAME:$IMAGE_TAG"
FULL_CONTAINER_NAME="${IMAGE_NAME}_container"
ARCHIVE_NAME="${IMAGE_NAME}_${IMAGE_TAG}.tar.gz"

SSH_OPTIONS=""
if [ "$VERBOSE" = true ]; then
  SSH_OPTIONS="-vvv"
fi

# === REMOTE DEPLOY ===
echo "🚀 Deploying on remote server..."
ssh $SSH_OPTIONS "$USER@$HOST" sh << EOF
  set -e
  cd "$REMOTE_PATH"

  if [ "$CONTAINER_SKIP_IF_RUNNING" = true ]; then
    if docker ps --filter "name=^/${FULL_CONTAINER_NAME}$" --filter "status=running" | grep -q "$FULL_CONTAINER_NAME"; then
      echo "⚠️ Container $FULL_CONTAINER_NAME is already running. Skipping deployment as per configuration."
      exit 0
    fi
  fi

  echo "🛑 Stopping and Removing old container if exist..."
  docker stop -t "$CONTAINER_STOP_TIMEOUT" "$FULL_CONTAINER_NAME" || docker kill "$FULL_CONTAINER_NAME" || true
  docker rm -f "$FULL_CONTAINER_NAME" || true

  echo "♻️ Removing old Docker image if exists..."
  docker rmi "$FULL_IMAGE_NAME" || true

  echo "🔄 Loading Docker image..."
  docker load < "$ARCHIVE_NAME"

  echo "✅ Docker image $FULL_IMAGE_NAME loaded successfully on remote server!"
EOF
