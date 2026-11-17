#!/bin/sh
# Installs Gõ Dấu on this Mac from a prebuilt zip. Run it with:
#   curl -fsSL <base-url>/install.sh | sh
# It downloads GoDau.zip, checks its SHA-256 and code signature, replaces any installed copy, and opens the app.
# It does not use sudo and does not change system settings. You grant the permissions yourself afterwards.
#
# Settings (environment):
#   GODAU_BASE_URL     where GoDau.zip and GoDau.zip.sha256 are (default: the value set at release time)
#   GODAU_INSTALL_DIR  where to put GoDau.app (default: /Applications, else ~/Applications)
#   GODAU_NO_OPEN=1    do not open the app after installing
set -eu

base_url=${GODAU_BASE_URL:-__GODAU_BASE_URL__}
bundle_id=io.github.sonqh.godau
minimum_macos=13

fail() { printf '%s\n' "Lỗi: $1" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || fail "Gõ Dấu chỉ chạy trên macOS."
macos_major=$(sw_vers -productVersion | cut -d. -f1)
[ "$macos_major" -ge "$minimum_macos" ] || fail "Cần macOS $minimum_macos trở lên. Máy này là $(sw_vers -productVersion)."
case "$base_url" in
    __*__|"") fail "Chưa có địa chỉ tải. Đặt GODAU_BASE_URL rồi chạy lại." ;;
esac
base_url=${base_url%/}

work=$(mktemp -d "${TMPDIR:-/tmp}/godau-install.XXXXXX")
trap 'rm -rf "$work"' EXIT INT TERM

printf '%s\n' "Đang tải Gõ Dấu từ $base_url ..."
curl -fsSL --proto '=https,file' -o "$work/GoDau.zip" "$base_url/GoDau.zip" || fail "Không tải được GoDau.zip."
curl -fsSL --proto '=https,file' -o "$work/GoDau.zip.sha256" "$base_url/GoDau.zip.sha256" \
    || fail "Không tải được GoDau.zip.sha256."

expected=$(cut -d' ' -f1 "$work/GoDau.zip.sha256")
actual=$(shasum -a 256 "$work/GoDau.zip" | cut -d' ' -f1)
[ -n "$expected" ] && [ "$expected" = "$actual" ] || fail "Mã SHA-256 không khớp. Không cài."

ditto -x -k "$work/GoDau.zip" "$work/unpacked"
app="$work/unpacked/GoDau.app"
[ -d "$app" ] || fail "File tải về không chứa GoDau.app."
codesign --verify --strict "$app" 2>/dev/null || fail "Chữ ký của GoDau.app không hợp lệ. Không cài."
found_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")
[ "$found_id" = "$bundle_id" ] || fail "GoDau.app có bundle ID lạ ($found_id). Không cài."
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")

if [ -n "${GODAU_INSTALL_DIR:-}" ]; then
    install_dir=$GODAU_INSTALL_DIR
elif [ -w /Applications ]; then
    install_dir=/Applications
else
    install_dir=$HOME/Applications
fi
mkdir -p "$install_dir"
target=$install_dir/GoDau.app

# Stop a running copy from this location and wait up to 5 s before replacing its files.
if pkill -TERM -f "$target/Contents/MacOS/VietMac" 2>/dev/null; then
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -f "$target/Contents/MacOS/VietMac" >/dev/null || break
        sleep 0.5
    done
fi
rm -rf "$target"
ditto "$app" "$target"
# curl sets no quarantine flag; this covers a zip that was downloaded another way.
xattr -dr com.apple.quarantine "$target" 2>/dev/null || true
codesign --verify --strict "$target" || fail "Bản đã cài không qua được kiểm tra chữ ký."

printf '%s\n' "Đã cài Gõ Dấu $version vào $target."
if [ "${GODAU_NO_OPEN:-}" != 1 ]; then
    open "$target"
    printf '%s\n' "Gõ Dấu đã mở. Tìm biểu tượng EN hoặc VI trên thanh menu và làm theo màn hình cài đặt."
fi
printf '%s\n' "Sau mỗi lần cập nhật, macOS có thể yêu cầu cấp lại quyền Trợ năng (Accessibility) cho Gõ Dấu."
