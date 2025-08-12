
# base image
FROM ubuntu:24.04

#input GitHub runner version argument

# Build arguments for local development
ARG GH_OWNER
ARG APP_ID
ARG APP_PRIVATE_KEY
ARG RUNNER_NAME

ENV DEBIAN_FRONTEND=noninteractive
# Set environment variables from build args
ENV GH_OWNER=${GH_OWNER}
ENV APP_ID=${APP_ID}
ENV APP_PRIVATE_KEY=${APP_PRIVATE_KEY}
ENV RUNNER_NAME=${RUNNER_NAME}
# update the base packages + add a non-sudo user
RUN apt-get update -y && apt-get upgrade -y && useradd -m docker


# Install base packages and dependencies (excluding azure-cli)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl nodejs wget unzip vim git jq build-essential libssl-dev libffi-dev \
    python3 python3-venv python3-dev python3-pip \
    apt-transport-https lsb-release gnupg ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Azure CLI using Microsoft's official install script
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash


# Install GitHub Actions runner (using version from build arg)
ARG GITHUB_RUNNER_VERSION
ARG TARGETPLATFORM
RUN set -eux; \
    echo "Runner version: ${GITHUB_RUNNER_VERSION}"; \
    echo "Target platform: ${TARGETPLATFORM}"; \
    [ ! -z "$GITHUB_RUNNER_VERSION" ] || (echo "GITHUB_RUNNER_VERSION build arg is required" && exit 1); \
    mkdir -p /home/docker/actions-runner; \
    cd /home/docker/actions-runner; \
    if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        ARCH="arm64"; \
    else \
        ARCH="x64"; \
    fi; \
    echo "Using architecture: ${ARCH}"; \
    curl -O -L https://github.com/actions/runner/releases/download/v${GITHUB_RUNNER_VERSION}/actions-runner-linux-${ARCH}-${GITHUB_RUNNER_VERSION}.tar.gz; \
    tar xzf actions-runner-linux-${ARCH}-${GITHUB_RUNNER_VERSION}.tar.gz


# add over the start.sh script
ADD start.sh start.sh

# make the script executable
RUN chmod +x start.sh

# set the user to "docker" so all subsequent commands are run as the docker user
USER docker

# set the entrypoint to the start.sh script
ENTRYPOINT ["./start.sh"]
