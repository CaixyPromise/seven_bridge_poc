#!/usr/bin/env bash
set -euo pipefail

# 用法：
#   bash create_seven_bridge_poc.sh [repo_dir]
#
# 例子：
#   bash create_seven_bridge_poc.sh seven-bridge-addon-repo

REPO_DIR="${1:-seven-bridge-addon-repo}"
ADDON_DIR="${REPO_DIR}/seven_bridge_poc"

echo "Creating repo at: ${REPO_DIR}"
mkdir -p "${ADDON_DIR}"

# -----------------------------------------------------------------------------
# repository.yaml
# 根目录必需：HA 识别 GitHub add-on/app 仓库要靠它
# -----------------------------------------------------------------------------
cat > "${REPO_DIR}/repository.yaml" <<'YAML'
name: Seven Agent Add-ons
url: https://github.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME
maintainer: YOUR_NAME <YOUR_EMAIL@example.com>
YAML

# -----------------------------------------------------------------------------
# seven_bridge_poc/config.yaml
# App/Add-on 清单
# -----------------------------------------------------------------------------
cat > "${ADDON_DIR}/config.yaml" <<'YAML'
name: Seven Bridge PoC
version: "0.0.1"
slug: seven_bridge_poc
description: "PoC for validating Supervisor add-on management permissions"
arch:
  - aarch64
startup: services
boot: manual
hassio_api: true
hassio_role: manager
homeassistant_api: false
ingress: false
YAML

# -----------------------------------------------------------------------------
# seven_bridge_poc/Dockerfile
# 使用 HA add-on 基础镜像；安装 curl + jq 便于验证输出
# -----------------------------------------------------------------------------
cat > "${ADDON_DIR}/Dockerfile" <<'DOCKERFILE'
ARG BUILD_FROM
FROM $BUILD_FROM

RUN apk add --no-cache curl jq

COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
DOCKERFILE

# -----------------------------------------------------------------------------
# seven_bridge_poc/run.sh
# 启动后直接验证关键 Supervisor 端点，并保持容器存活，方便看日志/exec
# -----------------------------------------------------------------------------
cat > "${ADDON_DIR}/run.sh" <<'BASH'
#!/usr/bin/with-contenv bashio
set -euo pipefail

echo "=== Seven Bridge PoC starting ==="

if [ -z "${SUPERVISOR_TOKEN:-}" ]; then
  echo "ERROR: SUPERVISOR_TOKEN is empty"
  sleep infinity
fi

echo "SUPERVISOR_TOKEN length: ${#SUPERVISOR_TOKEN}"

call() {
  local method="$1"
  local url="$2"
  local body="${3:-}"

  echo
  echo "=================================================================="
  echo ">>> ${method} ${url}"
  echo "=================================================================="

  if [ -n "${body}" ]; then
    curl -i -sS -X "${method}" \
      -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "${body}" \
      "${url}" || true
  else
    curl -i -sS -X "${method}" \
      -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
      "${url}" || true
  fi
  echo
}

# 1) 基础信息
call GET "http://supervisor/info"

# 2) 全局 add-on 枚举（最关键）
call GET "http://supervisor/addons"

# 3) Store add-on 枚举（最关键）
call GET "http://supervisor/store/addons"

# 4) 后台 jobs
call GET "http://supervisor/jobs/info"

# 5) 用 Matter Server 作为已知样本做详情读取
call GET "http://supervisor/addons/core_matter_server/info"

# 6) Stats 读取
call GET "http://supervisor/addons/core_matter_server/stats"

# 7) options config 读取（如果支持）
call GET "http://supervisor/addons/core_matter_server/options/config"

# 8) validate 试探（只校验，不落盘）
call POST "http://supervisor/addons/core_matter_server/options/validate" \
'{"options":{"log_level":"info","log_level_sdk":"error","beta":false,"enable_test_net_dcl":false}}'

echo
echo "=== Validation finished. Container will now stay alive. ==="
sleep infinity
BASH

chmod +x "${ADDON_DIR}/run.sh"

# -----------------------------------------------------------------------------
# 可选：.gitignore
# -----------------------------------------------------------------------------
cat > "${REPO_DIR}/.gitignore" <<'GITIGNORE'
.DS_Store
GITIGNORE

# -----------------------------------------------------------------------------
# 可选：README.md
# -----------------------------------------------------------------------------
cat > "${REPO_DIR}/README.md" <<'MARKDOWN'
# Seven Agent Add-ons

This repository contains a PoC Home Assistant add-on used to validate
Supervisor permissions for managing add-ons.

## Included add-ons

- `seven_bridge_poc`

## Notes

- Update `repository.yaml` with your real GitHub repository URL
- Bump the version in `seven_bridge_poc/config.yaml` when you change files
MARKDOWN

echo
echo "Done."
echo "Next steps:"
echo "1) Edit ${REPO_DIR}/repository.yaml and replace the placeholder GitHub URL"
echo "2) git init && git add . && git commit -m 'init seven bridge poc'"
echo "3) Push to GitHub"
echo "4) In Home Assistant Add-on Store, add the GitHub repo URL"
