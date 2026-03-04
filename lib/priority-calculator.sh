#!/bin/bash
# Notion Task Automation - 任务优先级计算器 (P1-2)
# 根据截止日期、紧急程度、等待时间计算优先级分数

# 优先级权重配置
URGENCY_WEIGHT=40      # 紧急程度权重 40%
DUE_DATE_WEIGHT=40     # 截止日期权重 40%
WAITING_WEIGHT=20      # 等待时间权重 20%

# 计算单个任务的优先级分数 (0-100)
calculate_task_priority() {
    local task_json="$1"
    local score=0
    
    # 1. 紧急程度评分 (0-40分)
    local urgency=$(echo "$task_json" | jq -r '.properties."紧急程度"?.select?.name // "普通"')
    case "$urgency" in
        "P0"|"紧急") score=$((score + 40)) ;;
        "P1"|"高")   score=$((score + 30)) ;;
        "P2"|"中")   score=$((score + 20)) ;;
        "P3"|"低")   score=$((score + 10)) ;;
        *)           score=$((score + 15)) ;;  # 默认中等
    esac
    
    # 2. 截止日期评分 (0-40分)
    local due_date=$(echo "$task_json" | jq -r '.properties."截止日期"?.date?.start // empty')
    if [[ -n "$due_date" ]]; then
        local due_ts=$(date -d "$due_date" +%s 2>/dev/null || echo 0)
        local now_ts=$(date +%s)
        local days_until=$(( (due_ts - now_ts) / 86400 ))
        
        if [[ $days_until -lt 0 ]]; then
            # 已逾期，最高优先级
            score=$((score + 40))
        elif [[ $days_until -lt 2 ]]; then
            # 2天内到期
            score=$((score + 35))
        elif [[ $days_until -lt 7 ]]; then
            # 1周内到期
            score=$((score + 25))
        elif [[ $days_until -lt 14 ]]; then
            # 2周内到期
            score=$((score + 15))
        else
            # 2周以上
            score=$((score + 5))
        fi
    else
        # 无截止日期，中等优先级
        score=$((score + 20))
    fi
    
    # 3. 等待时间评分 (0-20分)
    local created_time=$(echo "$task_json" | jq -r '.created_time')
    if [[ -n "$created_time" ]]; then
        local created_ts=$(date -d "$created_time" +%s 2>/dev/null || echo 0)
        local now_ts=$(date +%s)
        local days_waiting=$(( (now_ts - created_ts) / 86400 ))
        
        if [[ $days_waiting -gt 30 ]]; then
            # 等待超过30天
            score=$((score + 20))
        elif [[ $days_waiting -gt 14 ]]; then
            # 等待超过14天
            score=$((score + 15))
        elif [[ $days_waiting -gt 7 ]]; then
            # 等待超过7天
            score=$((score + 10))
        elif [[ $days_waiting -gt 3 ]]; then
            # 等待超过3天
            score=$((score + 5))
        fi
    fi
    
    # 确保分数在 0-100 范围内
    [[ $score -gt 100 ]] && score=100
    [[ $score -lt 0 ]] && score=0
    
    echo "$score"
}

# 获取优先级标签
get_priority_label() {
    local score=$1
    if [[ $score -ge 80 ]]; then
        echo "🔴 紧急"
    elif [[ $score -ge 60 ]]; then
        echo "🟠 高"
    elif [[ $score -ge 40 ]]; then
        echo "🟡 中"
    else
        echo "🟢 低"
    fi
}

# 对任务列表按优先级排序
sort_tasks_by_priority() {
    local tasks_json="$1"
    
    # 为每个任务计算优先级并排序
    echo "$tasks_json" | jq -c '.[]' | while read -r task; do
        local score=$(calculate_task_priority "$task")
        echo "${score}|$task"
    done | sort -t'|' -k1 -nr | cut -d'|' -f2-
}

# 如果直接运行此脚本，显示帮助
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "任务优先级计算器"
    echo ""
    echo "使用方法:"
    echo "  source $0"
    echo "  calculate_task_priority '<task_json>'"
    echo ""
    echo "优先级算法:"
    echo "  • 紧急程度: 40% (P0=40, P1=30, P2=20, P3=10)"
    echo "  • 截止日期: 40% (逾期=40, 2天内=35, 1周内=25, 2周内=15)"
    echo "  • 等待时间: 20% (>30天=20, >14天=15, >7天=10, >3天=5)"
fi
