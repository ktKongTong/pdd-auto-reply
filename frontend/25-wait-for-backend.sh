#!/bin/sh
# frontend/25-wait-for-backend.sh
# ==============================================================================
# 启动探测脚本：等待后端 upstream 域名在内网 DNS 中解析就绪。
# 解决 Nginx 在容器冷启动时因 backend 尚未注册导致 "host not found in upstream" 崩溃。
# ==============================================================================

if [ -n "$BACKEND_API_URL" ]; then
    # 提取主机名（去除 http:// 或 https:// 前缀及端口号）
    HOST=$(echo "$BACKEND_API_URL" | sed -E 's|https?://([^:/]+).*|\1|')

    if [ -n "$HOST" ] && [ "$HOST" != "localhost" ] && [ "$HOST" != "127.0.0.1" ]; then
        echo "[wait-for-backend] Checking DNS resolution for upstream host '$HOST'..."
        resolved=0
        for i in $(seq 1 30); do
            # Alpine 默认内置 nslookup / ping（BusyBox 包含）
            if nslookup "$HOST" > /dev/null 2>&1 || ping -c 1 -W 1 "$HOST" > /dev/null 2>&1; then
                echo "[wait-for-backend] Upstream host '$HOST' resolved successfully (attempt $i)."
                resolved=1
                break
            fi
            sleep 1
        done

        if [ "$resolved" -eq 0 ]; then
            echo "[wait-for-backend] WARNING: Upstream host '$HOST' not resolvable after 30s. Proceeding to start nginx anyway..."
        fi
    fi
fi
