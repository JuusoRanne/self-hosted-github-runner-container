
# base image
FROM ubuntu:24.04

ARG APP_ID
ARG APP_PRIVATE_KEY

#input GitHub runner version argument
ENV DEBIAN_FRONTEND=noninteractive

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


# Install GitHub Actions runner (latest)
RUN set -eux; \
    RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/^v//'); \
    mkdir -p /home/docker/actions-runner; \
    cd /home/docker/actions-runner; \
    curl -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz; \
    tar xzf actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz

    # Remember to change arm64 to x64 if you are not using an ARM architecture


# add over the start.sh script
ADD start.sh start.sh

# make the script executable
RUN chmod +x start.sh

# set the user to "docker" so all subsequent commands are run as the docker user
USER docker

# set the entrypoint to the start.sh script
ENTRYPOINT ["./start.sh"]
