# RFBrowser — AI 增强知识浏览器 设计文档

> **RFBrowser**: 融合浏览（Browse）与知识流（Flow），让信息在获取与组织之间自由流动

---

## 设计文档索引

本目录包含 RFBrowser 的完整设计文档。原 `DESIGN.md` 已按功能模块拆分为以下子文档：

### 产品定义

| 文档 | 内容 |
|------|------|
| [01-product-vision.md](docs/design/01-product-vision.md) | 产品愿景、核心差异化、关键决策记录（ADR） |

### 架构设计

| 文档 | 内容 |
|------|------|
| [02-architecture.md](docs/design/02-architecture.md) | 系统分层架构、项目目录结构、技术栈汇总 |
| [03-data-models.md](docs/design/03-data-models.md) | Vault 文件结构、Note/WebClip/Link/AgentTask/Skill/Plugin 模型、ContextAssembly、@引用语法 |
| [04-core-engines.md](docs/design/04-core-engines.md) | Markdown引擎、LinkResolver、GraphEngine、ContextAssembler、SearchEngine、ModelRouter |
| [05-services.md](docs/design/05-services.md) | Browser/Knowledge/AI/Agent/Plugin/Sync 六个 Service 的接口定义 |

### 子系统设计

| 文档 | 内容 |
|------|------|
| [06-plugin-system.md](docs/design/06-plugin-system.md) | 插件架构、manifest.yaml、API Surface、Sandbox、Skill 系统 |
| [07-ui-layout.md](docs/design/07-ui-layout.md) | 桌面/Android 布局、视图模式、CommandBar、国际化方案 |
| [08-agent-system.md](docs/design/08-agent-system.md) | Agent 执行流程、安全约束、预定义任务、当前实现状态 |
| [09-sync-strategy.md](docs/design/09-sync-strategy.md) | Git 同步、WebDAV 同步、冲突处理、当前实现状态 |

### 开发路线图

| 文档 | 内容 |
|------|------|
| [10-roadmap.md](docs/design/10-roadmap.md) | Phase 1-5 路线图、执行优先级、依赖关系、关键风险 |

### 功能详细计划

| 文档 | 内容 | Phase |
|------|------|-------|
| [feature-plans/phase2.md](docs/design/feature-plans/phase2.md) | P2-1 图谱增强 / P2-2 @引用系统 / P2-3 AI标签分组 | Phase 2 ✅ |
| [feature-plans/phase3.md](docs/design/feature-plans/phase3.md) | P3-1 Agent自动化 / P3-2 上下文组装器 / P3-3 WebDAV | Phase 3 ✅ |
| [feature-plans/phase4.md](docs/design/feature-plans/phase4.md) | P4-1 插件API Bridge / P4-3 语义搜索 / P4-5 性能 / P4-6 插件市场 / P4-7 Skill市场 | Phase 4 🔶 |
| [feature-plans/phase5.md](docs/design/feature-plans/phase5.md) | P5-4 Linux浏览器 / P5-5 离线模式 / P5-6~P5-11 发布准备 | Phase 5 🔶 |

### 改进计划

| 文档 | 内容 |
|------|------|
| [improvement-plans.md](docs/improvement-plans.md) | 2026-05-04 代码审计发现的 13 个改进项，含 User Stories 和可自动化验收标准 |

---

## 快速导航

- **想了解产品定位？** → [01-product-vision.md](docs/design/01-product-vision.md)
- **想看架构全貌？** → [02-architecture.md](docs/design/02-architecture.md)
- **想了解当前进度？** → [10-roadmap.md](docs/design/10-roadmap.md)
- **想找待解决的问题？** → [improvement-plans.md](docs/improvement-plans.md)
- **想看某个 Phase 的详细计划？** → [feature-plans/](docs/design/feature-plans/)

---

## 开发阶段总览

| Phase | 目标 | 状态 | 说明 |
|-------|------|------|------|
| Phase 1 | 基础框架 MVP | ✅ 完成 | 三平台可运行，浏览器+编辑器+AI Chat |
| Phase 2 | 知识核心 | ✅ 完成 | wikilink、剪藏、模板、Daily Notes、图谱、@引用、AI分组 |
| Phase 3 | AI 增强 | ✅ 完成 | Agent自动化、上下文组装、WebDAV同步 |
| Phase 4 | 生态扩展 | 🔶 ~60% | Canvas已有、主题已有、未链接提及已有、Dataview已有；API Bridge和语义搜索本地嵌入待完善 |
| Phase 5 | 打磨发布 | 🔶 ~70% | 快捷键/拖拽/编辑器增强已完成；Linux浏览器和离线模式待完善 |
