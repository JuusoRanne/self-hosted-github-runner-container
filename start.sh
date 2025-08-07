#!/bin/bash

# Entrypoint for connecting runner container to Github
#!/bin/bash
set -e

# for running this script, remember to pass in follwing arguments:
# docker run -e GH_TOKEN=... -e GH_OWNER=BusinessFinland -e RUNNER_NAME="my-runner-01"

# Entrypoint for connecting runner container to GitHub

# Validate required environment variables
if [[ -z "$GH_OWNER" || -z "$GH_TOKEN" ]]; then
  echo "❌ Error: GH_OWNER and GH_TOKEN must be set as environment variables."
  exit 1
fi

# Generate unique runner name

echo "🔧 Registering GitHub Actions runner '${RUNNER_NAME}' for org '${GH_OWNER}'..."

# Get org-level registration token
REG_TOKEN=$(curl -sX POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token ${GH_TOKEN}" \
  "https://api.github.com/orgs/${GH_OWNER}/actions/runners/registration-token" \
  | jq -r .token)

if [[ -z "$REG_TOKEN" || "$REG_TOKEN" == "null" ]]; then
  echo "❌ Failed to fetch registration token. Check GH_TOKEN and GH_OWNER."
  exit 1
fi

cd /home/docker/actions-runner

# Configure the runner
./config.sh --unattended \
  --url "https://github.com/${GH_OWNER}" \
  --token "${REG_TOKEN}" \
  --name "${RUNNER_NAME}"

# Cleanup function to deregister on stop
cleanup() {
    echo "🧹 Removing runner..."
    ./config.sh remove --unattended --token "${REG_TOKEN}"
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

echo "✅ Runner '${RUNNER_NAME}' registered and starting..."
./run.sh & wait $!

