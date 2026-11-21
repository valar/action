#!/usr/bin/env bash
# Runs deploy.sh against stub valar and gh commands and checks the calls it
# makes. Usage: scripts/deploy_test.sh
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0
token=valar_ut_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef

mkdir -p "$tmp/bin" "$tmp/work"
printf 'project: acme\nservice: web\n' >"$tmp/work/.valar.yml"

# The stub logs each call with the token it sees. STUB_EXCHANGE is the
# output of auth exchange, or "fail".
cat >"$tmp/bin/valar" <<'EOF'
#!/usr/bin/env bash
echo "$* | token=${VALAR_TOKEN:-}" >>"$STUB_LOG"
case "$1 $2" in
"auth exchange")
	[ "$STUB_EXCHANGE" = fail ] && exit 4
	echo "$STUB_EXCHANGE"
	;;
"build push") echo 0123456789abcdef ;;
"service url") echo https://acme-web.valar.app ;;
esac
EOF
printf '#!/usr/bin/env bash\nexit 0\n' >"$tmp/bin/gh"
chmod +x "$tmp/bin/valar" "$tmp/bin/gh"

# run runs deploy.sh with the given variables and leaves its exit code in
# $code, and its output, step outputs and the stub's calls in $seen.
run() {
	local out
	: >"$tmp/log"
	: >"$tmp/output"
	out=$(env -i PATH="$tmp/bin:/usr/bin:/bin" HOME="$tmp" STUB_LOG="$tmp/log" \
		STUB_EXCHANGE="$token" GITHUB_OUTPUT="$tmp/output" GITHUB_STEP_SUMMARY="$tmp/summary" \
		GITHUB_REPOSITORY=acme/web INPUT_WORKDIR="$tmp/work" "$@" bash "$root/scripts/deploy.sh" 2>&1)
	code=$?
	seen="$(cat "$tmp/log" "$tmp/output")"$'\n'"$out"
}

check() {
	local name=$1 want_code=$2
	shift 2
	if [ "$code" != "$want_code" ]; then
		echo "FAIL $name: exit $code, want $want_code"$'\n'"$seen"
		failures=$((failures + 1))
		return
	fi
	local want
	for want in "$@"; do
		case "$want" in
		!*)
			if grep -qF -- "${want#!}" <<<"$seen"; then
				echo "FAIL $name: has ${want#!}"$'\n'"$seen"
				failures=$((failures + 1))
			fi
			;;
		*)
			if ! grep -qF -- "$want" <<<"$seen"; then
				echo "FAIL $name: lacks $want"$'\n'"$seen"
				failures=$((failures + 1))
			fi
			;;
		esac
	done
}

oidc=(ACTIONS_ID_TOKEN_REQUEST_URL=https://token.example/id ACTIONS_ID_TOKEN_REQUEST_TOKEN=request)
pr=(INPUT_PREVIEW=true INPUT_SERVICE=web EVENT_NAME=pull_request PR_HEAD_REPO=acme/web GITHUB_REF=refs/pull/42/merge PR_NUMBER=42)

run VALAR_TOKEN=stored "${oidc[@]}"
check "token input" 0 "build push --wait --timeout 30m | token=stored" "service url | token=stored" "!auth exchange"

run "${oidc[@]}"
check "identity token" 0 "auth exchange | token=" "::add-mask::$token" \
	"build push --wait --timeout 30m | token=$token" "service url | token=$token"

run "${oidc[@]}" INPUT_SERVICE=api INPUT_AUDIENCE=https://valar.example.com
check "audience" 0 "auth exchange --service api --audience https://valar.example.com" "build push --service api"

run
check "neither" 1 "::error::The token input is empty" "!build push"

run "${oidc[@]}" STUB_EXCHANGE=fail
check "refused exchange" 1 "::error::Could not exchange" "!build push"

run "${oidc[@]}" STUB_EXCHANGE="Manage user and service permissions."
check "older CLI" 1 "::error::Could not exchange" "!build push" "!::add-mask::"

run "${oidc[@]}" STUB_EXCHANGE="$token"$'\n'"BASH_ENV=/tmp/evil"
check "two lines" 1 "::error::Could not exchange" "!build push" "!::add-mask::"

run "${oidc[@]}" STUB_EXCHANGE=valar_ut_0123
check "short token" 1 "::error::Could not exchange" "!build push"

run "${oidc[@]}" GITHUB_EVENT_NAME=pull_request_target
check "pull_request_target" 1 "::error::pull_request_target runs with" "!auth exchange" "!build push"

run "${oidc[@]}" EVENT_NAME=workflow_run
check "workflow_run" 1 "::error::workflow_run runs with" "!auth exchange" "!build push"

run VALAR_TOKEN=stored GITHUB_EVENT_NAME=workflow_run
check "token input on workflow_run" 0 "build push --wait --timeout 30m | token=stored"

run "${oidc[@]}" "${pr[@]}" PR_ACTION=synchronize
check "preview" 0 "auth exchange --service webpr42 | token=" "build push --service webpr42 --wait" "service=webpr42"

run "${oidc[@]}" "${pr[@]}" PR_ACTION=closed
check "closed preview" 0 "auth exchange --service webpr42" "service disable --service webpr42 | token=$token" "!build push"

run "${oidc[@]}" "${pr[@]}" PR_ACTION=reopened GITHUB_REF=refs/pull/7/head PR_NUMBER=
check "number from ref" 0 "auth exchange --service webpr7" "service enable --service webpr7" "build push --service webpr7"

run "${oidc[@]}" "${pr[@]}" PR_ACTION=opened PR_HEAD_REPO=fork/web
check "fork" 0 "Pull requests from forks get no preview" "!auth exchange"

if [ "$failures" != 0 ]; then
	echo "$failures failed"
	exit 1
fi
echo "all passed"
