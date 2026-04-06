#!/usr/bin/env bash

set -euo pipefail

APP_NAME="AIPace"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${REPO_ROOT}/app"
INFO_PLIST="${APP_DIR}/Sources/AIPace/Info.plist"
DIST_DIR="${REPO_ROOT}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
STAGING_DIR="${DIST_DIR}/dmg-staging"

SIGN_IDENTITY=""
NOTARY_PROFILE=""
VERSION=""

usage() {
  cat <<'EOF'
Usage: ./scripts/build-dmg.sh [options]

Options:
  --version VERSION           Version to stamp into Info.plist.
  --sign IDENTITY             Sign the app bundle with a Developer ID Application identity.
  --notarize-profile PROFILE  Notarize the DMG with a notarytool keychain profile.
  -h, --help                  Show this help text.

Examples:
  ./scripts/build-dmg.sh --version 0.1.0
  ./scripts/build-dmg.sh --version 0.1.0 \
    --sign "Developer ID Application: Example, Inc. (TEAMID)" \
    --notarize-profile AC_NOTARY
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --sign)
      SIGN_IDENTITY="${2:-}"
      shift 2
      ;;
    --notarize-profile)
      NOTARY_PROFILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${VERSION}" ]]; then
  VERSION="$(
    /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${INFO_PLIST}" \
      | tr -d '\r'
  )"
fi

if [[ -z "${VERSION}" ]]; then
  echo "Unable to determine version. Pass --version." >&2
  exit 1
fi

if [[ -n "${NOTARY_PROFILE}" && -z "${SIGN_IDENTITY}" ]]; then
  echo "--notarize-profile requires --sign because notarization expects a signed app." >&2
  exit 1
fi

DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"

echo "Building ${APP_NAME} ${VERSION}"
mkdir -p "${DIST_DIR}"

(
  cd "${APP_DIR}"
  swift build -c release
)

rm -rf "${APP_BUNDLE}" "${STAGING_DIR}" "${DMG_PATH}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${APP_DIR}/.build/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${INFO_PLIST}" "${APP_BUNDLE}/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist"

chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

if [[ -n "${SIGN_IDENTITY}" ]]; then
  echo "Signing app bundle with ${SIGN_IDENTITY}"
  codesign \
    --force \
    --timestamp \
    --options runtime \
    --sign "${SIGN_IDENTITY}" \
    "${APP_BUNDLE}"

  codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"
fi

mkdir -p "${STAGING_DIR}"
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

echo "Creating DMG at ${DMG_PATH}"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

if [[ -n "${NOTARY_PROFILE}" ]]; then
  echo "Submitting DMG for notarization with profile ${NOTARY_PROFILE}"
  xcrun notarytool submit "${DMG_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait
  xcrun stapler staple "${DMG_PATH}"
fi

echo "Done"
echo "App bundle: ${APP_BUNDLE}"
echo "DMG: ${DMG_PATH}"
