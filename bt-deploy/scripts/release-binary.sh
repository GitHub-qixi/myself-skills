#!/usr/bin/env bash
# Replace an existing systemd executable and roll it back if the release fails health checks.
set -euo pipefail

if [[ $# != 6 ]]; then
  echo "Usage: bash release-binary.sh PACKAGE SHA256 TARGET UNIT RELEASE HEALTH_CHECK" >&2
  exit 2
fi
package=$1
checksum=$2
target=$3
unit=$4
release=$5
health_check=$6

if [[ ! $checksum =~ ^[[:xdigit:]]{64}$ || ! $release =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ||
      ! $unit =~ ^[a-zA-Z0-9][a-zA-Z0-9@._-]*\.service$ ||
      $package != /* || $target != /* || $health_check != /* ]]; then
  echo "Invalid checksum, release, unit or absolute path" >&2
  exit 2
fi
[[ -f $target && -x $target && ! -L $target && -x $health_check ]]
[[ $(systemctl show --property=LoadState --value "$unit") == loaded ]]
directory=$(dirname -- "$target")
exec 9>"$directory/.deploy-${target##*/}.lock"
flock -n 9

actual=$(sha256sum < "$package")
[[ ${actual%% *} == "${checksum,,}" ]] || { echo "SHA-256 mismatch" >&2; exit 1; }
[[ $(tar -tzf "$package") == app ]] || { echo "Expected a single archive member named app" >&2; exit 1; }

backup="$target.before-$release"
[[ ! -e $backup && ! -L $backup ]]
next=$(mktemp -- "$directory/.deploy-next.XXXXXXXX")
rollback_needed=0
cleanup() {
  result=$?
  trap - EXIT INT TERM
  if (( rollback_needed )); then
    if cp -p -- "$backup" "$next" && mv -fT -- "$next" "$target" && systemctl restart "$unit"; then
      echo "Previous binary restored and restart requested. Verify its health." >&2
    else
      echo "Rollback failed. Backup: $backup" >&2
    fi
  fi
  rm -f -- "$next"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

cp -p -- "$target" "$backup"
cp -p -- "$target" "$next"
tar -xOzf "$package" -- app > "$next"
[[ -s $next ]]
rollback_needed=1
mv -fT -- "$next" "$target"
systemctl restart "$unit"
for ((attempt=1; attempt<=15; attempt++)); do
  if timeout 3 "$health_check" "$release"; then
    rollback_needed=0
    printf 'Release %s passed health check. Backup: %s\n' "$release" "$backup"
    exit 0
  fi
  sleep 1
done
echo "Release health check failed" >&2
exit 1
