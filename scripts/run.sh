# === Default Variables ===
IMAGE_NAME=""
IMAGE_TAG="latest"
DOCKERFILE="Dockerfile"
DOCKER_CONTEXT="."
USER=""
HOST=""
REMOTE_PATH=""
PORT_MAPPING="" #(hostPort1:containerPort1,hostPort2:containerPort2)
CONTAINER_STOP_TIMEOUT=20
CONTAINER_START_TIMEOUT=180
CONTAINER_STABILITY_WINDOW=20
CONTAINER_WAIT_UNTIL_COMPLETE=false
CONTAINER_SKIP_IF_RUNNING=false
ENVIRONMENT_VARIABLES="" #(VAR1=value1,VAR2=value2)
VOLUME_MAPPING="" #(/host/path:/container/path,/host/path2:/container/path2)
COMMAND=""
DEFAULT_MODE="full"
ENABLED_MODES="full,preload,run-only"
VERBOSE=false
MODE="$DEFAULT_MODE"

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# === Parse Options ===
set -e

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode) MODE="${2:-$DEFAULT_MODE}"; shift 2 ;;
    --image-name) IMAGE_NAME="$2"; shift 2 ;;
    --image-tag) IMAGE_TAG="$2"; shift 2 ;;
    --dockerfile) DOCKERFILE="$2"; shift 2 ;;
    --docker-context) DOCKER_CONTEXT="$2"; shift 2 ;;
    --user) USER="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --remote-path) REMOTE_PATH="$2"; shift 2 ;;
    --port-mapping) PORT_MAPPING="${2:-$PORT_MAPPING}"; shift 2 ;;
    --container-stop-timeout) CONTAINER_STOP_TIMEOUT="${2:-$CONTAINER_STOP_TIMEOUT}"; shift 2 ;;
    --container-start-timeout) CONTAINER_START_TIMEOUT="${2:-$CONTAINER_START_TIMEOUT}"; shift 2 ;;
    --container-stability-window) CONTAINER_STABILITY_WINDOW="${2:-$CONTAINER_STABILITY_WINDOW}"; shift 2 ;;
    --container-wait-until-complete) CONTAINER_WAIT_UNTIL_COMPLETE="${2:-$CONTAINER_WAIT_UNTIL_COMPLETE}"; shift 2 ;;
    --container-skip-if-running) CONTAINER_SKIP_IF_RUNNING="${2:-$CONTAINER_SKIP_IF_RUNNING}"; shift 2 ;;
    --environment-variables) ENVIRONMENT_VARIABLES="${2:-$ENVIRONMENT_VARIABLES}"; shift 2 ;;
    --volume-mapping) VOLUME_MAPPING="${2:-$VOLUME_MAPPING}"; shift 2 ;;
    --verbose) VERBOSE=true; shift 1 ;;
    --command) COMMAND="${2:-$COMMAND}"; shift 2 ;;
    *) echo "::error::Invalid option $1"; exit 1 ;;
  esac
done

handle_error() {
  echo "::error::Issue with the script $1"
  exit 1
}

# === Validate Options ===
valid_mode=false
old_ifs=$IFS
IFS=,
for m in $ENABLED_MODES; do
  if [ "$m" = "$MODE" ]; then
    valid_mode=true
    break
  fi
done
IFS=$old_ifs

if [ "$valid_mode" != "true" ]; then
  echo "::error::Invalid mode: $MODE. Enabled modes are: $ENABLED_MODES"
  exit 1
fi

# === RUN SELECTED MODES ===
if [ "$MODE" = "full" ] || [ "$MODE" = "preload" ]; then
  sh ${SCRIPT_DIR}/01_build.sh \
    --image-name "$IMAGE_NAME" \
    --image-tag "$IMAGE_TAG" \
    --dockerfile "$DOCKERFILE" \
    --docker-context "$DOCKER_CONTEXT" \
    $( [ "$VERBOSE" = true ] && echo "--verbose" ) \
    || handle_error "01_build.sh"

  sh ${SCRIPT_DIR}/02_save.sh \
    --image-name "$IMAGE_NAME" \
    --image-tag "$IMAGE_TAG" \
    $( [ "$VERBOSE" = true ] && echo "--verbose" ) \
    || handle_error "02_save.sh"

  sh ${SCRIPT_DIR}/03_transfer.sh \
    --image-name "$IMAGE_NAME" \
    --image-tag "$IMAGE_TAG" \
    --user "$USER" \
    --host "$HOST" \
    --remote-path "$REMOTE_PATH" \
    $( [ "$VERBOSE" = true ] && echo "--verbose" ) \
    || handle_error "03_transfer.sh"

  sh ${SCRIPT_DIR}/04_remote_load.sh \
    --image-name "$IMAGE_NAME" \
    --image-tag "$IMAGE_TAG" \
    --user "$USER" \
    --host "$HOST" \
    --remote-path "$REMOTE_PATH" \
    --container-stop-timeout "$CONTAINER_STOP_TIMEOUT" \
    --container-skip-if-running "$CONTAINER_SKIP_IF_RUNNING" \
    $( [ "$VERBOSE" = true ] && echo "--verbose" ) \
    || handle_error "04_remote_load.sh"
fi

if [ "$MODE" = "full" ] || [ "$MODE" = "run-only" ]; then
  ENV_ARGS=""
  IFS=',' 
  for pair in $ENVIRONMENT_VARIABLES; do
    ENV_ARGS="$ENV_ARGS --environment $pair"
  done
  unset IFS

  VOLUME_ARGS=""
  IFS=',' 
  for mapping in $VOLUME_MAPPING; do
    VOLUME_ARGS="$VOLUME_ARGS --volume $mapping"
  done
  unset IFS

  PORT_ARGS=""
  IFS=','
  for mapping in $PORT_MAPPING; do
    PORT_ARGS="$PORT_ARGS --port $mapping"
  done
  unset IFS

  sh ${SCRIPT_DIR}/05_remote_run.sh \
    --image-name "$IMAGE_NAME" \
    --image-tag "$IMAGE_TAG" \
    --user "$USER" \
    --host "$HOST" \
    --remote-path "$REMOTE_PATH" \
    $PORT_ARGS \
    --container-stop-timeout "$CONTAINER_STOP_TIMEOUT" \
    --container-start-timeout "$CONTAINER_START_TIMEOUT" \
    --container-stability-window "$CONTAINER_STABILITY_WINDOW" \
    --container-wait-until-complete "$CONTAINER_WAIT_UNTIL_COMPLETE" \
    --container-skip-if-running "$CONTAINER_SKIP_IF_RUNNING" \
    $ENV_ARGS \
    $VOLUME_ARGS \
    --command "$COMMAND" \
    $( [ "$VERBOSE" = true ] && echo "--verbose" ) \
    || handle_error "05_remote_run.sh"
fi
