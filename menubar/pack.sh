#!/bin/zsh
# Pack Pinecone.app to hand out: one app for both kinds of Mac (arm64 and x86_64), in a disk image.
#
#     menubar/pack.sh [version]            # build/Pinecone-<version>.dmg, and build/Pinecone.app
#
# With the five signing secrets in the environment, the app is signed with a Developer ID and the
# hardened runtime, notarised by Apple and stapled, and so is the disk image; then both are checked the
# way another Mac checks them before it opens them. They are the secrets pine's release uses:
#   CSC_LINK            the "Developer ID Application" certificate with its key, a .p12 file, as base64
#   CSC_KEY_PASSWORD    the password of that file
#   APPLE_API_KEY       the path of an App Store Connect API key's .p8 file
#   APPLE_API_KEY_ID    that key's ID
#   APPLE_API_ISSUER    the issuer ID shown above the keys
# Without any of them it is signed ad hoc, which is enough to try it on this Mac and on no other. With only
# some of them it stops: an app that is half signed is one nobody can open.
#
# The universal build needs Xcode (SwiftPM builds two architectures with Xcode's build system); the
# Command Line Tools build for this Mac's kind only, with menubar/build.sh.
set -euo pipefail
cd "$(dirname "$0")"
VERSION=${1:-0.0.0}
if ! print -r -- "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "pack.sh: \"$VERSION\" is not a version like 0.4.2" >&2; exit 1
fi

secrets=(CSC_LINK CSC_KEY_PASSWORD APPLE_API_KEY APPLE_API_KEY_ID APPLE_API_ISSUER)
have=0
for s in $secrets; do [[ -n ${(P)s:-} ]] && have=$((have + 1)); done
if (( have > 0 && have < ${#secrets} )); then
    missing=(); for s in $secrets; do [[ -z ${(P)s:-} ]] && missing+=$s; done
    echo "pack.sh: these signing secrets are missing: ${missing[*]}" >&2; exit 1
fi
sign=$(( have == ${#secrets} ))

# ---- build ----
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Pinecone"
rm -rf build && mkdir -p build/Pinecone.app/Contents/MacOS
APP=build/Pinecone.app
cp "$BIN" "$APP/Contents/MacOS/Pinecone"
cp Info.plist "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"
echo "built $APP $VERSION ($(lipo -archs "$APP/Contents/MacOS/Pinecone"))"

DMG="build/Pinecone-$VERSION.dmg"
work=$(mktemp -d)

if (( ! sign )); then
    codesign --force --sign - "$APP"
else
    # The certificate goes into a keychain of its own for this run, which is taken away again at the end.
    keychain="$work/signing.keychain-db"
    password=$(uuidgen)
    before=("${(@f)$(security list-keychains -d user | tr -d ' "')}")
    cleanup() {
        security list-keychains -d user -s $before >/dev/null 2>&1 || true
        security delete-keychain "$keychain" >/dev/null 2>&1 || true
        rm -rf "$work"
    }
    trap cleanup EXIT
    security create-keychain -p "$password" "$keychain"
    security set-keychain-settings -lut 3600 "$keychain"
    security unlock-keychain -p "$password" "$keychain"
    print -rn -- "$CSC_LINK" | base64 --decode > "$work/certificate.p12"
    security import "$work/certificate.p12" -k "$keychain" -P "$CSC_KEY_PASSWORD" -T /usr/bin/codesign >/dev/null
    rm -f "$work/certificate.p12"
    security set-key-partition-list -S apple-tool:,apple: -s -k "$password" "$keychain" >/dev/null
    security list-keychains -d user -s "$keychain" $before
    identity=$(security find-identity -v -p codesigning "$keychain" | awk '/Developer ID Application/ { print $2; exit }')
    if [[ -z $identity ]]; then echo "pack.sh: CSC_LINK holds no \"Developer ID Application\" certificate" >&2; exit 1; fi

    # Sent to Apple and waited for; when Apple refuses it, its log says why.
    notarise() {
        local out id verdict
        out=$(xcrun notarytool submit "$1" --key "$APPLE_API_KEY" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER" \
            --wait --timeout 30m --output-format json)
        id=$(print -r -- "$out" | plutil -extract id raw -o - -)
        verdict=$(print -r -- "$out" | plutil -extract status raw -o - -)
        echo "notarisation of $(basename "$1"): $verdict ($id)"
        if [[ $verdict != Accepted ]]; then
            xcrun notarytool log "$id" --key "$APPLE_API_KEY" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER" >&2 || true
            exit 1
        fi
    }

    # The app: the hardened runtime, which notarisation asks for, and a secure timestamp.
    codesign --force --options runtime --timestamp --keychain "$keychain" --sign "$identity" "$APP"
    codesign --verify --strict --verbose=2 "$APP"
    ditto -c -k --keepParent "$APP" "$work/Pinecone.zip"
    notarise "$work/Pinecone.zip"
    xcrun stapler staple "$APP"
fi

# ---- the disk image: the app and a way to Applications ----
mkdir -p "$work/image"
cp -R "$APP" "$work/image/"
ln -s /Applications "$work/image/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "Pinecone" -srcfolder "$work/image" -fs HFS+ -format UDZO "$DMG"

if (( sign )); then
    codesign --force --timestamp --keychain "$keychain" --sign "$identity" "$DMG"
    notarise "$DMG"
    xcrun stapler staple "$DMG"
    # What another Mac will say to them.
    spctl --assess --type execute --verbose=2 "$APP"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
    xcrun stapler validate "$APP"
    xcrun stapler validate "$DMG"
else
    rm -rf "$work"
fi
echo "packed $DMG"
