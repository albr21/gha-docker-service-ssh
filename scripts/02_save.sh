# === Default Variables ===
IMAGE_NAME=""
IMAGE_TAG="latest"
VERBOSE=false

# === Parse Options ===
set -e

while [ "$#" -gt 0 ]; do
  case "$1" in
    --image-name) IMAGE_NAME="$2"; shift 2 ;;
    --image-tag) IMAGE_TAG="${2:-$IMAGE_TAG}"; shift 2 ;;
    --verbose) VERBOSE=true; shift 1 ;;
    *) echo "::error::Invalid option $1"; exit 1 ;;
  esac
done

# === Validate Options ===
if [ -z "$IMAGE_NAME" ]; then
  echo "::error::Usage: $0 --image-name <image_name> [--image-tag <image_tag>] [--verbose]"
  exit 1
fi

FULL_IMAGE_NAME="$IMAGE_NAME:$IMAGE_TAG"
ARCHIVE_NAME="${IMAGE_NAME}_${IMAGE_TAG}.tar.gz"
SHA256_SUM_NAME="${ARCHIVE_NAME}.sha256"

# === SAVE IMAGE ===
echo "📦 Saving docker image..."
docker save "$FULL_IMAGE_NAME" | gzip > "$ARCHIVE_NAME"
sha256sum "$ARCHIVE_NAME" > "$SHA256_SUM_NAME"

echo "✅ Docker image $FULL_IMAGE_NAME saved as $ARCHIVE_NAME successfully!"
echo "✅ SHA256 checksum saved as $SHA256_SUM_NAME successfully!"
