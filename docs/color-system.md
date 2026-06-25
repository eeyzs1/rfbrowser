# RFBrowser 颜色系统定义

本文档定义 RFBrowser 中四种可调节颜色各自控制的元素类别，作为开发者和设计者的权威参考。所有 UI 元素的颜色使用都应遵循此定义。

## 设计原则

1. **职责分离** — 每种颜色只控制一个视觉层级，避免交叉污染
2. **交互辨识** — 交互元素（按钮、链接）使用主题色，与内容文字形成区分
3. **可读性优先** — 字体颜色只影响"阅读性内容"，不干涉交互信号
4. **层级递进** — 背景 → 面板 → 内容，三层逐级提升视觉焦点

---

## 1. 主题色（Theme Color / accentColor）

**定义**：应用的强调色/品牌色，用于标识交互元素和激活状态。

### 控制的元素

| 类别 | 具体元素 | 示例 |
|------|----------|------|
| 按钮文字 | TextButton、OutlinedButton 的文字 | "取消"、"保存"、"新建" |
| 激活状态 | 当前选中的标签页、激活的切换按钮 | 选中的场景按钮(capture/think/connect) |
| 链接 | Markdown 中的链接文字、WikiLink | `[[笔记标题]]`、`[文本](url)` |
| 焦点指示 | 输入框焦点边框、键盘焦点环 | TextField 的 focusedBorder |
| 进度指示 | ProgressBar、CircularProgressIndicator | 同步进度条 |
| 选中标记 | 选中的预设颜色边框、选中的 ChoiceChip | 设置面板中的颜色预设 |
| 图标按钮 | IconButton 默认颜色（未显式覆盖时） | 工具栏图标 |
| 开关 | Switch、Checkbox 选中态 | 设置开关 |

### 不应控制

- 正文文字、标题、标签文字 → 由**字体颜色**控制
- 背景、面板 → 由**背景色/面板色**控制
- 非交互的装饰性图标 → 由**字体颜色**（muted 变体）控制

---

## 2. 背景色（Background Color）

**定义**：应用最底层的基础画布颜色，所有内容浮于其上。

### 控制的元素

| 类别 | 具体元素 | 示例 |
|------|----------|------|
| 主画布 | Scaffold 背景 | 编辑器区域、浏览器区域的基础背景 |
| 全屏遮罩 | Dialog/Modal 的背景遮罩 | 弹窗背后的半透明遮罩 |

### 不应控制

- 卡片、面板、工具栏背景 → 由**面板色**控制
- 文字颜色 → 由**字体颜色**控制
- 交互元素颜色 → 由**主题色**控制

---

## 3. 面板色（Surface Color）

**定义**：浮于背景之上的表面颜色，用于卡片、面板、工具栏等需要与背景区分的容器。

### 控制的元素

| 类别 | 具体元素 | 示例 |
|------|----------|------|
| 面板背景 | 侧边栏、设置面板、属性面板 | 笔记侧边栏、AI 面板 |
| 卡片背景 | 笔记卡片、画布卡片、设置分组卡片 | 笔记列表项、画布元素 |
| 工具栏背景 | AppBar、底部工具栏、格式工具栏 | 编辑器顶部栏 |
| 对话框背景 | Dialog、AlertDialog 的背景 | 新建笔记对话框 |
| 输入框背景 | TextField 的填充背景 | 搜索框、文本输入 |

### 不应控制

- 主画布背景 → 由**背景色**控制
- 面板上的文字颜色 → 由**字体颜色**控制
- 面板上的按钮颜色 → 由**主题色**控制

---

## 4. 字体颜色（Font Color）

**定义**：所有"阅读性内容"的文字颜色，即用户阅读和消费的文字。

### 控制的元素

| 类别 | 具体元素 | 对应 TextTheme 样式 | 透明度 |
|------|----------|---------------------|--------|
| 标题文字 | 笔记标题、对话框标题、分区标题 | displayLarge/Medium/Small, headlineLarge/Medium/Small, titleLarge/Medium/Small | 100% (onSurface) |
| 正文文字 | 笔记内容、描述文字、列表项文字 | bodyLarge | 100% (onSurface) |
| 次要正文 | 说明文字、提示性正文 | bodyMedium | 70% (onSurfaceVariant) |
| 辅助文字 | 计数器、时间戳、状态标签 | bodySmall, labelSmall | 50% (muted) |
| 标签文字 | 表单标签、按钮内标签（非交互色） | labelLarge, labelMedium | 100% (onSurface) |
| 占位文字 | TextField 的 hint text | — | 50% (muted) |
| Markdown 正文 | 预览模式的段落、标题、列表 | 全部 TextTheme 样式 | 按上述规则 |

### 不应控制

- **按钮文字**（TextButton、OutlinedButton、FilledButton、ElevatedButton）→ 由**主题色**控制
- **链接文字** → 由**主题色**控制
- **激活状态的文字** → 由**主题色**控制
- **图标颜色** → 由**主题色**控制（IconButton）或 muted 变体（装饰图标）
- **进度条、开关等交互控件颜色** → 由**主题色**控制

### 自动模式（Auto）

当字体颜色设为"自动"时，根据面板色亮度自动推导：
- 浅色面板 → 深色文字
- 深色面板 → 浅色文字

---

## 审查清单

开发新 UI 元素时，按以下顺序确定颜色：

1. **它是交互元素吗？** → 用主题色（`theme.colorScheme.primary`）
2. **它是背景画布吗？** → 用背景色（`theme.scaffoldBackgroundColor`）
3. **它是浮于背景的容器吗？** → 用面板色（`theme.colorScheme.surface` 或相关 surface 变体）
4. **它是阅读性文字吗？** → 用字体颜色（`theme.textTheme.xxx.color` 或 `theme.colorScheme.onSurface/onSurfaceVariant`）
5. **它是辅助/次要文字吗？** → 用字体颜色的 muted 变体（`theme.hintColor`）

### 禁止做法

- ❌ 在按钮文字上使用 `theme.textTheme` 颜色
- ❌ 在正文文字上使用 `theme.colorScheme.primary`（除非是链接）
- ❌ 硬编码 `Colors.white`/`Colors.black` 作为文字颜色
- ❌ 在背景容器上使用 `theme.colorScheme.primary`
- ❌ 混淆 `onSurface`（主文字）和 `onSurfaceVariant`（次要文字）的用途
