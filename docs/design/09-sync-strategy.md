# RFBrowser — 同步方案设计

---

## Git 同步

```
Vault (本地)
    │
    ├──→ git init (首次)
    ├──→ git remote add origin <url>
    │
    ├──→ 自动提交（每次保存后延迟 30s）
    │     git add -A && git commit -m "auto: update notes"
    │
    ├──→ 定时拉取（每 5 分钟）
    │     git pull --rebase
    │
    └──→ 手动推送/拉取
          git push / git pull
```

**冲突处理**：
- Markdown 文件级别冲突：自动合并（Git merge）
- 无法自动合并时：生成冲突标记，提示用户手动解决
- `.rfbrowser/cache/` 目录加入 `.gitignore`

---

## WebDAV 同步

```
Vault (本地)
    │
    ├──→ 文件变更检测（WatchService）
    │
    ├──→ 增量上传（仅上传变更文件）
    │     PUT /dav/vault/notes/example.md
    │
    ├──→ 增量下载（ETag 比较）
    │     GET /dav/vault/notes/example.md
    │     If-None-Match: "etag-value"
    │
    └──→ 冲突处理
          本地较新 → 上传覆盖
          远端较新 → 下载覆盖
          双方修改 → 保留两份，标记冲突
```

---

## 当前实现状态

WebDAV 同步已完整实现（`lib/services/webdav_sync_service.dart`）：
- SyncStore 持久化 ETag/lastSync/localModified 状态
- downloadChanges：基于 ETag 的增量下载 + 冲突检测
- uploadChanges：基于 mtime 的增量上传
- SyncConflict 模型，3 种解决策略（keepLocal / keepRemote / keepBoth）
- SyncProgressWidget UI + SyncConflictDialog
- 自动定时同步 Timer
- 11 个测试通过
