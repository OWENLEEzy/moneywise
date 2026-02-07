# Moneywise App Store 发布检查清单

## 前置准备

### 1. Apple Developer 账号
- [ ] 注册 Apple Developer Program ($99/年)
- [ ] 创建 App ID
- [ ] 配置 iCloud Container
- [ ] 创建 Provisioning Profile

### 2. App Store Connect 配置
- [ ] 登录 [App Store Connect](https://appstoreconnect.apple.com)
- [ ] 创建新 App
- [ ] 填写 App 基本信息
  - 平台：iOS
  - 名称：Moneywise
  - 主要语言：中文（简体）/ English
  - Bundle ID：owenlee.Moneywise
  - SKU：MONEYWISE-001

---

## App Store Connect 必填信息

### 1. App 信息
| 项目 | 内容 |
|------|------|
| **App 名称** | Moneywise |
| **副标题** | 智能财务管理助手 |
| **类别** | 财务 |
| **内容版权** | 2025 Owen Lee |

### 2. 年龄分级
- 填写问卷获取分级标签

### 3. 定价与销售范围
- 价格：免费 / 付费
- 销售地区：选择要发布的国家

### 4. App 隐私
- 填写隐私问卷（Privacy Questionnaire）
- 说明数据收集和使用方式

### 5. 审核信息
- **用户名**：用于审核的测试账号
- **密码**：测试账号密码
- **联系方式**：你的邮箱

---

## App 截图要求

### 需要的截图尺寸

| 设备 | 尺寸 | 数量 |
|------|------|------|
| iPhone 6.7" (Pro Max) | 1290 x 2796 | 至少 3 张 |
| iPhone 6.5" (Plus) | 1242 x 2688 | 可选 |
| iPhone 5.5" | 1242 x 2208 | 可选 |

### 推荐截图内容
1. **首页**：展示总览卡片和余额
2. **AI 入录**：展示智能记账功能
3. **报表**：展示数据可视化图表
4. **预算管理**：展示预算进度条
5. **目标**：展示储蓄目标跟踪

---

## App 描述模板

### 简短描述（170 字符限制）
```
智能财务管理助手，AI 驱动的一键记账，让理财变得简单轻松。
```

### 完整描述

```
Moneywise 是一款智能个人财务管理应用，结合人工智能技术，让记账变得前所未有的简单。

## 核心功能

🧠 AI 智能入录
• 语音输入或文字描述，AI 自动解析交易详情
• 支持中英文，智能识别消费类别
• 置信度评分，确保记录准确

📊 数据可视化
• 精美的图表展示收支趋势
• 按类别分析支出构成
• 月度/年度财务报告

💰 预算管理
• 为不同类别设置预算限额
• 实时跟踪预算使用进度
• 超支智能提醒

🎯 储蓄目标
• 设定存钱目标，跟踪进度
• 可视化展示目标达成情况

☁️ iCloud 同步
• 数据自动同步到所有设备
• 安全可靠的云端备份

## 适合人群
• 想要轻松记账的普通人
• 需要财务分析的理财用户
• 追求简洁美观的应用爱好者

## 隐私与安全
• 所有数据存储在本地或你的私人 iCloud
• 不收集任何个人信息
• 支持 Face ID / Touch ID 保护

开始使用 Moneywise，让 AI 帮你打理财务！
```

---

## 构建与上传步骤

### 1. 在 Xcode 中配置

```
1. 打开 Moneywise.xcodeproj
2. 选择项目 → Target → General
3. 配置：
   - Display Name: Moneywise
   - Bundle Identifier: owenlee.Moneywise
   - Version: 1.0.0
   - Build: 1

4. Signing & Capabilities:
   - Team: 选择你的开发者账号
   - Capability: 添加 iCloud (CloudKit)
   - Capability: 添加 Push Notifications (可选)
```

### 2. Archive（归档）

```
菜单栏 → Product → Archive
```

### 3. 验证与上传

```
1. Archive 完成后自动打开 Organizer
2. 选择归档 → Distribute App
3. 选择分发方式：App Store Connect
4. 点击 Upload
```

---

## 审核注意事项

### 常见拒绝原因
1. **崩溃或 Bug**：确保充分测试
2. **隐私权限未说明**：已在 Info.plist 添加
3. **功能不完整**：确保所有功能可用
4. **测试账号无效**：提供有效的测试账号

### 预计审核时间
- 初次提交：**3-7 个工作日**
- 更新版本：**1-3 个工作日**

---

## 发布后

1. **监控崩溃报告**：Xcode Organizer → Crashes
2. **回复用户评价**：App Store Connect → Ratings and Reviews
3. **准备更新版本**：根据用户反馈持续改进

---

## 快捷命令

```bash
# 打开项目
cd /Users/owenlee/Desktop/2025年/项目/moneywise
open Moneywise.xcodeproj

# 构建检查（需要 Xcode）
xcodebuild clean build -project Moneywise.xcodeproj -scheme Moneywise

# 归档
xcodebuild archive -project Moneywise.xcodeproj -scheme Moneywise -archivePath Moneywise.xcarchive
```
