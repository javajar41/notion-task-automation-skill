#!/bin/bash
# Notion Task Automation - 开发时间预估 (P1-3)
# 基于历史数据统计，预估开发时间

STATS_FILE="${STATS_FILE:-$(dirname "$0")/../config/dev-time-stats.json}"

# 加载统计数据
load_stats() {
    if [[ ! -f "$STATS_FILE" ]]; then
        echo "{}"
        return
    fi
    cat "$STATS_FILE"
}

# 预估开发时间 (分钟)
estimate_dev_time() {
    local task_type="${1:-web}"      # web/tool/automation
    local complexity="${2:-medium}"  # simple/medium/complex
    local factors="${3:-}"           # 额外因素，逗号分隔
    
    local stats=$(load_stats)
    
    # 获取基础时间
    local base_time=$(echo "$stats" | jq -r ".stats.${task_type}.${complexity}.avg_minutes // 60")
    local count=$(echo "$stats" | jq -r ".stats.${task_type}.${complexity}.count // 0")
    
    # 应用复杂度因素
    local final_time=$base_time
    if [[ -n "$factors" ]]; then
        IFS=',' read -ra factor_array <<< "$factors"
        for factor in "${factor_array[@]}"; do
            local factor_value=$(echo "$stats" | jq -r ".complexity_factors.${factor} // 1.0")
            final_time=$(echo "$final_time * $factor_value" | bc -l)
        done
    fi
    
    # 四舍五入到整数
    final_time=$(printf "%.0f" "$final_time")
    
    # 计算置信度
    local confidence="中"
    if [[ $count -gt 5 ]]; then
        confidence="高"
    elif [[ $count -lt 2 ]]; then
        confidence="低"
    fi
    
    # 输出结果
    echo "{
  \"task_type\": \"$task_type\",
  \"complexity\": \"$complexity\",
  \"estimated_minutes\": $final_time,
  \"estimated_hours\": $(echo "scale=1; $final_time / 60" | bc),
  \"confidence\": \"$confidence\",
  \"based_on_samples\": $count
}"
}

# 格式化时间显示
format_duration() {
    local minutes=$1
    local hours=$((minutes / 60))
    local mins=$((minutes % 60))
    
    if [[ $hours -gt 0 && $mins -gt 0 ]]; then
        echo "${hours}小时${mins}分钟"
    elif [[ $hours -gt 0 ]]; then
        echo "${hours}小时"
    else
        echo "${mins}分钟"
    fi
}

# 记录实际开发时间 (用于更新统计数据)
record_actual_time() {
    local task_name="$1"
    local task_type="$2"
    local complexity="$3"
    local actual_minutes="$4"
    
    log "记录开发时间: $task_name - ${actual_minutes}分钟"
    
    # 这里可以扩展为更新 stats.json
    # 暂时只记录到日志
    echo "[$(date -Iseconds)] $task_name | $task_type | $complexity | ${actual_minutes}min" >> "$(dirname "$0")/../logs/dev-time-log.txt"
}

# 显示预估报告
show_estimate_report() {
    local task_name="$1"
    local estimate_json="$2"
    
    local minutes=$(echo "$estimate_json" | jq -r '.estimated_minutes')
    local hours=$(echo "$estimate_json" | jq -r '.estimated_hours')
    local confidence=$(echo "$estimate_json" | jq -r '.confidence')
    local samples=$(echo "$estimate_json" | jq -r '.based_on_samples')
    
    echo ""
    echo "📊 开发时间预估报告"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📁 任务: $task_name"
    echo "⏱️  预估时间: $(format_duration $minutes)"
    echo "🎯 置信度: $confidence (基于 $samples 个样本)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 如果直接运行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "开发时间预估工具"
        echo ""
        echo "用法:"
        echo "  $0 <任务类型> <复杂度> [额外因素]"
        echo ""
        echo "任务类型: web, tool, automation"
        echo "复杂度: simple, medium, complex"
        echo "额外因素: new_feature, bug_fix, refactor, integration (逗号分隔)"
        echo ""
        echo "示例:"
        echo "  $0 web medium new_feature"
        echo "  $0 tool simple"
        exit 1
    fi
    
    result=$(estimate_dev_time "$1" "$2" "${3:-}")
    echo "$result" | jq .
fi
