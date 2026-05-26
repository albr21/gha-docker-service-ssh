# === Default Variables ===
IMAGE_NAME=""
IMAGE_TAG="latest"
USER=""
HOST=""
REMOTE_PATH=""
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
    --verbose) VERBOSE=true; shift 1 ;;
    *) echo "::error::Invalid option $1"; exit 1 ;;
  esac
done

# === Validate Options ===
if [ -z "$IMAGE_NAME" ] || [ -z "$USER" ] || [ -z "$HOST" ] || [ -z "$REMOTE_PATH" ]; then
  echo "::error::Usage: $0 --image-name <image_name> --user <user> --host <host> --remote-path <remote_path> [--image-tag <image_tag>]"
  exit 1
fi

ARCHIVE_NAME="${IMAGE_NAME}_${IMAGE_TAG}.tar.gz"
SHA256_SUM_NAME="${ARCHIVE_NAME}.sha256"

# === TRANSFER FILES ===
echo "📤 Transferring docker image to remote server..."

echo "Ensuring remote path exists..."

SSH_OPTIONS=""
if [ "$VERBOSE" = true ]; then
  SSH_OPTIONS="-vvv"
fi

SCP_OPTIONS=""
if [ "$VERBOSE" = true ]; then
  SCP_OPTIONS="-vvv"
fi

ssh $SSH_OPTIONS "$USER@$HOST" "mkdir -p $REMOTE_PATH"
echo "Transferring $ARCHIVE_NAME to $USER@$HOST:$REMOTE_PATH/$ARCHIVE_NAME ..."
scp $SCP_OPTIONS "$ARCHIVE_NAME" "$USER@$HOST:$REMOTE_PATH/$ARCHIVE_NAME"

echo "✅ Docker image archive $ARCHIVE_NAME transferred successfully to $USER@$HOST:$REMOTE_PATH/"

echo "Transferring $SHA256_SUM_NAME to $USER@$HOST:$REMOTE_PATH/$SHA256_SUM_NAME ..."
scp $SCP_OPTIONS "$SHA256_SUM_NAME" "$USER@$HOST:$REMOTE_PATH/$SHA256_SUM_NAME"

echo "✅ SHA256 checksum $SHA256_SUM_NAME transferred successfully to $USER@$HOST:$REMOTE_PATH/"

echo "✅ All files transferred successfully!"

# === VERIFY TRANSFERRED FILES ===
echo "🔍 Verifying transferred files on remote server..."
ssh $SSH_OPTIONS "$USER@$HOST" "cd $REMOTE_PATH && sha256sum -c $SHA256_SUM_NAME"
if [ $? -ne 0 ]; then
  echo "::error::Checksum verification failed on remote server"
  exit 1
fi

echo "✅ Checksum verification succeeded on remote server!"
