#!/bin/bash
# Notion Task Automation - 多渠道通知发送器 (P2-2)

CONFIG_FILE="$(dirname "$0")/../config/notifications.json"

# 加载配置
load_notification_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "{}"
        return
    fi
    cat "$CONFIG_FILE"
}

# 发送 Feishu 通知
send_feishu() {
    local message="$1"
    local target="${2:-user:ou_33e8141e4496f0a674219423723997bf}"
    
    export OPENCLAW_WORKSPACE="/home/shiyongwang/.openclaw/workspace"
    
    /usr/bin/node /home/shiyongwang/.npm-global/bin/openclaw message send \
        --channel feishu \
        --target "$target" \
        --message "$message" 2>&1
}

# 发送邮件通知（简化版，需要配置 mail 命令）
send_email() {
    local subject="$1"
    local body="$2"
    local to="${3:-}"
    
    if [[ -z "$to" ]]; then
        echo "邮件收件人未配置，跳过邮件发送"
        return 1
    fi
    
    # 如果配置了 sendmail 或 mail 命令
    if command -v mail &>/dev/null; then
        echo "$body" | mail -s "$subject" "$to"
        echo "邮件已发送至: $to"
    else
        echo "mail 命令未安装，跳过邮件发送"
        return 1
    fi
}

# 发送 Slack 通知
send_slack() {
    local message="$1"
    local webhook="${2:-}"
    
    if [[ -z "$webhook" ]]; then
        echo "Slack webhook 未配置"
        return 1
    fi
    
    curl -s -X POST "$webhook" \
        -H 'Content-type: application/json' \
        --data "{\"text\":\"$message\"}" 2>&1
}

# 发送 Telegram 通知
send_telegram() {
    local message="$1"
    local bot_token="${2:-}"
    local chat_id="${3:-}"
    
    if [[ -z "$bot_token" || -z "$chat_id" ]]; then
        echo "Telegram 配置不完整"
        return 1
    fi
    
    curl -s -X POST "https://api.telegram.org/bot${bot_token}/sendMessage" \
        -d "chat_id=${chat_id}" \
        -d "text=${message}" \
        -d "parse_mode=Markdown" 2>&1
}

# 主发送函数
send_notification() {
    local event_type="$1"  # task_started, task_completed, task_failed, daily_summary
    local message="$2"
    local config=$(load_notification_config)
    
    # 获取该事件类型需要通知的渠道
    local channels=$(echo "$config" | jq -r ".notification_rules.${event_type}[]? // empty")
    
    if [[ -z "$channels" ]]; then
        echo "事件类型 '$event_type' 未配置通知规则"
        return 0
    fi
    
    # 遍历每个渠道发送通知
    while IFS= read -r channel; do
        [[ -z "$channel" ]] && continue
        
        local enabled=$(echo "$config" | jq -r ".channels.${channel}.enabled // false")
        [[ "$enabled" != "true" ]] && continue
        
        echo "发送通知到 $channel..."
        
        case "$channel" in
            "feishu")
                local target=$(echo "$config" | jq -r ".channels.feishu.target // \"\"")
                send_feishu "$message" "$target"
                ;;
            "email")
                local to=$(echo "$config" | jq -r ".channels.email.to[0] // \"\"")
                send_email "Notion Task Automation" "$message" "$to"
                ;;
            "slack")
                local webhook=$(echo "$config" | jq -r ".channels.slack.webhook // \"\"")
                send_slack "$message" "$webhook"
                ;;
            "telegram")
                local token=$(echo "$config" | jq -r ".channels.telegram.bot_token // \"\"")
                local chat=$(echo "$config" | jq -r ".channels.telegram.chat_id // \"\"")
                send_telegram "$message" "$token" "$chat"
                ;;
            *)
                echo "未知的通知渠道: $channel"
                ;;
        esac
    done <<< "$channels"
}

# 测试通知
if [[ "${1:-}" == "test" ]]; then
    echo "测试多渠道通知..."
    send_notification "task_completed" "🎉 **测试通知**\n\n这是一条测试消息\n时间: $(date)"
fi

# 如果直接运行，显示帮助
if [[ "${BASH_SOURCE[0]}" == "${0}" && "${1:-}" != "test" ]]; then
    echo "多渠道通知发送器"
    echo ""
    echo "用法:"
    echo "  source $0"
    echo "  send_notification <event_type> <message>"
    echo ""
    echo "事件类型:"
    echo "  - task_started"
    echo "  - task_completed"
    echo "  - task_failed"
    echo "  - daily_summary"
    echo ""
    echo "测试:"
    echo "  $0 test"
fi
