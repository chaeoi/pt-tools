#!/bin/sh
set -eu

# The SDK uses a fixed 64-bit limit in a field of type int.
sdk=github.com/larksuite/oapi-sdk-go/v3
go mod download "$sdk"
sdk_dir=$(go list -m -f '{{.Dir}}' "$sdk")

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
mkdir "$work_dir/sdk"
cp -R "$sdk_dir/." "$work_dir/sdk/"
chmod -R u+rwX "$work_dir/sdk"
iterator="$work_dir/sdk/service/drive/v1/api_ext.go"
if ! grep -Eq 'limit:[[:space:]]+math\.MaxInt64' "$iterator"; then
    echo "Check whether the upstream Lark SDK still needs the ARMhf patch" >&2
    exit 1
fi
sed 's/\(limit:[[:space:]]*\)math\.MaxInt64/\1math.MaxInt/' "$iterator" >"$work_dir/api_ext.go"
cp "$work_dir/api_ext.go" "$iterator"

cp go.mod "$work_dir/armhf.mod"
cp go.sum "$work_dir/armhf.sum"
go mod edit -modfile="$work_dir/armhf.mod" -replace="$sdk=$work_dir/sdk"
GOOS=linux GOARCH=arm GOARM=7 CGO_ENABLED=0 go build -modfile="$work_dir/armhf.mod" "$@"
