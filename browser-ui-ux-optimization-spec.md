# RFBrowser 浏览页面 UI/UX 优化规格书

> 审计范围：`lib/ui/pages/browser_page.dart`、`lib/ui/scenes/capture/capture_scene.dart`、`lib/ui/widgets/note_sidebar.dart`、`lib/ui/theme/design_tokens.dart`
> 审计依据：UI/UX Pro Max 99 条准则（10 大优先级类别）
> 生成日期：2026-05-13

---

## 目录

- [P1: 可访问性 (Accessibility) — CRITICAL](#p1-accessibility--critical)
- [P2: 触控与交互 (Touch & Interaction) — CRITICAL](#p2-touch--interaction--critical)
- [P3: 性能 (Performance) — HIGH](#p3-performance--high)
- [P4: 风格与视觉一致性 (Style Selection) — HIGH](#p4-style-selection--high)
- [P5: 布局与响应式 (Layout & Responsive) — HIGH](#p5-layout--responsive--high)
- [P6: 排版与色彩 (Typography & Color) — MEDIUM](#p6-typography--color--medium)
- [P7: 动画 (Animation) — MEDIUM](#p7-animation--medium)
- [P8: 表单与反馈 (Forms & Feedback) — MEDIUM](#p8-forms--feedback--medium)
- [P9: 导航模式 (Navigation Patterns) — HIGH](#p9-navigation-patterns--high)
- [P10: 架构与产品 UX (Architecture & Product UX)](#p10-architecture--product-ux)
- [实施路线图](#实施路线图)

---

## P1: Accessibility — CRITICAL

### A1: 标签栏关闭按钮触控区过小

**User Story:** 作为触屏用户，我希望标签关闭按钮有足够的触控区域，这样我不会误触或难以关闭标签。

**Acceptance Criteria:**
- GIVEN 标签栏显示至少一个标签
- WHEN 用户点击标签关闭图标
- THEN 关闭按钮的有效触控区域 ≥ 44×44pt（通过 padding/hitSlop 扩展，视觉图标可保持 12px）
- AND 点击区域不与相邻标签的切换区域重叠

**涉及文件:** `lib/ui/pages/browser_page.dart` L392-396
**违反准则:** `touch-target-size` (≥44pt)

---

### A2: 标签栏项目缺少语义标签

**User Story:** 作为屏幕阅读器用户，我希望每个标签项有清晰的语义描述，这样我能理解当前标签状态并正确操作。

**Acceptance Criteria:**
- GIVEN 屏幕阅读器已启用
- WHEN 焦点移至某个标签
- THEN 朗读内容包含："标签：{标题}，{是否激活}，{是否加载中}"
- AND 关闭按钮朗读为："关闭标签 {标题}"
- AND 新建标签按钮朗读为："新建标签"

**涉及文件:** `lib/ui/pages/browser_page.dart` L343-400
**违反准则:** `aria-labels`

---

### A3: 导航按钮缺少 Tooltip / 语义标签

**User Story:** 作为键盘/屏幕阅读器用户，我希望后退、前进、刷新按钮有明确的文字标签，这样我能理解每个按钮的功能。

**Acceptance Criteria:**
- GIVEN 浏览器导航栏可见
- WHEN 用户悬停或聚焦于后退/前进/刷新按钮
- THEN 显示对应 l10n 文本的 Tooltip（如"后退"/"前进"/"刷新"）
- AND 屏幕阅读器朗读相同的语义标签
- AND `_buildNavButton` 的 `tooltip` 参数不再为空字符串

**涉及文件:** `lib/ui/pages/browser_page.dart` L161-172, L477-498
**违反准则:** `aria-labels` + `keyboard-nav`

---

### A4: 剪藏按钮无 disabled 语义标注

**User Story:** 作为屏幕阅读器用户，我希望禁用状态的剪藏按钮被明确告知为"不可用"，这样我不会困惑为何点击无响应。

**Acceptance Criteria:**
- GIVEN 当前标签 URL 为空或 `about:blank`
- WHEN 屏幕阅读器聚焦于剪藏按钮
- THEN 按钮语义状态为 `disabled: true`
- AND 朗读内容包含"不可用"或等效提示
- AND 视觉上按钮透明度降低至 0.38-0.5（符合 Material disabled 规范）

**涉及文件:** `lib/ui/pages/browser_page.dart` L515-537
**违反准则:** `disabled-states`

---

### A5: URL 栏缺少表单标签关联

**User Story:** 作为屏幕阅读器用户，我希望 URL 输入框有明确的标签，这样我能知道此字段的用途。

**Acceptance Criteria:**
- GIVEN 屏幕阅读器聚焦于 URL 输入框
- THEN 朗读内容为 l10n 的"搜索或输入 URL"文本
- AND 不依赖 hintText 作为唯一标识（添加 `Semantics(label: ...)` 或 `decoration.labelText`）

**涉及文件:** `lib/ui/pages/browser_page.dart` L179-198
**违反准则:** `form-labels`

---

## P2: Touch & Interaction — CRITICAL

### T1: 标签栏高度不满足触控标准

**User Story:** 作为触屏设备用户，我希望标签栏有足够的高度，这样我能轻松点击切换标签。

**Acceptance Criteria:**
- GIVEN 应用运行在触屏设备上
- WHEN 用户点击标签栏中的标签
- THEN 标签栏内部可点击区域高度 ≥ 40pt（桌面端可接受 36px 容器高度，但内部触控热区需扩展）
- OR 标签栏容器高度提升至 40-44px

**涉及文件:** `lib/ui/pages/browser_page.dart` L322
**违反准则:** `touch-target-size` (≥44pt)

---

### T2: 标签切换无按下反馈

**User Story:** 作为用户，我希望点击标签时有视觉反馈，这样我能确认点击已被识别。

**Acceptance Criteria:**
- GIVEN 标签栏显示多个标签
- WHEN 用户按下（而非仅点击）某个标签
- THEN 显示 ripple 效果或背景色变化（使用 `InkWell` 替代 `GestureDetector`）
- AND 按下反馈在 100ms 内出现
- AND 反馈不改变标签的布局边界（无 layout shift）

**涉及文件:** `lib/ui/pages/browser_page.dart` L343-345
**违反准则:** `press-feedback`

---

### T3: 剪藏操作无加载状态反馈

**User Story:** 作为用户，我希望点击剪藏按钮后看到操作正在进行，这样我不会重复点击或以为没有响应。

**Acceptance Criteria:**
- GIVEN 用户点击"整页剪藏"或"选区剪藏"按钮
- WHEN 剪藏操作进行中
- THEN 按钮显示 loading 指示器（spinner 或进度条）
- AND 按钮变为不可点击状态（disabled）
- AND 操作完成后恢复按钮原始状态
- AND 操作失败时显示错误提示并恢复按钮

**涉及文件:** `lib/ui/pages/browser_page.dart` L543-595, L597-680
**违反准则:** `loading-buttons`

---

### T4: URL 提交后焦点未转移

**User Story:** 作为用户，我希望在 URL 栏按回车后键盘自动收起/焦点离开输入框，这样我能立即看到页面加载。

**Acceptance Criteria:**
- GIVEN URL 输入框处于聚焦状态
- WHEN 用户按回车提交 URL
- THEN `FocusScope.of(context).unfocus()` 被调用
- AND 软键盘收起（移动端）
- AND WebView 获得视觉焦点

**涉及文件:** `lib/ui/pages/browser_page.dart` L196
**违反准则:** `focus-management`

---

### T5: 标签关闭无撤销机制

**User Story:** 作为用户，我希望关闭标签后能撤销此操作，这样我不会因误触而丢失正在浏览的页面。

**Acceptance Criteria:**
- GIVEN 用户关闭了一个标签
- WHEN 标签被关闭后
- THEN 显示 SnackBar 提示"已关闭标签：{标题}"，包含"撤销"按钮
- AND 点击"撤销"后恢复该标签（URL 和导航历史保留）
- AND SnackBar 在 5 秒后自动消失
- AND 若用户连续关闭多个标签，仅保留最近一个的撤销选项

**涉及文件:** `lib/ui/pages/browser_page.dart` L393-394
**违反准则:** `undo-support`

---

## P3: Performance — HIGH

### P1: 标签数量无上限与溢出处理

**User Story:** 作为用户，我希望打开大量标签时浏览器仍保持流畅，这样我不会遇到性能问题。

**Acceptance Criteria:**
- GIVEN 用户打开了超过 15 个标签
- WHEN 标签栏无法全部显示
- THEN 标签栏右侧显示溢出指示器（如 "▸" 按钮或 "N 个更多"）
- AND 标签栏水平滚动仍可正常使用
- AND 内存占用不会因标签数增加而线性增长（超过 5 个非活跃标签时考虑释放 WebView 资源）

**涉及文件:** `lib/ui/pages/browser_page.dart` L326-403
**违反准则:** `virtualize-lists`

---

### P2: URL 栏输入预留防抖接口

**User Story:** 作为用户，我希望在 URL 栏输入时获得搜索建议，且建议不会因快速输入而频繁请求。

**Acceptance Criteria:**
- GIVEN URL 栏添加了自动补全/建议功能
- WHEN 用户快速输入文本
- THEN 搜索建议请求被 300ms 防抖延迟
- AND 仅在用户停止输入 300ms 后触发建议查询
- AND 当前版本至少预留 debounce 基础设施（即使建议功能尚未实现）

**涉及文件:** `lib/ui/pages/browser_page.dart` L179-198
**违反准则:** `debounce-throttle`

---

### P3: 非活跃标签 WebView 资源管理

**User Story:** 作为用户，我希望打开多个标签时不会因内存占用过高导致应用卡顿。

**Acceptance Criteria:**
- GIVEN 用户打开了超过 5 个标签
- WHEN 非活跃标签数 > 5
- THEN 最早的非活跃标签 WebView 资源被释放（保留 URL 和标题，释放渲染资源）
- AND 用户切换回已释放的标签时自动重新加载
- AND 当前活跃标签和最近 4 个非活跃标签保持 `maintainState: true`

**涉及文件:** `lib/ui/pages/browser_page.dart` L236-298
**违反准则:** `main-thread-budget`

---

## P4: Style Selection — HIGH

### S1: 剪藏对话框硬编码英文

**User Story:** 作为非英文用户，我希望剪藏对话框的文本与我选择的语言一致，这样我能理解每个选项。

**Acceptance Criteria:**
- GIVEN 应用语言设置为非英文（如中文）
- WHEN 用户点击整页剪藏按钮
- THEN 对话框标题显示 l10n 文本（非 "Clip Page"）
- AND "Full Page" 选项显示 l10n 文本
- AND "Bookmark" 选项显示 l10n 文本
- AND 所有硬编码英文字符串替换为 `AppLocalizations` 调用

**涉及文件:** `lib/ui/pages/browser_page.dart` L606-633
**违反准则:** `consistency` + UX-10

---

### S2: 剪藏成功提示硬编码英文

**User Story:** 作为非英文用户，我希望剪藏成功的提示消息使用我的语言。

**Acceptance Criteria:**
- GIVEN 剪藏操作成功完成
- WHEN SnackBar 显示成功提示
- THEN 提示文本使用 l10n（非 `'Bookmarked: ${tab.title}'` 或 `'Clipped: ${tab.title}'`）
- AND 提示格式与 `_clipSelection` 中的 `l.savedToKnowledgeBase` 一致

**涉及文件:** `lib/ui/pages/browser_page.dart` L648-679
**违反准则:** `consistency`

---

### S3: 错误提示硬编码英文

**User Story:** 作为非英文用户，我希望所有错误提示使用我的语言。

**Acceptance Criteria:**
- GIVEN 剪藏操作失败或页面未加载
- WHEN 错误 SnackBar 显示
- THEN `'Page not loaded yet'` 替换为 l10n 文本
- AND `'Clip failed: $e'` 替换为 l10n 文本
- AND 所有用户可见字符串均通过 `AppLocalizations` 获取

**涉及文件:** `lib/ui/pages/browser_page.dart` L600-601, L673-679
**违反准则:** `consistency`

---

### S4: 图标风格不统一

**User Story:** 作为用户，我希望浏览器工具栏的图标风格一致，这样界面看起来专业且协调。

**Acceptance Criteria:**
- GIVEN 浏览器导航栏可见
- WHEN 观察所有图标
- THEN 所有未激活状态图标使用 outline 风格
- AND 所有激活状态图标使用 filled 风格
- AND 图标语义层级一致（导航类 vs 操作类不混用 filled/outline）
- AND 书签按钮：未收藏 → `bookmark_border`（outline），已收藏 → `bookmark`（filled）✓ 已符合，但剪藏按钮应统一风格

**涉及文件:** `lib/ui/pages/browser_page.dart` 多处
**违反准则:** `icon-style-consistent` + `filled-vs-outline-discipline`

---

### S5: 空状态引导不足

**User Story:** 作为新用户，我希望浏览器空状态页面能引导我下一步操作，这样我不会困惑该做什么。

**Acceptance Criteria:**
- GIVEN 浏览器无活跃标签
- WHEN 显示空状态页面
- THEN 包含主标题（如"开始浏览"）
- AND 包含副标题引导（如"打开一个网页开始探索，或从左侧书签中选择"）
- AND 包含"新建标签"按钮
- AND 包含快捷入口区域：最近访问的 3-5 个 URL 或常用书签
- AND 快捷入口点击后直接在新标签中打开

**涉及文件:** `lib/ui/pages/browser_page.dart` L109-142
**违反准则:** `empty-states` + UX-2

---

## P5: Layout & Responsive — HIGH

### L1: 导航栏间距不遵循 4/8dp 节奏

**User Story:** 作为用户，我希望浏览器导航栏的元素间距视觉节奏一致，这样界面看起来整洁专业。

**Acceptance Criteria:**
- GIVEN 浏览器导航栏可见
- WHEN 检查元素间距
- THEN 所有间距值为 4 的倍数（4/8/12/16）
- AND 导航按钮与 URL 栏间距统一为 8dp
- AND URL 栏与右侧按钮间距统一为 8dp
- AND 书签按钮与剪藏按钮间距统一为 8dp（当前为 4dp）

**涉及文件:** `lib/ui/pages/browser_page.dart` L153-206
**违反准则:** `spacing-scale`

---

### L2: URL 栏无聚焦态视觉区分

**User Story:** 作为用户，我希望点击 URL 栏时能明确看到输入框已激活，这样我知道当前可以输入。

**Acceptance Criteria:**
- GIVEN URL 栏处于非聚焦状态
- WHEN 用户点击 URL 栏
- THEN 输入框背景色变化（如 subtle 填充色）
- AND 输入框边框高亮（primary 色 1px 边框或下划线）
- AND 聚焦态过渡动画 ≤ 200ms
- AND 失焦时恢复非聚焦态样式

**涉及文件:** `lib/ui/pages/browser_page.dart` L175-198
**违反准则:** `state-clarity`

---

### L3: 标签栏无拖拽重排能力

**User Story:** 作为用户，我希望通过拖拽来调整标签顺序，这样我能按自己的习惯组织标签。

**Acceptance Criteria:**
- GIVEN 标签栏显示多个标签
- WHEN 用户长按并拖动某个标签
- THEN 标签跟随手指/鼠标移动
- AND 其他标签自动让位（带动画）
- AND 释放后标签停留在新位置
- AND 拖拽过程中有视觉反馈（标签略微放大或添加阴影）
- AND 使用 `ReorderableListView` 或自定义拖拽实现

**涉及文件:** `lib/ui/pages/browser_page.dart` L314-404
**违反准则:** `gesture-alternative`

---

### L4: 右侧面板初始宽度过小

**User Story:** 作为用户，我希望 AI 摘要面板有足够的宽度来舒适阅读内容。

**Acceptance Criteria:**
- GIVEN 右侧面板首次展开
- WHEN 面板以默认宽度显示
- THEN 初始宽度 ≥ 320px（当前 280px）
- AND 内容区正文行宽 ≥ 35 个字符
- AND 用户仍可通过拖拽调整宽度（180-450px）

**涉及文件:** `lib/ui/scenes/capture/capture_scene.dart` L92-95
**违反准则:** `readable-font-size` + `line-length-control`

---

### L5: 面板折叠无过渡动画

**User Story:** 作为用户，我希望侧边面板折叠/展开时有平滑的过渡效果，这样界面不会突然跳跃。

**Acceptance Criteria:**
- GIVEN 左侧或右侧面板处于展开状态
- WHEN 用户点击折叠按钮
- THEN 面板宽度以 200-300ms 动画收缩至折叠状态
- AND 使用 `AnimatedSize` 或 `AnimatedContainer` 实现
- AND 折叠按钮位置同步动画移动
- AND 动画使用 `Curves.easeInOut` 缓动曲线

**涉及文件:** `lib/ui/scenes/capture/capture_scene.dart` L78-90
**违反准则:** `state-transition`

---

## P6: Typography & Color — MEDIUM

### C1: 标签栏文字过小

**User Story:** 作为用户，我希望标签标题文字足够大以便快速阅读，这样我不需要仔细辨认每个标签。

**Acceptance Criteria:**
- GIVEN 标签栏显示标签标题
- WHEN 用户查看标签文字
- THEN 标签标题字体 ≥ 13px（`labelMedium` 或 `bodyMedium`）
- AND 标签栏高度相应调整至 38-40px 以容纳更大字体
- AND 标题仍使用 `TextOverflow.ellipsis` 处理溢出

**涉及文件:** `lib/ui/pages/browser_page.dart` L381-389
**违反准则:** `readable-font-size`

---

### C2: 激活标签仅靠微弱颜色区分

**User Story:** 作为用户，我希望一眼就能识别当前激活的标签，这样我不需要仔细辨别颜色差异。

**Acceptance Criteria:**
- GIVEN 标签栏显示多个标签
- WHEN 查看激活标签
- THEN 激活标签有底部指示条（2-3px 高，primary 色）
- AND 激活标签背景色与未激活标签有 ≥ 10% 透明度差异
- AND 在深色主题下激活/未激活标签仍可清晰区分
- AND 颜色不是唯一的区分手段（结合位置+指示条）

**涉及文件:** `lib/ui/pages/browser_page.dart` L349-353
**违反准则:** `color-not-only`

---

### C3: URL 栏 hint 与输入文字风格不一致

**User Story:** 作为用户，我希望 URL 栏聚焦时文字不会出现视觉跳动。

**Acceptance Criteria:**
- GIVEN URL 栏处于非聚焦状态（显示 hint）
- WHEN 用户聚焦 URL 栏
- THEN hint 文字与输入文字使用相同字号和字重
- AND 仅颜色不同（hint 用 `hintColor`，输入用 `textTheme.bodyMedium` 颜色）
- AND 聚焦/失焦时无文字大小跳动

**涉及文件:** `lib/ui/pages/browser_page.dart` L184-185
**违反准则:** `weight-hierarchy`

---

### C4: AI 摘要面板正文使用过小字体

**User Story:** 作为用户，我希望 AI 摘要内容使用舒适的阅读字体大小。

**Acceptance Criteria:**
- GIVEN AI 摘要面板显示生成的摘要内容
- WHEN 用户阅读摘要
- THEN 正文使用 `bodyMedium`（14-16px）而非 `bodySmall`（12px）
- AND 行高为 1.5-1.6
- AND 在 320px 宽面板中每行约 35-45 个中文字符

**涉及文件:** `lib/ui/scenes/capture/capture_scene.dart` L658
**违反准则:** `contrast-readability`

---

## P7: Animation — MEDIUM

### M1: 标签切换无过渡动画

**User Story:** 作为用户，我希望切换标签时有平滑的视觉过渡，这样界面不会突然闪烁。

**Acceptance Criteria:**
- GIVEN 用户从一个标签切换到另一个标签
- WHEN WebView 可见性发生变化
- THEN 新标签以 150-200ms 淡入显示
- AND 旧标签以 100-150ms 淡出
- AND 使用 `AnimatedOpacity` 包裹 WebView
- AND 动画不阻塞用户交互

**涉及文件:** `lib/ui/pages/browser_page.dart` L236-298
**违反准则:** `continuity` + `state-transition`

---

### M2: 加载指示器无入场动画

**User Story:** 作为用户，我希望标签加载指示器的出现和消失是平滑的。

**Acceptance Criteria:**
- GIVEN 标签开始加载
- WHEN 加载指示器出现
- THEN 使用 `AnimatedSwitcher`（200ms crossfade）从地球图标过渡到 spinner
- AND 加载完成后以相同动画过渡回地球图标
- AND 动画不改变标签的布局大小

**涉及文件:** `lib/ui/pages/browser_page.dart` L360-368
**违反准则:** `loading-states`

---

### M3: 书签按钮状态切换无动画

**User Story:** 作为用户，我希望点击书签按钮时有愉悦的动画反馈。

**Acceptance Criteria:**
- GIVEN 用户点击书签按钮
- WHEN 图标从 `bookmark_border` 切换到 `bookmark`
- THEN 使用 `AnimatedSwitcher`（200ms crossfade）过渡
- OR 使用 scale 弹跳动画（0.8 → 1.1 → 1.0，总时长 300ms）
- AND 反向切换（取消书签）也有对应动画

**涉及文件:** `lib/ui/pages/browser_page.dart` L414-443
**违反准则:** `state-transition`

---

## P8: Forms & Feedback — MEDIUM

### F1: URL 栏无自动补全/建议

**User Story:** 作为用户，我希望在 URL 栏输入时看到历史记录和书签匹配建议，这样我能快速访问常用网站。

**Acceptance Criteria:**
- GIVEN 用户在 URL 栏输入文本
- WHEN 输入长度 ≥ 2 个字符
- THEN 显示下拉建议列表，匹配历史访问 URL 和书签
- AND 建议列表最多显示 5 项
- AND 建议请求有 300ms 防抖
- AND 点击建议项直接导航到对应 URL
- AND 按 Esc 关闭建议列表

**涉及文件:** `lib/ui/pages/browser_page.dart` L179-198
**违反准则:** `input-helper-text` + UX-5

---

### F2: URL 输入无验证反馈

**User Story:** 作为用户，我希望输入无效 URL 时获得明确提示，这样我知道输入有误。

**Acceptance Criteria:**
- GIVEN 用户在 URL 栏输入文本并按回车
- WHEN 输入被识别为 URL 但格式无效（如包含空格的域名）
- THEN URL 栏下方显示简短错误提示（如"无效的网址"）
- AND 输入框边框变为 error 色
- AND 输入仍被当作搜索关键词处理（不阻断用户流程）

**涉及文件:** `lib/ui/pages/browser_page.dart` L301-311
**违反准则:** `error-clarity`

---

### F3: 剪藏对话框选项过于简陋

**User Story:** 作为用户，我希望剪藏对话框提供更多选项，这样我能控制剪藏的内容和格式。

**Acceptance Criteria:**
- GIVEN 用户点击整页剪藏按钮
- WHEN 剪藏对话框显示
- THEN 提供格式选择（Markdown / HTML / 纯文本）
- AND 提供目标文件夹选择（默认为 `clippings/`）
- AND 显示页面标题（可编辑）
- AND 高级选项折叠显示（渐进式披露）
- AND 所有文本使用 l10n

**涉及文件:** `lib/ui/pages/browser_page.dart` L606-633
**违反准则:** `progressive-disclosure`

---

### F4: 添加书签对话框无编辑能力

**User Story:** 作为用户，我希望添加书签时能编辑标题和创建新文件夹，这样书签更易管理。

**Acceptance Criteria:**
- GIVEN 用户点击书签按钮添加新书签
- WHEN 添加书签对话框显示
- THEN 页面标题字段可编辑（TextField，预填当前标题）
- AND 文件夹列表下方有"新建文件夹"按钮
- AND 点击"新建文件夹"弹出输入框，输入后立即出现在文件夹列表中
- AND 新建文件夹自动被选中

**涉及文件:** `lib/ui/pages/browser_page.dart` L836-919
**违反准则:** `form-autosave`

---

### F5: SnackBar 反馈不一致

**User Story:** 作为用户，我希望所有操作反馈的格式和持续时间一致。

**Acceptance Criteria:**
- GIVEN 任何操作触发 SnackBar 反馈
- WHEN SnackBar 显示
- THEN 所有成功提示持续 3 秒
- AND 所有警告提示持续 4 秒
- AND 所有错误提示持续 5 秒
- AND 成功提示包含操作按钮（如"查看"、"撤销"）
- AND 取消书签提供"撤销"选项
- AND SnackBar 使用统一的视觉样式

**涉及文件:** `lib/ui/pages/browser_page.dart` 多处
**违反准则:** `toast-dismiss`

---

## P9: Navigation Patterns — HIGH

### N1: 标签无右键/长按菜单

**User Story:** 作为用户，我希望右键或长按标签时看到操作菜单，这样我能快速执行标签管理操作。

**Acceptance Criteria:**
- GIVEN 标签栏显示多个标签
- WHEN 用户右键点击（桌面）或长按（触屏）某个标签
- THEN 显示上下文菜单，包含以下选项：
  - 关闭此标签
  - 关闭其他标签
  - 关闭右侧所有标签
  - 复制 URL
  - 固定/取消固定标签
- AND 菜单项使用 l10n 文本
- AND 仅一个标签时"关闭其他标签"选项禁用

**涉及文件:** `lib/ui/pages/browser_page.dart` L343-400
**违反准则:** `overflow-menu`

---

### N2: 标签分组功能已实现但未集成

**User Story:** 作为用户，我希望将标签分组管理，这样我能按项目或主题组织浏览内容。

**Acceptance Criteria:**
- GIVEN `TabGroupSidebar` 组件已存在
- WHEN 用户希望管理标签分组
- THEN 标签分组功能可通过以下入口访问：
  - 标签栏右键菜单中的"添加到分组"
  - 左侧面板新增"标签分组"标签页
- AND 分组后的标签在标签栏中有颜色标识
- AND 点击分组可展开/折叠组内标签
- AND `TabGroupSidebar` 被集成到 `CaptureScene` 或 `NoteSidebar`

**涉及文件:** `lib/ui/widgets/tab_group_sidebar.dart`
**违反准则:** `nav-hierarchy`

---

### N3: 无浏览器键盘快捷键

**User Story:** 作为键盘用户，我希望使用标准浏览器快捷键操作标签和导航，这样我能高效浏览。

**Acceptance Criteria:**
- GIVEN 浏览器页面处于活跃状态
- WHEN 用户按下以下快捷键
- THEN 对应操作被执行：
  - `Ctrl+T` → 新建标签
  - `Ctrl+W` → 关闭当前标签
  - `Ctrl+L` → 聚焦 URL 栏
  - `Ctrl+Tab` / `Ctrl+Shift+Tab` → 切换标签
  - `Ctrl+1-9` → 切换到第 N 个标签
  - `F5` / `Ctrl+R` → 刷新
  - `Alt+←` / `Alt+→` → 后退/前进
- AND 快捷键在 macOS 上使用 `Cmd` 替代 `Ctrl`
- AND 快捷键不与系统级快捷键冲突

**涉及文件:** `lib/ui/pages/browser_page.dart` 全局
**违反准则:** `keyboard-shortcuts` + UX-7

---

### N4: 后退/前进按钮无禁用态

**User Story:** 作为用户，我希望后退/前进按钮在无历史记录时显示为禁用状态，这样我知道当前无法后退/前进。

**Acceptance Criteria:**
- GIVEN WebView 导航历史为空（无法后退）
- WHEN 查看后退按钮
- THEN 后退按钮显示为禁用态（灰色 + 不可点击）
- AND 同理前进按钮在无前进历史时禁用
- AND 通过 `WebViewController.canGoBack()` / `canGoForward()` 判断状态
- AND 状态在页面加载完成后更新

**涉及文件:** `lib/ui/pages/browser_page.dart` L161-172
**违反准则:** `disabled-states`

---

### N5: URL 栏不显示安全状态

**User Story:** 作为用户，我希望在 URL 栏看到当前连接的安全状态，这样我能判断网站是否安全。

**Acceptance Criteria:**
- GIVEN 页面已加载完成
- WHEN 查看 URL 栏
- THEN HTTPS 页面在 URL 前显示锁图标（`Icons.lock`，绿色）
- AND HTTP 页面在 URL 前显示警告图标（`Icons.warning_amber`，橙色）
- AND 点击安全图标显示简要安全信息（证书域名）
- AND 图标在 URL 栏左侧，搜索图标之前或替代搜索图标

**涉及文件:** `lib/ui/pages/browser_page.dart` L175-198
**违反准则:** `nav-state-active`

---

## P10: Architecture & Product UX

### X1: browser_page.dart 巨型组件需拆分

**User Story:** 作为开发者，我希望浏览器页面的代码按职责拆分为独立组件，这样代码更易维护和测试。

**Acceptance Criteria:**
- GIVEN `browser_page.dart` 当前约 920 行
- WHEN 重构完成
- THEN 拆分为以下独立组件：
  - `BrowserTabBar` — 标签栏
  - `BrowserNavigationBar` — 导航栏（后退/前进/刷新）
  - `BrowserUrlBar` — URL 输入栏
  - `BrowserBookmarkButton` — 书签按钮
  - `BrowserClipButtons` — 剪藏按钮组
  - `BrowserWebViewStack` — WebView 容器
- AND 每个组件 ≤ 200 行
- AND `BrowserView` 仅负责组合子组件
- AND 所有现有功能不受影响

**涉及文件:** `lib/ui/pages/browser_page.dart`
**违反准则:** A-3

---

### X2: 剪藏功能重复实现需统一

**User Story:** 作为开发者，我希望剪藏功能只有一处实现，这样修改时不会遗漏。

**Acceptance Criteria:**
- GIVEN `BrowserView` 内联了 `_clipPage`/`_clipSelection`，`ClipToolbar` 也实现了相同逻辑
- WHEN 统一完成
- THEN 剪藏逻辑仅存在于一个位置（推荐 `ClipToolbar` 或独立的 `ClipService`）
- AND `BrowserView` 通过回调或 Provider 调用统一实现
- AND `ClipToolbar` 被集成到 `BrowserView` 中替代内联按钮
- AND 删除重复代码

**涉及文件:** `lib/ui/pages/browser_page.dart`, `lib/ui/widgets/clip_toolbar.dart`
**违反准则:** A-2

---

### X3: 无页面加载进度条

**User Story:** 作为用户，我希望看到页面加载的进度指示，这样我知道页面正在加载且大约还需多久。

**Acceptance Criteria:**
- GIVEN 用户导航到新页面
- WHEN 页面开始加载
- THEN 导航栏下方显示 `LinearProgressIndicator`
- AND 进度条使用 primary 色
- AND 进度条高度 2-3px
- AND 页面加载完成后进度条淡出（200ms）
- AND 加载失败时进度条变为 error 色后淡出

**涉及文件:** `lib/ui/pages/browser_page.dart` L206-217
**违反准则:** UX-4

---

### X4: 无阅读模式

**User Story:** 作为用户，我希望在浏览长文章时切换到阅读模式，这样我能专注于内容而不被页面装饰干扰。

**Acceptance Criteria:**
- GIVEN 当前页面包含可提取的正文内容
- WHEN 用户点击"阅读模式"按钮
- THEN 页面切换为简化视图，仅显示：
  - 标题
  - 作者/日期（如可提取）
  - 正文（去除广告、侧边栏、导航等）
- AND 阅读模式使用应用主题色渲染（支持深色模式）
- AND 提供退出阅读模式按钮
- AND 阅读模式中可调整字体大小

**涉及文件:** 新组件
**违反准则:** UX-9

---

### X5: 无标签悬停预览

**User Story:** 作为用户，我希望悬停在标签上时看到页面缩略图预览，这样我能快速识别标签内容。

**Acceptance Criteria:**
- GIVEN 标签栏显示多个标签
- WHEN 用户悬停在某个非活跃标签上超过 500ms
- THEN 显示该标签的缩略图预览（使用 `_takeScreenshot` 已有功能）
- AND 预览图宽度约 240px，高度按比例缩放
- AND 预览图显示标签标题
- AND 鼠标移开后预览立即消失
- AND 截图缓存避免重复获取

**涉及文件:** `lib/ui/pages/browser_page.dart` L343
**违反准则:** UX-5

---

### X6: 搜索引擎不可配置

**User Story:** 作为用户，我希望选择默认搜索引擎，这样搜索结果符合我的偏好。

**Acceptance Criteria:**
- GIVEN 应用设置页面可见
- WHEN 用户查看搜索引擎选项
- THEN 可选择以下搜索引擎：
  - Bing（默认）
  - Google
  - DuckDuckGo
  - 自定义搜索引擎（输入搜索 URL 模板）
- AND 选择后 URL 栏的搜索查询使用新引擎
- AND 搜索引擎设置持久化到 `rfbrowser_config.json`

**涉及文件:** `lib/ui/pages/browser_page.dart` L308, `lib/services/settings_service.dart`
**违反准则:** UX-1

---

## 实施路线图

### Phase 1: 零风险快速修复（1-2 天）

| ID | 优化点 | 预估工作量 | 风险 |
|----|--------|-----------|------|
| S1 | 剪藏对话框硬编码英文 → l10n | 0.5h | 无 |
| S2 | 剪藏成功提示硬编码英文 → l10n | 0.5h | 无 |
| S3 | 错误提示硬编码英文 → l10n | 0.5h | 无 |
| A3 | 导航按钮添加 Tooltip | 0.5h | 无 |
| T4 | URL 提交后 unfocus | 0.2h | 无 |
| L1 | 导航栏间距统一 8dp | 0.5h | 低 |

### Phase 2: 交互体验提升（3-5 天）

| ID | 优化点 | 预估工作量 | 风险 |
|----|--------|-----------|------|
| T2 | 标签切换 InkWell 反馈 | 1h | 低 |
| A1 | 关闭按钮触控区扩大 | 1h | 低 |
| C2 | 激活标签底部指示条 | 1h | 低 |
| L2 | URL 栏聚焦态视觉增强 | 1h | 低 |
| N4 | 后退/前进按钮禁用态 | 2h | 中（需异步状态） |
| N5 | HTTPS 安全指示器 | 2h | 中 |
| T3 | 剪藏操作 loading 状态 | 2h | 低 |
| X3 | 页面加载进度条 | 2h | 中 |
| C3 | URL 栏 hint/输入风格统一 | 0.5h | 低 |

### Phase 3: 导航与效率（5-7 天）

| ID | 优化点 | 预估工作量 | 风险 |
|----|--------|-----------|------|
| N3 | 浏览器键盘快捷键 | 3h | 中 |
| N1 | 标签右键/长按菜单 | 3h | 中 |
| T5 | 标签关闭撤销 | 2h | 中 |
| F5 | SnackBar 反馈统一 | 1h | 低 |
| M1 | 标签切换过渡动画 | 2h | 低 |
| M2 | 加载指示器入场动画 | 1h | 低 |
| M3 | 书签按钮状态动画 | 1h | 低 |
| L5 | 面板折叠过渡动画 | 2h | 中 |

### Phase 4: 功能增强（7-14 天）

| ID | 优化点 | 预估工作量 | 风险 |
|----|--------|-----------|------|
| F1 | URL 栏自动补全/建议 | 5h | 高 |
| L3 | 标签拖拽重排 | 4h | 高 |
| S5 | 空状态引导增强 | 2h | 低 |
| F4 | 书签对话框编辑能力 | 3h | 中 |
| F3 | 剪藏对话框增强 | 3h | 中 |
| N2 | 标签分组集成 | 5h | 高 |
| X6 | 搜索引擎可配置 | 3h | 中 |
| C1 | 标签栏字体增大 | 1h | 低 |
| C4 | AI 摘要字体增大 | 0.5h | 无 |
| L4 | 右侧面板初始宽度增大 | 0.5h | 无 |

### Phase 5: 架构重构与高级功能（14+ 天）

| ID | 优化点 | 预估工作量 | 风险 |
|----|--------|-----------|------|
| X1 | browser_page.dart 组件拆分 | 8h | 高 |
| X2 | 剪藏功能统一 | 4h | 中 |
| P3 | 非活跃标签资源管理 | 5h | 高 |
| X4 | 阅读模式 | 8h | 高 |
| X5 | 标签悬停预览 | 5h | 中 |
| P1 | 标签数量上限与溢出 | 3h | 中 |
| A2 | 标签语义标签 | 2h | 低 |
| A4 | 剪藏按钮 disabled 语义 | 1h | 低 |
| A5 | URL 栏表单标签 | 1h | 低 |
| F2 | URL 输入验证反馈 | 2h | 中 |
| P2 | URL 栏防抖基础设施 | 1h | 低 |
| T1 | 标签栏高度调整 | 1h | 低 |
| S4 | 图标风格统一 | 2h | 低 |

---

## 统计

| 优先级 | 数量 | 占比 |
|--------|------|------|
| CRITICAL (P1-P2) | 10 | 25% |
| HIGH (P3-P5, P9) | 14 | 35% |
| MEDIUM (P6-P8) | 10 | 25% |
| LOW (P10) | 6 | 15% |
| **总计** | **40** | **100%** |
