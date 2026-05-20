#!/bin/sh
set -e

CONFIGURATION_NAME="${FIREBASE_CONFIGURATION:-controller-courier.qa}"
SOURCE_FILE="${SRCROOT}/Runner/Firebase/GoogleService-Info-${CONFIGURATION_NAME}.plist"
DESTINATION_FILE="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"

if [ ! -f "$SOURCE_FILE" ]; then
  echo "error: Firebase iOS config not found: ${SOURCE_FILE}" >&2
  echo "error: Copy GoogleService-Info-controller-courier.qa.plist and/or GoogleService-Info-controller-user.qa.plist into ios/Runner/Firebase." >&2
  echo "error: Current FIREBASE_CONFIGURATION=${CONFIGURATION_NAME}" >&2
  exit 1
fi

mkdir -p "$(dirname "$DESTINATION_FILE")"
cp "$SOURCE_FILE" "$DESTINATION_FILE"

echo "Firebase iOS config copied: ${SOURCE_FILE}"
