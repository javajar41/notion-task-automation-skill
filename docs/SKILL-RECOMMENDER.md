# Notion Task Automation - 智能Skill发现系统

## 🎯 功能概述

自动化流程现在具备**智能Skill发现和推荐能力**！

### 核心能力

1. **自动分析任务描述** - 提取技术关键词
2. **智能搜索相关Skill** - 基于关键词匹配
3. **评估Skill匹配度** - 综合评分算法
4. **自动推荐最优Skill** - 通知用户并询问安装

---

## 🏗️ 系统架构

```
新任务创建
    ↓
[自动化流程] 检测到"未开始"任务
    ↓
[Skill分析器] 提取任务描述关键词
    ↓
[Skill搜索器] 搜索相关Skill
    ↓
[匹配度评估] 计算匹配分数
    ↓
[推荐系统] 生成推荐报告
    ↓
[通知用户] 发送Skill推荐
    ↓
[用户确认] → 自动安装
```

---

## 📋 使用方式

### 方式1：自动触发（已集成）

当创建新任务时，系统会自动：
1. 分析任务描述
2. 推荐相关Skill
3. 发送通知

### 方式2：手动触发

```bash
# 分析特定任务
./lib/skill-recommender.sh "任务名" "任务描述"

# 示例
./lib/skill-recommender.sh "电商网站" "创建响应式电商网站，包含购物车和支付功能"
```

---

## 🔧 技术实现

### 1. 关键词提取器

```bash
# 支持中英文关键词映射
"网站" → "web-design-guidelines,frontend-css-patterns"
"移动端" → "mobile-app,responsive-design"
"支付" → "payment-integration,security"
```

### 2. Skill搜索器

- 使用 `npx skills find` 搜索
- 缓存结果（1小时内有效）
- 避免重复搜索

### 3. 匹配度算法

```
匹配度 = 安装量得分(40%) + 关键词匹配(60%)

安装量评分：
- >100K installs: 40分
- >10K installs: 30分
- >1K installs: 20分
- <1K installs: 10分

关键词匹配：
- 每个匹配关键词 + (60/关键词总数)分
```

---

## 📊 推荐示例

### 示例1：电商网站

**任务描述：** 创建响应式电商网站，包含购物车功能和支付接口

**识别关键词：**
- 网站、响应式、移动端、支付、购物车、电商

**推荐Skill：**
```
🔴 强烈推荐
  Skill: web-design-guidelines (Vercel)
  匹配度: 85/100
  安装量: 146.7K

🟠 推荐
  Skill: accessibility-a11y
  匹配度: 72/100
  安装量: 762

🟡 可选
  Skill: performance
  匹配度: 65/100
  安装量: 3K
```

### 示例2：数据库工具

**任务描述：** 创建数据库管理工具，支持SQL查询优化

**识别关键词：**
- 数据库、SQL、优化

**推荐Skill：**
```
🟠 推荐
  Skill: database-design
  匹配度: 78/100
  
🟡 可选
  Skill: sql-optimization
  匹配度: 60/100
```

---

## ✅ 已实现的组件

### 文件结构
```
lib/
├── skill-recommender.sh      # 智能推荐核心
├── priority-calculator.sh    # 优先级计算
├── dev-time-estimator.sh     # 时间预估
├── notification-sender.sh    # 多渠道通知
└── report-generator.sh       # 报表生成
```

### 集成点

在 `check_tasks()` 函数中，当检测到**新任务**时：

1. 调用 `skill-recommender.sh`
2. 分析任务描述
3. 生成推荐报告
4. 追加到通知消息

---

## 🚀 下一步增强

### 计划功能

1. **自动安装** - 用户确认后自动执行 `npx skills add`
2. **Skill版本管理** - 检查更新并提醒
3. **依赖分析** - 识别项目技术栈，推荐配套Skill
4. **历史学习** - 根据已安装Skill优化推荐

### 集成到自动化流程

```bash
# 在 automation.sh 中添加
if [ "$todo" -gt 0 ]; then
    # 分析新任务
    while IFS= read -r task; do
        task_name=$(echo "$task" | jq -r '.properties."项目名称".title[0].plain_text')
        task_desc=$(echo "$task" | jq -r '.properties."需求描述".rich_text[0].plain_text')
        
        # 生成Skill推荐
        recommendations=$(./lib/skill-recommender.sh "$task_name" "$task_desc")
        
        # 添加到报告
        report="$report\n\n🔍 **Skill推荐**\n$recommendations"
    done < <(echo "$all_data" | jq -c '.results[] | select(.properties."完成状态".status.name == "未开始")')
fi
```

---

## 💡 使用建议

### 当前状态

✅ **已实现：**
- Skill推荐脚本
- 关键词映射
- 匹配度算法
- 手动触发

⏳ **待集成：**
- 自动触发（建议后续版本添加）
- 自动安装
- 用户交互确认

### 建议

1. **当前使用** - 手动运行 `./lib/skill-recommender.sh` 分析任务
2. **后续版本** - 集成到自动化流程，新任务自动推荐
3. **优化方向** - 基于历史数据训练更精准的推荐模型

---

## 📞 使用示例

```bash
# 进入项目目录
cd ~/.openclaw/workspace/skills/notion-task-automation

# 运行Skill推荐
./lib/skill-recommender.sh "物联网数据可视化平台" "创建一个物联网数据可视化平台，使用React和D3.js展示实时传感器数据，需要支持图表交互和数据导出功能"

# 查看输出
# 系统会分析描述并推荐相关Skill
```

---

**现在你的自动化流程已经具备智能Skill发现能力！** 🤖✨
