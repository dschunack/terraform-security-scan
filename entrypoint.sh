#!/bin/bash

# set working directory
if [ "${INPUT_TFSEC_ACTIONS_WORKING_DIR}" != "" ] && [ "${INPUT_TFSEC_ACTIONS_WORKING_DIR}" != "." ]; then
  TFSEC_WORKING_DIR="/github/workspace/${INPUT_TFSEC_ACTIONS_WORKING_DIR}"
else
  TFSEC_WORKING_DIR="/github/workspace/"
fi

# grab tfsec from GitHub (taken from README.md)
if [[ -n "$INPUT_TFSEC_VERSION" ]]; then
  env GO111MODULE=on go install github.com/aquasecurity/tfsec/cmd/tfsec@"${INPUT_TFSEC_VERSION}"
  #curl -L -o /tmp/tfsec https://github.com/aquasecurity/tfsec/releases/download/${INPUT_TFSEC_VERSION}/tfsec-linux-amd64
  #chmod +x /tmp/tfsec
else
  env GO111MODULE=on go install github.com/aquasecurity/tfsec/cmd/tfsec@latest
  #curl -L -o /tmp/tfsec https://github.com/aquasecurity/tfsec/releases/download/v1.19.1/tfsec-linux-amd64
  #chmod +x /tmp/tfsec
fi

TFSEC_VERSION=$(/go/bin/tfsec -v)

if [[ -n "$INPUT_TFSEC_EXCLUDE" ]]; then
  #TFSEC_OUTPUT=$(/tmp/tfsec ${TFSEC_WORKING_DIR} --no-colour ${INPUT_TFSEC_ARGS} -e "${INPUT_TFSEC_EXCLUDE}" ${INPUT_TFSEC_OUTPUT_FORMAT:+ -f "$INPUT_TFSEC_OUTPUT_FORMAT"} ${INPUT_TFSEC_OUTPUT_FILE:+ --out "$INPUT_TFSEC_OUTPUT_FILE"})
  TFSEC_OUTPUT=$(/go/bin/tfsec ${TFSEC_WORKING_DIR} --no-colour ${INPUT_TFSEC_ARGS} -e "${INPUT_TFSEC_EXCLUDE}" ${INPUT_TFSEC_OUTPUT_FORMAT:+ -f "$INPUT_TFSEC_OUTPUT_FORMAT"} ${INPUT_TFSEC_OUTPUT_FILE:+ --out "$INPUT_TFSEC_OUTPUT_FILE"})
else
  #TFSEC_OUTPUT=$(/tmp/tfsec ${TFSEC_WORKING_DIR} --no-colour ${INPUT_TFSEC_ARGS} ${INPUT_TFSEC_OUTPUT_FORMAT:+ -f "$INPUT_TFSEC_OUTPUT_FORMAT"} ${INPUT_TFSEC_OUTPUT_FILE:+ --out "$INPUT_TFSEC_OUTPUT_FILE"})
  TFSEC_OUTPUT=$(/go/bin/tfsec ${TFSEC_WORKING_DIR} --no-colour ${INPUT_TFSEC_ARGS} ${INPUT_TFSEC_OUTPUT_FORMAT:+ -f "$INPUT_TFSEC_OUTPUT_FORMAT"} ${INPUT_TFSEC_OUTPUT_FILE:+ --out "$INPUT_TFSEC_OUTPUT_FILE"})
fi
TFSEC_EXITCODE=${?}

# Exit code of 0 indicates success.
if [ "$(grep -c "soft-fail" <<< ${INPUT_TFSEC_ARGS} )" -eq "1" ]
then
  TFSEC_STATUS=""
else
  if [ ${TFSEC_EXITCODE} -eq 0 ]
  then
    TFSEC_STATUS="Success"
  else
    TFSEC_STATUS="Failed"
  fi
fi

# Print output.
echo "${TFSEC_OUTPUT}"

# Comment on the pull request if necessary.
if [ "${INPUT_TFSEC_ACTIONS_COMMENT}" == "1" ] || [ "${INPUT_TFSEC_ACTIONS_COMMENT}" == "true" ]; then
  TFSEC_COMMENT=1
else
  TFSEC_COMMENT=0
fi

if [ "${GITHUB_EVENT_NAME}" == "pull_request" ] && [ -n "${GITHUB_TOKEN}" ] && [ "${TFSEC_COMMENT}" == "1" ]; then
    COMMENT="#### \`Terraform Security Scan\` ${TFSEC_STATUS}

TFSec Version: ${TFSEC_VERSION}

<details><summary>Show Output</summary>

\`\`\`hcl
${TFSEC_OUTPUT}
\`\`\`

</details>"
  PAYLOAD=$(echo "${COMMENT}" | jq -R --slurp '{body: .}')
  URL=$(jq -r .pull_request.comments_url "${GITHUB_EVENT_PATH}")
  echo "${PAYLOAD}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${URL}" > /dev/null
fi

exit $TFSEC_EXITCODE
