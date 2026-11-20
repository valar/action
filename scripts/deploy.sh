#!/usr/bin/env bash
# Pushes the working directory to Valar, waits for the result, and reports it
# as step outputs, a job summary and, for previews, a pull request comment.
set -uo pipefail

service=${INPUT_SERVICE:-}
preview=
marker=

# A closed pull request needs no files: its preview is only disabled.
if [ "${INPUT_PREVIEW:-false}" != true ] || [ "${PR_ACTION:-}" != closed ]; then
	cd "${INPUT_WORKDIR:-.}" || {
		echo "::error::workdir ${INPUT_WORKDIR:-.} does not exist; check out the repository first."
		exit 1
	}
fi

summary() {
	[ -n "${GITHUB_STEP_SUMMARY:-}" ] && printf '%s\n' "$@" >>"$GITHUB_STEP_SUMMARY"
	return 0
}

# configured_service prints the service named in the nearest .valar.yml.
configured_service() {
	local dir=$PWD
	while :; do
		if [ -f "$dir/.valar.yml" ]; then
			sed -n 's/^service:[[:space:]]*["'\'']\{0,1\}\([A-Za-z][A-Za-z0-9]*\).*/\1/p' "$dir/.valar.yml" | head -n1
			return
		fi
		[ "$dir" = / ] && return
		dir=$(dirname "$dir")
	done
}

# comment creates or updates the preview comment on the pull request.
comment() {
	local body="$marker"$'\n'"$1" id
	if ! command -v gh >/dev/null; then
		echo "::notice::gh is not installed, so the preview URL is not commented on the pull request."
		return
	fi
	id=$(gh api "repos/$GITHUB_REPOSITORY/issues/$PR_NUMBER/comments" --paginate \
		--jq ".[] | select(.body | startswith(\"$marker\")) | .id" 2>/dev/null | head -n1)
	if [ -n "$id" ]; then
		gh api -X PATCH "repos/$GITHUB_REPOSITORY/issues/comments/$id" -f body="$body" >/dev/null
	else
		gh api "repos/$GITHUB_REPOSITORY/issues/$PR_NUMBER/comments" -f body="$body" >/dev/null
	fi || echo "::warning::Could not comment on the pull request; the job needs pull-requests: write."
}

if [ "${INPUT_PREVIEW:-false}" = true ]; then
	if [ "${EVENT_NAME:-}" != pull_request ]; then
		echo "::error::preview: true works on pull_request events only, not ${EVENT_NAME:-none}."
		exit 1
	fi
	if [ "${PR_HEAD_REPO:-}" != "${GITHUB_REPOSITORY:-}" ]; then
		echo "::notice::Pull requests from forks get no preview."
		exit 0
	fi
	base=${service:-$(configured_service)}
	if [ -z "$base" ]; then
		echo "::error::preview: true needs a service, from the service input or .valar.yml."
		exit 1
	fi
	service="${base}pr${PR_NUMBER}"
	preview=$service
	marker="<!-- valar-preview:$base -->"
	echo "service=$service" >>"$GITHUB_OUTPUT"
	case "${PR_ACTION:-}" in
	closed)
		if valar service disable --service "$service"; then
			comment "Preview \`$service\` was disabled when this pull request closed."
			summary "Disabled preview \`$service\`."
		else
			echo "::warning::Could not disable preview $service."
		fi
		exit 0
		;;
	reopened)
		valar service enable --service "$service" ||
			echo "::warning::Could not enable preview $service again; deploying anyway."
		;;
	esac
elif [ -n "$service" ]; then
	echo "service=$service" >>"$GITHUB_OUTPUT"
fi

args=(build push)
[ -n "$service" ] && args+=(--service "$service")
[ "${INPUT_DEPLOY:-true}" = false ] && args+=(--no-deploy)
wait=false
if [ "${INPUT_WAIT:-true}" = true ]; then
	wait=true
	args+=(--wait --timeout "${INPUT_TIMEOUT:-30m}")
fi

echo "::group::valar ${args[*]}"
build_id=$(valar "${args[@]}")
status=$?
echo "::endgroup::"
build_id=$(printf '%s\n' "$build_id" | head -n1)
echo "build-id=$build_id" >>"$GITHUB_OUTPUT"

url=
if [ "$status" = 0 ] && [ "$wait" = true ] && [ "${INPUT_DEPLOY:-true}" != false ]; then
	url_args=(service url)
	[ -n "$service" ] && url_args+=(--service "$service")
	url=$(valar "${url_args[@]}" 2>/dev/null | head -n1) || url=
fi
echo "url=$url" >>"$GITHUB_OUTPUT"

if [ "$status" = 0 ]; then
	result="succeeded"
	[ "$wait" = false ] && result="submitted"
else
	result="**failed**"
fi
summary "### Valar deploy" "" "| | |" "|---|---|" \
	"| Service | \`${service:-from .valar.yml}\` |" \
	"| Build | \`${build_id:-none}\` |" \
	"| Result | $result |"
[ -n "$url" ] && summary "| URL | $url |"

if [ -n "$preview" ]; then
	if [ "$status" = 0 ] && [ -n "$url" ]; then
		comment "Preview of this pull request: $url (\`$preview\`, build \`$build_id\`)"
	elif [ "$status" != 0 ]; then
		comment "The preview deploy of \`$preview\` failed in [this run]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID)."
	fi
fi
if [ "$status" != 0 ]; then
	echo "::error::Valar deploy failed${build_id:+ (build $build_id)}."
fi
exit $status
