#!/bin/bash

set -e
set -o nounset
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" ; pwd -P)

# shellcheck source=./go.variables
source "${SCRIPT_DIR}/go.variables"

goal_login-pipeline() {
  pushd "${SCRIPT_DIR}" > /dev/null
  fly --target "${CONCOURSE_TARGET}" login \
      --concourse-url "${CONCOURSE_URL}" \
      --username "${CONCOURSE_USER}" \
      --password "${CONCOURSE_PASSWORD}"
  popd > /dev/null
}

goal_validate-pipeline() {
  pushd "${SCRIPT_DIR}" > /dev/null
  fly validate-pipeline -c "${PIPELINE_FILE}"
  popd > /dev/null
}

goal_update-pipeline() {
  pushd "${SCRIPT_DIR}" > /dev/null
  goal_login-pipeline
  fly --target "${CONCOURSE_TARGET}" sync
  fly --target "${CONCOURSE_TARGET}" set-pipeline \
      --non-interactive \
      --pipeline "${PIPELINE_NAME}" \
      --config "${PIPELINE_FILE}"
  popd > /dev/null
}

json2yaml() {
  python3 -c 'import sys, yaml, json; print(yaml.dump(json.loads(sys.stdin.read())))'
}

goal_generate-pipeline() {
  FILES=$(jsonnet pipeline.jsonnet -J ../concourse-jsonnet-utils -m .)

  for file in $FILES; do
    json2yaml < "$file" > "${file%.json}.yml"
    rm "$file"
  done
}

goal_linter-sh() {
  shellcheck go*
}

goal_linter-js() {
  npm run linter:js
}

goal_linter-css() {
  npm run linter:css
}

goal_linter-docker() {
  dockerfiles=$(find . -name 'Dockerfile*' -not -path './node_modules/*' -print | tr '\n' ' ')
  # shellcheck disable=SC2086
  hadolint ${dockerfiles}
}

goal_test-js() {
  npm test
}

goal_build() {
  npm run build
}

validate-args() {
  acceptable_args="$(declare -F | sed -n "s/declare -f goal_//p" | tr '\n' ' ')"

  if [[ -z $1 ]]; then
    echo "usage: $0 <goal>"
    # shellcheck disable=SC1117,SC2059
    printf "\n$(declare -F | sed -n "s/declare -f goal_/ - /p")"
    exit 1
  fi

  if [[ ! " $acceptable_args " =~ .*\ $1\ .* ]]; then
    echo "Invalid argument: $1"
    # shellcheck disable=SC1117,SC2059
    printf "\n$(declare -F | sed -n "s/declare -f goal_/ - /p")"
    exit 1
  fi
}

CMD=${1:-}
shift || true
if validate-args "${CMD}"; then
  "goal_${CMD}"
  exit 0
fi
