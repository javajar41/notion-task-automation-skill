#!/bin/bash
# Notion Task Automation - 智能Skill推荐系统
# 根据任务描述自动发现并推荐最优Skill

SKILL_SEARCH_CACHE="/tmp/skill-search-cache.json"
RECOMMENDATION_LOG="$HOME/.openclaw/workspace/skills/notion-task-automation/logs/skill-recommendations.log"

# 确保日志目录存在
mkdir -p "$(dirname "$RECOMMENDATION_LOG")"

# 关键词到skill类型的映射（支持中英文）
declare -A SKILL_KEYWORDS=(
    ["web"]="web-design-guidelines,frontend-css-patterns,responsive-design"
    ["website"]="web-design-guidelines,frontend-css-patterns"
    ["网站"]="web-design-guidelines,frontend-css-patterns"
    ["ui"]="web-design-guidelines,ui-ux-pro-max,figma-design"
    ["界面"]="web-design-guidelines,ui-ux-pro-max"
    ["database"]="database-design,sql-optimization"
    ["数据库"]="database-design,sql-optimization"
    ["api"]="api-design,rest-api-graphql"
    ["接口"]="api-design,rest-api-graphql"
    ["test"]="testing,jest,playwright,e2e"
    ["测试"]="testing,jest,playwright,e2e"
    ["deploy"]="deployment,ci-cd,docker,kubernetes"
    ["部署"]="deployment,ci-cd,docker,kubernetes"
    ["security"]="security-audit,vulnerability-scan"
    ["安全"]="security-audit,vulnerability-scan"
    ["performance"]="performance,optimization,lighthouse"
    ["性能"]="performance,optimization,lighthouse"
    ["accessibility"]="accessibility-a11y,wcag"
    ["可访问"]="accessibility-a11y,wcag"
    ["mobile"]="mobile-app,react-native,flutter"
    ["移动端"]="mobile-app,responsive-design"
    ["响应式"]="responsive-design,web-design-guidelines"
    ["animation"]="css-animation,gsap,framer-motion"
    ["动画"]="css-animation,gsap,framer-motion"
    ["payment"]="payment-integration,stripe"
    ["支付"]="payment-integration,security"
    ["购物车"]="e-commerce,shopping-cart"
    ["电商"]="e-commerce,web-design-guidelines"
)

# 分析任务描述，提取关键词
analyze_task_description() {
    local description="$1"
    local found_keywords=""
    
    # 转换为小写
    local lower_desc=$(echo "$description" | tr '[:upper:]' '[:lower:]')
    
    # 遍历关键词映射
    for keyword in "${!SKILL_KEYWORDS[@]}"; do
        if echo "$lower_desc" | grep -q "$keyword"; then
            found_keywords="$found_keywords ${SKILL_KEYWORDS[$keyword]}"
        fi
    done
    
    # 去重并返回
    echo "$found_keywords" | tr ',' '\n' | tr ' ' '\n' | sort -u | grep -v '^$' | tr '\n' ',' | sed 's/,$//'
}

# 搜索Skill（带缓存）
search_skills() {
    local query="$1"
    local cache_key=$(echo "$query" | md5sum | cut -d' ' -f1)
    local cache_file="/tmp/skill-search-${cache_key}.json"
    
    # 检查缓存（1小时内有效）
    if [[ -f "$cache_file" ]]; then
        local cache_time=$(stat -f%m "$cache_file" 2>/dev/null || stat -c%Y "$cache_file" 2>/dev/null)
        local now=$(date +%s)
        if [[ $((now - cache_time)) -lt 3600 ]]; then
            cat "$cache_file"
            return
        fi
    fi
    
    # 执行搜索
    local results=$(npx skills find "$query" 2>/dev/null | grep -E "^[a-z].*@" | head -5)
    
    # 缓存结果
    echo "$results" > "$cache_file"
    echo "$results"
}

# 评估Skill匹配度
evaluate_skill_match() {
    local skill_name="$1"
    local task_keywords="$2"
    local score=0
    
    # 安装量权重 (40%)
    local installs=$(npx skills info "$skill_name" 2>/dev/null | grep -oE "[0-9]+(\.[0-9]+)?K installs" | grep -oE "[0-9]+(\.[0-9]+)?" | head -1)
    if [[ -n "$installs" ]]; then
        if [[ $(echo "$installs > 100" | bc -l) -eq 1 ]]; then
            score=$((score + 40))
        elif [[ $(echo "$installs > 10" | bc -l) -eq 1 ]]; then
            score=$((score + 30))
        elif [[ $(echo "$installs > 1" | bc -l) -eq 1 ]]; then
            score=$((score + 20))
        else
            score=$((score + 10))
        fi
    fi
    
    # 关键词匹配 (60%)
    local keyword_count=0
    local match_count=0
    
    IFS=',' read -ra keywords <<< "$task_keywords"
    for kw in "${keywords[@]}"; do
        keyword_count=$((keyword_count + 1))
        if echo "$skill_name" | grep -qi "$kw"; then
            match_count=$((match_count + 1))
        fi
    done
    
    if [[ $keyword_count -gt 0 ]]; then
        local match_score=$((match_count * 60 / keyword_count))
        score=$((score + match_score))
    fi
    
    echo "$score"
}

# 生成推荐报告
generate_recommendation() {
    local task_name="$1"
    local task_description="$2"
    
    echo "🔍 智能Skill推荐分析"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📁 任务: $task_name"
    echo "📝 描述: $task_description"
    echo ""
    
    # 提取关键词
    local keywords=$(analyze_task_description "$task_description")
    echo "🎯 识别关键词: $keywords"
    echo ""
    
    if [[ -z "$keywords" ]]; then
        echo "⚠️ 未能识别特定技术关键词，跳过Skill推荐"
        return 1
    fi
    
    # 搜索相关Skill
    echo "🔎 搜索相关Skill..."
    echo ""
    
    local recommendations=""
    IFS=',' read -ra keyword_array <<< "$keywords"
    
    for kw in "${keyword_array[@]}"; do
        [[ -z "$kw" ]] && continue
        
        echo "  搜索: $kw"
        local skills=$(search_skills "$kw")
        
        while IFS= read -r skill_line; do
            [[ -z "$skill_line" ]] && continue
            
            local skill_name=$(echo "$skill_line" | awk '{print $1}')
            local installs=$(echo "$skill_line" | grep -oE "[0-9]+(\.[0-9]+)?K installs" || echo "0 installs")
            
            # 评估匹配度
            local match_score=$(evaluate_skill_match "$skill_name" "$keywords")
            
            if [[ $match_score -gt 30 ]]; then
                recommendations="${recommendations}${match_score}|${skill_name}|${installs}\n"
            fi
        done <<< "$skills"
    done
    
    # 排序并去重
    if [[ -n "$recommendations" ]]; then
        echo "📊 推荐结果（按匹配度排序）:"
        echo ""
        
        echo -e "$recommendations" | sort -t'|' -k1 -nr | uniq | head -5 | while IFS='|' read -r score skill installs; do
            [[ -z "$skill" ]] && continue
            
            # 显示推荐等级
            local level="🟡"
            if [[ $score -ge 80 ]]; then
                level="🔴 强烈推荐"
            elif [[ $score -ge 60 ]]; then
                level="🟠 推荐"
            else
                level="🟡 可选"
            fi
            
            echo "  $level"
            echo "    Skill: $skill"
            echo "    匹配度: ${score}/100"
            echo "    安装量: $installs"
            echo "    安装命令: npx skills add $skill"
            echo ""
        done
        
        # 记录到日志
        echo "[$(date -Iseconds)] $task_name | $keywords" >> "$RECOMMENDATION_LOG"
        
        return 0
    else
        echo "⚠️ 未找到高匹配度的Skill"
        return 1
    fi
}

# 主函数
main() {
    local task_name="${1:-}"
    local task_description="${2:-}"
    
    if [[ -z "$task_name" || -z "$task_description" ]]; then
        echo "智能Skill推荐系统"
        echo ""
        echo "用法:"
        echo "  $0 <任务名称> <任务描述>"
        echo ""
        echo "示例:"
        echo "  $0 '电商网站' '创建一个响应式电商网站，包含购物车功能'"
        exit 1
    fi
    
    generate_recommendation "$task_name" "$task_description"
}

# 如果直接运行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
