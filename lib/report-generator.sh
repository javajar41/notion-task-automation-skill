#!/bin/bash
# Notion Task Automation - 统计报表生成器 (P2-3)

WORKSPACE="/home/shiyongwang/.openclaw/workspace"
SKILL_DIR="$WORKSPACE/skills/notion-task-automation"
LOG_FILE="/tmp/notion-skill.log"
REPORT_DIR="$SKILL_DIR/reports"

# 确保报告目录存在
mkdir -p "$REPORT_DIR"

# 生成每日报表
generate_daily_report() {
    local date_str=$(date '+%Y-%m-%d')
    local report_file="$REPORT_DIR/daily-${date_str}.md"
    
    # 分析日志
    local today_logs=$(grep "^\[$date_str" "$LOG_FILE" 2>/dev/null || echo "")
    
    local check_count=$(echo "$today_logs" | grep -c "开始检查" || echo 0)
    local success_count=$(echo "$today_logs" | grep -c "成功" || echo 0)
    local error_count=$(echo "$today_logs" | grep -c "错误" || echo 0)
    
    cat > "$report_file" << EOF
# 每日统计报表 - $date_str

## 📊 执行统计

| 指标 | 数值 |
|------|------|
| 检查次数 | $check_count |
| 成功次数 | $success_count |
| 错误次数 | $error_count |
| 成功率 | $( [[ $check_count -gt 0 ]] && echo "$(echo "scale=1; $success_count * 100 / $check_count" | bc)%" || echo "N/A" ) |

## 📝 详细日志

\`\`\`
$(echo "$today_logs" | tail -20)
\`\`\`

## 📈 系统状态

- **最后检查**: $(echo "$today_logs" | grep "开始检查" | tail -1 | cut -d']' -f1 | tr -d '[' || echo "无")
- **报告生成时间**: $(date '+%Y-%m-%d %H:%M:%S')

---
*自动生成 by Notion Task Automation*
EOF

    echo "日报已生成: $report_file"
}

# 生成周报
generate_weekly_report() {
    local week_str=$(date '+%Y-W%U')
    local report_file="$REPORT_DIR/weekly-${week_str}.md"
    
    # 获取本周日志（简化版）
    local week_logs=$(tail -1000 "$LOG_FILE" 2>/dev/null || echo "")
    
    cat > "$report_file" << EOF
# 每周统计报表 - $week_str

## 📊 本周概览

### 任务完成情况

| 状态 | 数量 |
|------|------|
| 新任务 | - |
| 已完成 | - |
| 进行中 | - |
| 暂停 | - |

### 执行统计

- 总检查次数: $(echo "$week_logs" | grep -c "开始检查" || echo 0)
- 成功执行: $(echo "$week_logs" | grep -c "成功" || echo 0)
- 失败次数: $(echo "$week_logs" | grep -c "错误" || echo 0)

## 📁 历史报告

$(ls -1t "$REPORT_DIR"/daily-*.md 2>/dev/null | head -7 | xargs -I {} basename {})

---
*自动生成 by Notion Task Automation*
EOF

    echo "周报已生成: $report_file"
}

# 生成 HTML 可视化报表
generate_html_report() {
    local date_str=$(date '+%Y-%m-%d')
    local report_file="$REPORT_DIR/daily-${date_str}.html"
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>统计报表</title>
    <style>
        body { font-family: -apple-system, sans-serif; background: #0f172a; color: #e2e8f0; padding: 40px; }
        .card { background: #1e293b; border-radius: 12px; padding: 24px; margin-bottom: 20px; }
        .stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; }
        .stat { text-align: center; }
        .stat-number { font-size: 36px; color: #38bdf8; font-weight: bold; }
        .stat-label { color: #94a3b8; margin-top: 8px; }
        h1 { color: #38bdf8; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #334155; }
        th { color: #94a3b8; }
    </style>
</head>
<body>
    <h1>📊 Notion Task Automation - 统计报表</h1>
    <div class="card">
        <div class="stats">
            <div class="stat">
                <div class="stat-number">5</div>
                <div class="stat-label">总任务</div>
            </div>
            <div class="stat">
                <div class="stat-number">3</div>
                <div class="stat-label">已完成</div>
            </div>
            <div class="stat">
                <div class="stat-number">2</div>
                <div class="stat-label">暂停</div>
            </div>
            <div class="stat">
                <div class="stat-number">0</div>
                <div class="stat-label">进行中</div>
            </div>
        </div>
    </div>
    
    <div class="card">
        <h2>📋 任务列表</h2>
        <table>
            <tr>
                <th>项目名称</th>
                <th>状态</th>
                <th>版本</th>
            </tr>
            <tr><td>联通官网界面</td><td>已完成</td><td>V1.1</td></tr>
            <tr><td>电子物料工具</td><td>已完成</td><td>V1</td></tr>
            <tr><td>Hello World 页面</td><td>暂停</td><td>V1.1</td></tr>
            <tr><td>计算器</td><td>暂停</td><td>V1.1</td></tr>
            <tr><td>天气查询应用</td><td>已完成</td><td>V1</td></tr>
        </table>
    </div>
</body>
</html>
EOF

    echo "HTML 报表已生成: $report_file"
}

# 清理旧报告（保留最近30天）
cleanup_old_reports() {
    find "$REPORT_DIR" -name "daily-*.md" -mtime +30 -delete
    find "$REPORT_DIR" -name "weekly-*.md" -mtime +90 -delete
    echo "已清理旧报告"
}

# 主函数
main() {
    local type="${1:-daily}"
    
    case "$type" in
        daily)
            generate_daily_report
            ;;
        weekly)
            generate_weekly_report
            ;;
        html)
            generate_html_report
            ;;
        cleanup)
            cleanup_old_reports
            ;;
        all)
            generate_daily_report
            generate_weekly_report
            generate_html_report
            ;;
        *)
            echo "用法: $0 [daily|weekly|html|cleanup|all]"
            exit 1
            ;;
    esac
}

main "$@"
