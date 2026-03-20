# NanoClaw Agent Container
# Runs Claude Agent SDK in isolated Linux VM with browser automation

FROM local/ubuntu:24.04

# Set proxy for build-time apt/npm operations
ARG HTTP_PROXY
ARG HTTPS_PROXY
ENV http_proxy=$HTTP_PROXY
ENV https_proxy=$HTTPS_PROXY

# Add universe repo and install system dependencies
# Note: chromium is not available as a deb in Ubuntu 24.04 (snap only).
# The host's playwright-managed chromium binary is bind-mounted at runtime.
ARG APT_PROXY
RUN if [ -n "$APT_PROXY" ]; then \
      echo "Acquire::http::Proxy \"$APT_PROXY\";" > /etc/apt/apt.conf.d/99proxy && \
      echo "Acquire::https::Proxy \"$APT_PROXY\";" >> /etc/apt/apt.conf.d/99proxy; \
    fi
RUN echo "deb http://archive.ubuntu.com/ubuntu noble main universe restricted" > /etc/apt/sources.list && \
    echo "deb http://archive.ubuntu.com/ubuntu noble-updates main universe restricted" >> /etc/apt/sources.list && \
    apt-get update && apt-get install -y \
    fonts-liberation \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    libgbm1 \
    libnss3 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libasound2t64 \
    libpangocairo-1.0-0 \
    libcups2 \
    libdrm2 \
    libxshmfence1 \
    curl \
    git \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Add node user (matches node:22-slim behavior)
RUN groupadd --gid 1000 node && \
    useradd --uid 1000 --gid node --shell /bin/bash --create-home node

# Copy pre-built Node.js 22 from build context
COPY node22-minimal.tar.gz /tmp/node22-minimal.tar.gz
RUN mkdir -p /usr/local && tar -xzf /tmp/node22-minimal.tar.gz -C /usr/local && \
    rm /tmp/node22-minimal.tar.gz && \
    chmod +x /usr/local/bin/node && \
    ln -sf /usr/local/bin/node /usr/bin/node && \
    ln -sf /usr/local/bin/npm /usr/bin/npm && \
    ln -sf /usr/local/bin/npx /usr/bin/npx && \
    ln -sf /usr/local/bin/claude /usr/bin/claude && \
    ln -sf /usr/local/bin/agent-browser /usr/bin/agent-browser && \
    chmod +x /usr/local/lib/node_modules/agent-browser/bin/agent-browser-linux-x64

# Playwright chromium is bind-mounted from the host at runtime.
# The host path /root/.cache/ms-playwright/ is mounted to the same path in the container.
ENV AGENT_BROWSER_EXECUTABLE_PATH=/root/.cache/ms-playwright/chromium-1194/chrome-linux/chrome
ENV PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/root/.cache/ms-playwright/chromium-1194/chrome-linux/chrome

# Clear proxy env after installs (don't leak into runtime)
ENV http_proxy=
ENV https_proxy=

# Create app directory
WORKDIR /app

# Copy agent-runner with pre-installed node_modules (installed on host to avoid proxy TLS issues)
COPY agent-runner/ ./

# Build TypeScript
RUN npm run build

# Create workspace directories
RUN mkdir -p /workspace/group /workspace/global /workspace/extra /workspace/ipc/messages /workspace/ipc/tasks /workspace/ipc/input

# Create entrypoint script
# Container input (prompt, group info) is passed via stdin JSON.
# Credentials are injected by the host's credential proxy — never passed here.
# Follow-up messages arrive via IPC files in /workspace/ipc/input/
RUN printf '#!/bin/bash\nset -e\ncd /app && npx tsc --outDir /tmp/dist 2>&1 >&2\nln -s /app/node_modules /tmp/dist/node_modules\nchmod -R a-w /tmp/dist\ncat > /tmp/input.json\nnode /tmp/dist/index.js < /tmp/input.json\n' > /app/entrypoint.sh && chmod +x /app/entrypoint.sh

# Set ownership to node user (non-root) for writable directories
RUN chown -R node:node /workspace && chmod 777 /home/node

# Switch to non-root user (required for --dangerously-skip-permissions)
USER node

# Set working directory to group workspace
WORKDIR /workspace/group

# Entry point reads JSON from stdin, outputs JSON to stdout
ENTRYPOINT ["/app/entrypoint.sh"]
