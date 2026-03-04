#!/bin/bash
# Notion Task Automation - 多数据库支持 Wrapper (P1-1)
# 说明：此脚本作为 automation.sh 的包装器，实现多数据库支持
# 不修改主脚本，保持向后兼容

set -e

WORKSPACE="/home/shiyongwang/.openclaw/workspace"
SKILL_DIR="$WORKSPACE/skills/notion-task-automation"
CONFIG_FILE="$SKILL_DIR/config/databases.json"

# 加载环境变量
if [[ -f "$WORKSPACE/.env" ]]; then
    source "$WORKSPACE/.env"
fi

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

# 检查配置文件
if [[ ! -f "$CONFIG_FILE" ]]; then
    log "多数据库配置文件不存在，使用默认配置"
    # 直接调用主脚本
    exec "$SKILL_DIR/automation.sh" "$@"
fi

# 解析数据库配置
get_databases() {
    jq -c '.databases[] // empty' "$CONFIG_FILE" 2>/dev/null
}

# 检查单个数据库
check_single_db() {
    local db_config="$1"
    local db_name=$(echo "$db_config" | jq -r '.name // "未命名"')
    local db_token=$(echo "$db_config" | jq -r '.token // "'"$NOTION_TOKEN"'"')
    local db_id=$(echo "$db_config" | jq -r '.database_id // "'"$NOTION_DATABASE_ID"'"')
    local enabled=$(echo "$db_config" | jq -r '.enabled // true')
    
    # 跳过禁用的数据库
    [[ "$enabled" != "true" ]] && return 0
    
    log "检查数据库: $db_name"
    
    # 临时设置环境变量
    export NOTION_TOKEN="$db_token"
    export NOTION_DATABASE_ID="$db_id"
    
    # 调用主脚本
    "$SKILL_DIR/automation.sh" check
}

# 主逻辑
main() {
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "🔍 多数据库任务检查"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local db_count=0
    
    # 遍历所有数据库
    while IFS= read -r db_config; do
        [[ -z "$db_config" ]] && continue
        
        db_count=$((db_count + 1))
        check_single_db "$db_config"
        
        # 数据库间延迟，避免API限流
        if [[ $db_count -gt 0 ]]; then
            sleep 2
        fi
    done < <(get_databases)
    
    if [[ $db_count -eq 0 ]]; then
        info "未配置多数据库，使用默认配置"
        "$SKILL_DIR/automation.sh" "$@"
    else
        log "完成 $db_count 个数据库的检查"
    fi
}

# 根据参数执行
if [[ "${1:-}" == "check" ]]; then
    main
else
    # 其他命令直接透传给主脚本
    "$SKILL_DIR/automation.sh" "$@"
fi
