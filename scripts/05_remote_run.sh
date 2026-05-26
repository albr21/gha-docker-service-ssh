# === Default Variables ===
IMAGE_NAME=""
IMAGE_TAG="latest"
USER=""
HOST=""
REMOTE_PATH=""
PORT_LIST=""
CONTAINER_STOP_TIMEOUT=20
CONTAINER_START_TIMEOUT=180
CONTAINER_STABILITY_WINDOW=20
CONTAINER_WAIT_UNTIL_COMPLETE=false
CONTAINER_SKIP_IF_RUNNING=false
ENVIRONMENT_LIST=""
VOLUME_LIST=""
COMMAND=""
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
    --port) PORT_LIST="${PORT_LIST} -p $2"; shift 2 ;;
    --container-stop-timeout) CONTAINER_STOP_TIMEOUT="${2:-$CONTAINER_STOP_TIMEOUT}"; shift 2 ;;
    --container-start-timeout) CONTAINER_START_TIMEOUT="${2:-$CONTAINER_START_TIMEOUT}"; shift 2 ;;
    --container-stability-window) CONTAINER_STABILITY_WINDOW="${2:-$CONTAINER_STABILITY_WINDOW}"; shift 2 ;;
    --container-wait-until-complete) CONTAINER_WAIT_UNTIL_COMPLETE="${2:-$CONTAINER_WAIT_UNTIL_COMPLETE}"; shift 2 ;;
    --container-skip-if-running) CONTAINER_SKIP_IF_RUNNING="${2:-$CONTAINER_SKIP_IF_RUNNING}"; shift 2 ;;
    --environment) ENVIRONMENT_LIST="${ENVIRONMENT_LIST} -e $2"; shift 2 ;;
    --volume) VOLUME_LIST="${VOLUME_LIST} -v $2"; shift 2 ;;
    --command) COMMAND="$2"; shift 2 ;;
    --verbose) VERBOSE=true; shift 1 ;;
    *) echo "::error::Invalid option $1"; exit 1 ;;
  esac
done

# === Validate Options ===
if [ -z "$IMAGE_NAME" ] || [ -z "$USER" ] || [ -z "$HOST" ] || [ -z "$REMOTE_PATH" ]; then
  echo "::error::Usage: $0 --image-name <image_name> --user <user> --host <host> --remote-path <remote_path> [--image-tag <image_tag>] [--container-start-timeout <seconds>] [--container-stability-window <seconds>] [--host-port <host_port>] [--container-port <container_port>] [--container-stop-timeout <seconds>] [--environment VAR1=value1] [--environment VAR2=value2] [--volume /host/path:/container/path] [--command <command>]"
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

  echo "🚢 Running Docker container..."
  docker run -d --name "$FULL_CONTAINER_NAME" $PORT_LIST $ENVIRONMENT_LIST $VOLUME_LIST "$FULL_IMAGE_NAME" $COMMAND

  if [ "$CONTAINER_WAIT_UNTIL_COMPLETE" = true ]; then
    echo "🔍 Waiting for container to complete..."
    exit_code=\$(docker wait "$FULL_CONTAINER_NAME")
    if [ $VERBOSE = true ]; then
      echo "Container logs:"
      docker logs "$FULL_CONTAINER_NAME"
    fi

    if [ "\$exit_code" -ne 0 ]; then
      echo "❌ Container exited with code \$exit_code. Logs:"
      docker logs --tail 200 "$FULL_CONTAINER_NAME" || true
      exit 1
    fi
    echo "✅ Container completed successfully with exit code 0."
    exit 0
  fi

  # Else perform stability check
  echo "🔍 Window-Stability checking..."
  deadline=\$(( \$(date +%s) + $CONTAINER_START_TIMEOUT ))
  stable_since=""

  while :; do
    status=\$(docker inspect -f '{{.State.Status}}' "$FULL_CONTAINER_NAME" 2>/dev/null || echo "notfound")
    now=\$(date +%s)

    case "\$status" in
      running)
        if [ -z "\$stable_since" ]; then
          stable_since=\$now
        fi
        if [ \$(( now - stable_since )) -ge "$CONTAINER_STABILITY_WINDOW" ]; then
          echo "Container has been stable for ${CONTAINER_STABILITY_WINDOW}s."
          echo "✅ Deployment completed successfully!"
          break
        fi
        ;;
      exited|dead|removing|notfound)
        echo "❌ Container failed (status=\$status). Logs:"
        docker logs --tail 200 "$FULL_CONTAINER_NAME" || true
        exit 1
        ;;
      *)
        stable_since=""
        ;;
    esac

    if [ "\$now" -ge "\$deadline" ]; then
      echo "❌ Timeout after ${CONTAINER_START_TIMEOUT}s without reaching stability."
      docker logs --tail 200 "$FULL_CONTAINER_NAME" || true
      exit 1
    fi

    sleep 2
  done
EOF
