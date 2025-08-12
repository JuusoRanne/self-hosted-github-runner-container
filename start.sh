#!/bin/bash
set -e

# Validate required environment variables
if [[ -z "$APP_ID" || -z "$APP_PRIVATE_KEY" || -z "$GH_OWNER" ]]; then
  echo "❌ Error: APP_ID, APP_PRIVATE_KEY, and GH_OWNER must be set as environment variables."
  exit 1
fi

# Function to generate a JWT for the GitHub App
generate_jwt() {
  local header='{"alg":"RS256","typ":"JWT"}'
  local payload="{\"iat\":$(date +%s),\"exp\":$(($(date +%s) + 600)),\"iss\":\"${APP_ID}\"}"
  
  local header_b64=$(echo -n "${header}" | openssl base64 -e -A | tr -d '=')
  local payload_b64=$(echo -n "${payload}" | openssl base64 -e -A | tr -d '=')
  
  local signature=$(echo -n "${header_b64}.${payload_b64}" | openssl dgst -sha256 -sign <(echo "${APP_PRIVATE_KEY}") | openssl base64 -e -A | tr -d '=' | tr '/+' '_-')
  
  echo "${header_b64}.${payload_b64}.${signature}"
}

# Generate JWT and get installation token for the GitHub App
echo "🔒 Generating GitHub App JWT..."
JWT=$(generate_jwt)

# Get the installation ID for the GitHub App
echo "🔧 Fetching installation ID for owner '${GH_OWNER}'..."
INSTALLATION_ID=$(curl -s \
  -H "Authorization: Bearer ${JWT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations" \
  | jq -r --arg owner "${GH_OWNER}" '.[] | select(.account.login == $owner) | .id')

if [[ -z "$INSTALLATION_ID" || "$INSTALLATION_ID" == "null" ]]; then
  echo "❌ Failed to fetch installation ID. Check the App permissions and GH_OWNER."
  exit 1
fi

# Get an installation access token
echo "🔑 Fetching installation access token..."
INSTALLATION_TOKEN=$(curl -s \
  -X POST \
  -H "Authorization: Bearer ${JWT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/${INSTALLATION_ID}/access_tokens" \
  | jq -r '.token')

if [[ -z "$INSTALLATION_TOKEN" || "$INSTALLATION_TOKEN" == "null" ]]; then
  echo "❌ Failed to fetch installation token. Check the App permissions."
  exit 1
fi

# Get org-level registration token
echo "🔧 Fetching registration token for the self-hosted runner..."
REG_TOKEN=$(curl -sX POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${INSTALLATION_TOKEN}" \
  "https://api.github.com/orgs/${GH_OWNER}/actions/runners/registration-token" \
  | jq -r .token)

if [[ -z "$REG_TOKEN" || "$REG_TOKEN" == "null" ]]; then
  echo "❌ Failed to fetch registration token. Check the App permissions."
  exit 1
fi

cd /home/docker/actions-runner

# Generate unique runner name with timestamp and random suffix
UNIQUE_RUNNER_NAME="${RUNNER_NAME}-$(date +%s)-$(openssl rand -hex 4)"

# Configure the GitHub Actions runner
echo "🔧 Configuring GitHub Actions runner '${UNIQUE_RUNNER_NAME}' for org '${GH_OWNER}'..."
./config.sh --unattended \
  --url "https://github.com/${GH_OWNER}" \
  --token "${REG_TOKEN}" \
  --name "${UNIQUE_RUNNER_NAME}"

# Cleanup function to deregister runner on stop
cleanup() {
  echo "🧹 Removing runner..."
  
  # Generate fresh JWT and get new installation token for removal
  local cleanup_jwt=$(generate_jwt)
  local cleanup_token=$(curl -s \
    -X POST \
    -H "Authorization: Bearer ${cleanup_jwt}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/app/installations/${INSTALLATION_ID}/access_tokens" \
    | jq -r '.token')
  
  if [[ -n "$cleanup_token" && "$cleanup_token" != "null" ]]; then
    # Get fresh removal token
    local removal_token=$(curl -sX POST \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${cleanup_token}" \
      "https://api.github.com/orgs/${GH_OWNER}/actions/runners/remove-token" \
      | jq -r .token)
    
    if [[ -n "$removal_token" && "$removal_token" != "null" ]]; then
      ./config.sh remove --unattended --token "${removal_token}"
      echo "✅ Runner removed successfully"
    else
      echo "⚠️ Failed to get removal token, runner may remain registered"
    fi
  else
    echo "⚠️ Failed to get cleanup token, runner may remain registered"  
  fi
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

echo "✅ Runner '${UNIQUE_RUNNER_NAME}' registered and starting..."

# Run the GitHub Actions runner and exit after one job
./run.sh --once

# Cleanup after normal completion
cleanup
