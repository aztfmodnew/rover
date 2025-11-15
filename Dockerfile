###########################################################
# Azure CAF Rover - Optimized Dockerfile
# Multi-stage build for Terraform, Azure CLI, and DevOps tools
###########################################################

###########################################################
# Stage 1: Base Image with System Dependencies
###########################################################
FROM ubuntu:24.04 AS base

SHELL ["/bin/bash", "-c"]

# Build arguments
ARG versionVault \
    versionKubectl \
    versionKubelogin \
    versionDockerCompose \
    versionPowershell \
    versionPacker \
    versionGolang \
    versionTerraformDocs \
    versionAnsible \
    versionTerrascan \
    versionTfupdate \
    extensionsAzureCli \
    SSH_PASSWD \
    TARGETARCH \
    TARGETOS

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

# Metadata labels
LABEL maintainer="aztfmodnew" \
      description="Azure Cloud Adoption Framework Terraform Rover" \
      version="${versionRover}" \
      org.opencontainers.image.source="https://github.com/aztfmodnew/rover" \
      org.opencontainers.image.licenses="MIT"

# Environment variables
ENV SSH_PASSWD=${SSH_PASSWD} \
    USERNAME=${USERNAME} \
    versionVault=${versionVault} \
    versionGolang=${versionGolang} \
    versionKubectl=${versionKubectl} \
    versionKubelogin=${versionKubelogin} \
    versionDockerCompose=${versionDockerCompose} \
    versionTerraformDocs=${versionTerraformDocs} \
    versionPacker=${versionPacker} \
    versionPowershell=${versionPowershell} \
    versionAnsible=${versionAnsible} \
    extensionsAzureCli=${extensionsAzureCli} \
    versionTerrascan=${versionTerrascan} \
    versionTfupdate=${versionTfupdate} \
    PATH="${PATH}:/opt/mssql-tools/bin:/opt/mssql-tools18/bin:/home/vscode/.local/lib/shellspec/bin:/home/vscode/go/bin:/usr/local/go/bin" \
    TF_DATA_DIR="/home/${USERNAME}/.terraform.cache" \
    TF_PLUGIN_CACHE_DIR="/tf/cache" \
    TF_REGISTRY_DISCOVERY_RETRY=5 \
    TF_REGISTRY_CLIENT_TIMEOUT=15 \
    ARM_USE_MSGRAPH=true \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true

WORKDIR /tf/rover

# Copy configuration files early for better layer caching
COPY ./scripts/.kubectl_aliases ./scripts/zsh-autosuggestions.zsh ./

###########################################################
# Stage 2: System Packages and APT Repositories
###########################################################
RUN set -e && \
    echo "==> Installing base system packages..." && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Essential tools
        bsdmainutils \
        ca-certificates \
        curl \
        fonts-powerline \
        gcc \
        gettext \
        git \
        gpg \
        gpg-agent \
        jq \
        less \
        locales \
        make \
        python3-dev \
        python3-pip \
        rsync \
        software-properties-common \
        gosu \
        sudo \
        unzip \
        vim \
        wget \
        zsh \
        zip \
        # Networking tools
        dnsutils \
        net-tools \
        iputils-ping \
        openssh-client && \
    #
    echo "==> Creating user ${USERNAME}..." && \
    (groupadd docker 2>/dev/null || true) && \
    if ! id -u ${USERNAME} >/dev/null 2>&1; then \
        useradd --uid $USER_UID -m -G docker ${USERNAME} || \
        useradd -m -G docker ${USERNAME}; \
    fi && \
    #
    echo "==> Setting locale..." && \
    locale-gen en_US.UTF-8 && \
    #
    echo "==> Cleaning apt cache..." && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

###########################################################
# Stage 3: Add External Repositories
###########################################################
RUN set -e && \
    echo "==> Adding Microsoft repository..." && \
    curl -sSL --retry 3 --retry-delay 2 https://packages.microsoft.com/keys/microsoft.asc | \
        gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg && \
    echo "deb [arch=${TARGETARCH} signed-by=/etc/apt/trusted.gpg.d/microsoft.gpg] https://packages.microsoft.com/ubuntu/24.04/prod noble main" | \
        gosu root tee /etc/apt/sources.list.d/microsoft-prod.list && \
    #
    echo "==> Adding Docker repository..." && \
    curl -fsSL --retry 3 --retry-delay 2 https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/trusted.gpg.d/docker-archive-keyring.gpg && \
    echo "deb [arch=${TARGETARCH} signed-by=/etc/apt/trusted.gpg.d/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu noble stable" | \
        gosu root tee /etc/apt/sources.list.d/docker.list && \
    #
    echo "==> Adding GitHub CLI repository..." && \
    curl -fsSL --retry 3 --retry-delay 2 https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
        gosu root dd of=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
        tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    #
    echo "==> Installing packages from external repos..." && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        docker-ce-cli \
        gh && \
    #
    echo "==> Cleaning apt cache..." && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

###########################################################
# Stage 4: Install Binary Tools (Kubernetes, Docker Compose, etc.)
###########################################################
RUN set -e && \
    echo "==> Installing kubectl ${versionKubectl}..." && \
    curl -fsSLO --retry 3 --retry-delay 2 \
        "https://dl.k8s.io/release/v${versionKubectl}/bin/${TARGETOS}/${TARGETARCH}/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl && \
    kubectl version --client && \
    #
    echo "==> Installing Docker Compose ${versionDockerCompose}..." && \
    mkdir -p /usr/libexec/docker/cli-plugins/ && \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        COMPOSE_ARCH="x86_64"; \
    else \
        COMPOSE_ARCH="aarch64"; \
    fi && \
    curl -fsSL -o /usr/libexec/docker/cli-plugins/docker-compose \
        "https://github.com/docker/compose/releases/download/v${versionDockerCompose}/docker-compose-${TARGETOS}-${COMPOSE_ARCH}" && \
    chmod +x /usr/libexec/docker/cli-plugins/docker-compose && \
    docker compose version && \
    #
    echo "==> Installing Helm..." && \
    curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash && \
    helm version && \
    #
    echo "==> Installing kubectl node shell..." && \
    curl -fsSL -o /usr/local/bin/kubectl-node_shell \
        https://github.com/kvaps/kubectl-node-shell/raw/master/kubectl-node_shell && \
    chmod +x /usr/local/bin/kubectl-node_shell

###########################################################
# Stage 5: Install Terraform Tools (tflint, tfsec, terrascan, etc.)
###########################################################
RUN set -e && \
    echo "==> Installing tflint (latest)..." && \
    curl -fsSL -o /tmp/tflint.zip \
        "https://github.com/terraform-linters/tflint/releases/latest/download/tflint_${TARGETOS}_${TARGETARCH}.zip" && \
    unzip -o /tmp/tflint.zip -d /usr/bin && \
    chmod +x /usr/bin/tflint && \
    rm /tmp/tflint.zip && \
    tflint --version && \
    #
    echo "==> Installing tfsec (latest)..." && \
    curl -fsSL -o /bin/tfsec \
        "https://github.com/tfsec/tfsec/releases/latest/download/tfsec-${TARGETOS}-${TARGETARCH}" && \
    chmod +x /bin/tfsec && \
    tfsec --version && \
    #
    echo "==> Installing terrascan v${versionTerrascan}..." && \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        TERRASCAN_ARCH="x86_64"; \
    else \
        TERRASCAN_ARCH="${TARGETARCH}"; \
    fi && \
    curl -fsSL -o /tmp/terrascan.tar.gz \
        "https://github.com/tenable/terrascan/releases/download/v${versionTerrascan}/terrascan_${versionTerrascan}_Linux_${TERRASCAN_ARCH}.tar.gz" && \
    tar -xzf /tmp/terrascan.tar.gz -C /tmp terrascan && \
    install /tmp/terrascan /usr/local/bin && \
    rm -rf /tmp/terrascan* && \
    terrascan version && \
    #
    echo "==> Installing tfupdate v${versionTfupdate}..." && \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        TFUPDATE_ARCH="amd64"; \
    else \
        TFUPDATE_ARCH="${TARGETARCH}"; \
    fi && \
    curl -fsSL -o /tmp/tfupdate.tar.gz \
        "https://github.com/minamijoyo/tfupdate/releases/download/v${versionTfupdate}/tfupdate_${versionTfupdate}_linux_${TFUPDATE_ARCH}.tar.gz" && \
    tar -xzf /tmp/tfupdate.tar.gz -C /tmp tfupdate && \
    install /tmp/tfupdate /usr/local/bin && \
    rm -rf /tmp/tfupdate* && \
    tfupdate --version && \
    #
    echo "==> Installing terraform-docs v${versionTerraformDocs}..." && \
    curl -fsSL -o /tmp/terraform-docs.tar.gz \
        "https://github.com/terraform-docs/terraform-docs/releases/download/v${versionTerraformDocs}/terraform-docs-v${versionTerraformDocs}-${TARGETOS}-${TARGETARCH}.tar.gz" && \
    tar -xzf /tmp/terraform-docs.tar.gz -C /usr/bin terraform-docs && \
    chmod +x /usr/bin/terraform-docs && \
    rm /tmp/terraform-docs.tar.gz && \
    terraform-docs --version && \
    #
    echo "==> Installing tflint ruleset for Azure (latest)..." && \
    curl -fsSL -o /tmp/tflint-ruleset-azurerm.zip \
        "https://github.com/terraform-linters/tflint-ruleset-azurerm/releases/latest/download/tflint-ruleset-azurerm_${TARGETOS}_${TARGETARCH}.zip" && \
    mkdir -p /home/${USERNAME}/.tflint.d/plugins /home/${USERNAME}/.tflint.d/config && \
    unzip -o /tmp/tflint-ruleset-azurerm.zip -d /home/${USERNAME}/.tflint.d/plugins && \
    rm /tmp/tflint-ruleset-azurerm.zip && \
    echo 'plugin "azurerm" {' > /home/${USERNAME}/.tflint.d/config/.tflint.hcl && \
    echo '    enabled = true' >> /home/${USERNAME}/.tflint.d/config/.tflint.hcl && \
    echo '}' >> /home/${USERNAME}/.tflint.d/config/.tflint.hcl

###########################################################
# Stage 6: Install HashiCorp Tools (Packer, Vault)
###########################################################
RUN set -e && \
    echo "==> Installing Packer ${versionPacker}..." && \
    curl -fsSL -o /tmp/packer.zip \
        "https://releases.hashicorp.com/packer/${versionPacker}/packer_${versionPacker}_${TARGETOS}_${TARGETARCH}.zip" && \
    unzip -o /tmp/packer.zip -d /usr/bin && \
    chmod +x /usr/bin/packer && \
    rm /tmp/packer.zip && \
    packer version && \
    #
    echo "==> Installing Vault ${versionVault}..." && \
    curl -fsSL -o /tmp/vault.zip \
        "https://releases.hashicorp.com/vault/${versionVault}/vault_${versionVault}_${TARGETOS}_${TARGETARCH}.zip" && \
    unzip -o /tmp/vault.zip -d /usr/bin && \
    chmod +x /usr/bin/vault && \
    setcap cap_ipc_lock=-ep /usr/bin/vault && \
    rm /tmp/vault.zip && \
    vault version

###########################################################
# Stage 7: Install Azure Tools (Kubelogin, PowerShell)
###########################################################
RUN set -e && \
    echo "==> Installing Kubelogin ${versionKubelogin}..." && \
    curl -fsSL -o /tmp/kubelogin.zip \
        "https://github.com/Azure/kubelogin/releases/download/v${versionKubelogin}/kubelogin-${TARGETOS}-${TARGETARCH}.zip" && \
    unzip -o /tmp/kubelogin.zip -d /usr && \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        chmod +x /usr/bin/linux_amd64/kubelogin; \
    else \
        chmod +x /usr/bin/linux_arm64/kubelogin; \
    fi && \
    rm /tmp/kubelogin.zip && \
    #
    echo "==> Installing PowerShell ${versionPowershell}..." && \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        PS_ARCH="x64"; \
    else \
        PS_ARCH="${TARGETARCH}"; \
    fi && \
    curl -fsSL -o /tmp/powershell.tar.gz \
        "https://github.com/PowerShell/PowerShell/releases/download/v${versionPowershell}/powershell-${versionPowershell}-${TARGETOS}-${PS_ARCH}.tar.gz" && \
    mkdir -p /opt/microsoft/powershell/7 && \
    tar -xzf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 && \
    chmod +x /opt/microsoft/powershell/7/pwsh && \
    ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh && \
    rm /tmp/powershell.tar.gz && \
    pwsh --version

###########################################################
# Stage 8: Install Python Tools (pip packages)
###########################################################
RUN set -e && \
    echo "==> Installing pre-commit..." && \
    pip3 install --break-system-packages --ignore-installed pre-commit && \
    #
    echo "==> Installing yq..." && \
    pip3 install --break-system-packages yq && \
    #
    echo "==> Installing Azure CLI..." && \
    pip3 install --break-system-packages --ignore-installed azure-cli && \
    az version && \
    az extension add --name ${extensionsAzureCli} --system && \
    az extension add --name containerapp --system && \
    az config set extension.use_dynamic_install=yes_without_prompt && \
    az config set core.login_experience_v2=false && \
    #
    echo "==> Installing checkov..." && \
    pip3 install --break-system-packages --ignore-installed checkov && \
    #
    echo "==> Installing pywinrm..." && \
    pip3 install --break-system-packages pywinrm && \
    #
    echo "==> Installing Ansible ${versionAnsible}..." && \
    pip3 install --break-system-packages ansible-core==${versionAnsible} && \
    #
    echo "==> Verifying installations..." && \
    pre-commit --version && \
    ansible --version && \
    checkov --version

###########################################################
# Stage 9: Install Development Tools (Golang, shellspec)
###########################################################
RUN set -e && \
    echo "==> Installing Golang ${versionGolang}..." && \
    curl -fsSL -o /tmp/golang.tar.gz \
        "https://go.dev/dl/go${versionGolang}.${TARGETOS}-${TARGETARCH}.tar.gz" && \
    tar -C /usr/local -xzf /tmp/golang.tar.gz && \
    rm /tmp/golang.tar.gz && \
    export PATH=$PATH:/usr/local/go/bin && \
    go version && \
    #
    echo "==> Installing shellspec..." && \
    curl -fsSL https://git.io/shellspec | sh -s -- --yes && \
    #
    echo "==> Installing git completions..." && \
    mkdir -p /etc/bash_completion.d/ && \
    curl -fsSL https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash \
        -o /etc/bash_completion.d/git-completion.bash

###########################################################
# Stage 10: Install Optional Tools (mssql-tools for amd64)
###########################################################
RUN set -e && \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        echo "==> Installing mssql-tools (amd64 only)..." && \
        echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/microsoft.gpg] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" > /etc/apt/sources.list.d/mssql-release.list && \
        apt-get update && \
        ACCEPT_EULA=Y apt-get install -y --no-install-recommends unixodbc msodbcsql18 mssql-tools18 && \
        ln -sf /opt/mssql-tools18/bin/sqlcmd /usr/local/bin/sqlcmd && \
        ln -sf /opt/mssql-tools18/bin/bcp /usr/local/bin/bcp && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*; \
    else \
        echo "==> Skipping mssql-tools (not available for ${TARGETARCH})"; \
    fi

###########################################################
# Stage 11: Configure User Environment
###########################################################
RUN set -e && \
    echo "==> Creating directory structure..." && \
    mkdir -p \
        /tf/caf \
        /tf/rover \
        /tf/logs \
        /tf/cache \
        /home/${USERNAME}/.ansible \
        /home/${USERNAME}/.azure \
        /home/${USERNAME}/.gnupg \
        /home/${USERNAME}/.packer.d \
        /home/${USERNAME}/.ssh \
        /home/${USERNAME}/.ssh-localhost \
        /home/${USERNAME}/.terraform.logs \
        /home/${USERNAME}/.terraform.cache \
        /home/${USERNAME}/.terraform.cache/tfstates \
        /home/${USERNAME}/.terraform.cache/plugin-cache \
        /home/${USERNAME}/.vscode-server \
        /home/${USERNAME}/.vscode-server-insiders \
        /commandhistory && \
    #
    echo "==> Setting permissions..." && \
    chown -R ${USER_UID}:${USER_GID} \
        /home/${USERNAME} \
        /tf/rover \
        /tf/caf \
        /tf/logs \
        /tf/cache \
        /commandhistory && \
    chmod 777 -R /home/${USERNAME} /tf/caf /tf/rover && \
    chmod 700 /home/${USERNAME}/.ssh && \
    #
    echo "==> Configuring sudo..." && \
    echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME} && \
    #
    echo "==> Configuring bash history..." && \
    touch /commandhistory/.bash_history && \
    chown ${USERNAME}:${USERNAME} /commandhistory/.bash_history && \
    echo 'set -o history' >> /home/${USERNAME}/.bashrc && \
    echo 'export HISTCONTROL=ignoredups:erasedups' >> /home/${USERNAME}/.bashrc && \
    echo 'PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'"'"'\n'"'"'}history -a; history -c; history -r"' >> /home/${USERNAME}/.bashrc && \
    echo '[ -f /tf/rover/.kubectl_aliases ] && source /tf/rover/.kubectl_aliases' >> /home/${USERNAME}/.bashrc && \
    echo 'alias watch="watch "' >> /home/${USERNAME}/.bashrc && \
    #
    echo "==> Final cleanup..." && \
    apt-get remove -y gcc python3-dev apt-utils 2>/dev/null || true && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* && \
    find / -type f -name "*.pyc" -delete 2>/dev/null || true && \
    find / -type d -name "__pycache__" -delete 2>/dev/null || true

###########################################################
# Stage 12: User Configuration (Oh My Zsh)
###########################################################
USER ${USERNAME}

COPY .devcontainer/.zshrc /home/${USERNAME}/
COPY ./scripts/sshd_config /home/${USERNAME}/.ssh/sshd_config

RUN set -e && \
    echo "==> Installing Oh My Zsh..." && \
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | \
        bash -s -- --unattended && \
    chmod 700 -R /home/${USERNAME}/.oh-my-zsh && \
    #
    echo "==> Configuring zsh..." && \
    echo 'DISABLE_UNTRACKED_FILES_DIRTY="true"' >> /home/${USERNAME}/.zshrc && \
    echo 'alias rover=/tf/rover/rover.sh' >> /home/${USERNAME}/.zshrc && \
    echo 'alias t=/usr/bin/terraform' >> /home/${USERNAME}/.zshrc && \
    echo 'alias k=/usr/bin/kubectl' >> /home/${USERNAME}/.zshrc && \
    echo 'cd /tf/caf || true' >> /home/${USERNAME}/.zshrc && \
    echo '[ -f /tf/rover/.kubectl_aliases ] && source /tf/rover/.kubectl_aliases' >> /home/${USERNAME}/.zshrc && \
    echo 'source /tf/rover/zsh-autosuggestions.zsh' >> /home/${USERNAME}/.zshrc && \
    echo 'alias watch="watch "' >> /home/${USERNAME}/.zshrc && \
    #
    echo "==> Syncing bash and zsh aliases..." && \
    echo 'alias rover=/tf/rover/rover.sh' >> /home/${USERNAME}/.bashrc && \
    echo 'alias t=/usr/bin/terraform' >> /home/${USERNAME}/.bashrc && \
    echo 'alias k=/usr/bin/kubectl' >> /home/${USERNAME}/.bashrc && \
    echo 'cd /tf/caf || true' >> /home/${USERNAME}/.bashrc

###########################################################
# Final Stage: Install Terraform
###########################################################
FROM base AS final

ARG versionTerraform \
    USERNAME=vscode \
    versionRover \
    TARGETOS \
    TARGETARCH

ENV versionRover=${versionRover} \
    versionTerraform=${versionTerraform}

USER root

RUN set -e && \
    echo "==> Installing Terraform ${versionTerraform}..." && \
    curl -fsSL -o /tmp/terraform.zip \
        "https://releases.hashicorp.com/terraform/${versionTerraform}/terraform_${versionTerraform}_${TARGETOS}_${TARGETARCH}.zip" && \
    unzip -o /tmp/terraform.zip -d /usr/bin && \
    chmod +x /usr/bin/terraform && \
    rm /tmp/terraform.zip && \
    terraform version && \
    #
    echo "==> Setting rover version..." && \
    echo "${versionRover}" > /tf/rover/version.txt && \
    #
    echo "==> Creating plugin cache directory..." && \
    mkdir -p /home/${USERNAME}/.terraform.cache/plugin-cache && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.terraform.cache

USER ${USERNAME}

# Copy rover scripts
COPY --chown=${USERNAME}:${USERNAME} \
    ./scripts/rover.sh \
    ./scripts/tfstate.sh \
    ./scripts/functions.sh \
    ./scripts/remote.sh \
    ./scripts/parse_command.sh \
    ./scripts/banner.sh \
    ./scripts/clone.sh \
    ./scripts/walkthrough.sh \
    ./scripts/sshd.sh \
    ./scripts/backend.hcl.tf \
    ./scripts/backend.azurerm.tf \
    ./scripts/ci.sh \
    ./scripts/cd.sh \
    ./scripts/task.sh \
    ./scripts/symphony_yaml.sh \
    ./scripts/test_runner.sh \
    /tf/rover/

COPY --chown=${USERNAME}:${USERNAME} ./scripts/ci_tasks/* /tf/rover/ci_tasks/
COPY --chown=${USERNAME}:${USERNAME} ./scripts/lib/* /tf/rover/lib/
COPY --chown=${USERNAME}:${USERNAME} ./scripts/tfcloud/* /tf/rover/tfcloud/

# Set working directory
WORKDIR /tf/caf

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD terraform version && az version && kubectl version --client || exit 1

# Default command
CMD ["/bin/bash"]
