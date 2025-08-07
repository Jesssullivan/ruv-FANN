#!/usr/bin/env bash

#################################################
# Submodule Build Support Script
# Enables building ruv-FANN as a submodule
#################################################

set -euo pipefail

# Detect if running as submodule
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUV_FANN_ROOT="$(dirname "${SCRIPT_DIR}")"
PARENT_DIR="$(dirname "$(dirname "${RUV_FANN_ROOT}")")"

# Check if we're a submodule
IS_SUBMODULE=false
if [ -f "${PARENT_DIR}/.git" ] || [ -d "${PARENT_DIR}/.git" ]; then
    if grep -q "ruv-FANN" "${PARENT_DIR}/.gitmodules" 2>/dev/null; then
        IS_SUBMODULE=true
    fi
fi

# Export paths for container build
export RUV_FANN_ROOT
export IS_SUBMODULE

# Adapt paths if running as submodule
if [ "$IS_SUBMODULE" = true ]; then
    echo "🔧 Detected submodule installation"
    export DATA_ROOT="${PARENT_DIR}/.mcp-stack/data"
    export CONFIG_ROOT="${PARENT_DIR}/.mcp-stack/config"
    export LOGS_ROOT="${PARENT_DIR}/.mcp-stack/logs"
else
    export DATA_ROOT="${RUV_FANN_ROOT}/data"
    export CONFIG_ROOT="${RUV_FANN_ROOT}/config"
    export LOGS_ROOT="${RUV_FANN_ROOT}/logs"
fi

# Create necessary directories
mkdir -p "${DATA_ROOT}"/{postgres,redis,syncthing,memory,cache}
mkdir -p "${CONFIG_ROOT}"
mkdir -p "${LOGS_ROOT}"

echo "✅ Build environment configured"
echo "   Root: ${RUV_FANN_ROOT}"
echo "   Data: ${DATA_ROOT}"
echo "   Config: ${CONFIG_ROOT}"
echo "   Logs: ${LOGS_ROOT}"