#!/usr/bin/env bash
# L0 本地自验证 —— 按本项目填写 compile / test / smoke 三段实际命令。
# 被 Stop hook(verify-on-stop.sh) 调用：全过 exit 0；任一步失败 exit 非0 阻止 AI"收工"（守完成度）。
# 重云端依赖项目：先按"Harness 五方法论"做 DIP + Profile 隔离 + H2/本地替代，让本地能一条命令跑起来。
set -e

# 填好下面三段后，把这行的 1 改成 0（或删掉）。否则视为"未配置"：只告警、不守门（exit 0），避免悬空。
SKELETON=1

if [ "${SKELETON:-0}" = "1" ]; then
  echo "⚠ scripts/verify-local.sh 还是骨架（未配置本项目的 compile/test/smoke）——收工时的完成度守门当前空转。" >&2
  echo "  请填好三段命令并把脚本里的 SKELETON=1 改为 0。" >&2
  exit 0
fi

echo "=== 1. 编译 ==="
# <填：如 mvn -q compile -Dspring.profiles.active=local / npm run build / go build ./... / python -m compileall .>

echo "=== 2. 单元测试 ==="
# <填：如 mvn -q test / npm test / pytest -q / go test ./...>

echo "=== 3. 本地启动 + 冒烟 ==="
# <填：启动本地实例并断言健康端点，如：
#   (mvn spring-boot:run -Dspring.profiles.active=local &) ; sleep 15
#   curl -sf http://localhost:8080/actuator/health | grep -q UP
# 或端到端冒烟脚本。>

echo "=== 全部通过 ==="
