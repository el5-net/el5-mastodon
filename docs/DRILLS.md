# 升级演练留档（DRILLS）

> 环境：Windows / Git Bash（GNU bash 5.2.37）/ git 2.51.0.windows.1。
> 上游源：`https://github.com/mastodon/mastodon.git`，`build.sh` 每次 fetch `v4.7.2` 与目标 tag 两个浅引用。
> 本文只记录**实际执行**的命令与输出；演练期间没有修改任何补丁（v5 干跑只记录不修）。

## 1. v4.7.6 正式装配（2026-11-25T15:18:27+08:00）

命令：

```bash
rm -rf src && bash build.sh
```

完整输出（5 个 `Applying:` 行齐全，退出码 0）：

```text
>> Assembling Mastodon v4.7.6 + 5 patches (base v4.7.2)
>> Applying patches (3-way)...
Applying: feat: raise max toot chars to 5000
Applying: feat: raise poll options to 16
Applying: feat: tune trending statuses thresholds
Applying: feat: show only 5 recent posts to logged-out visitors
Applying: feat: chinese search analyzers (ik_max_word + stconvert)
>> OK: src/ = Mastodon v4.7.6 + el5 定制, 构建镜像即可:
   docker build -f src/Dockerfile -t maisuier/mastodon:v4.7.6 src
   docker build -f src/streaming/Dockerfile -t maisuier/mastodon-streaming:v4.7.6 src/streaming
```

验证命令与完整输出：

```bash
FORK="C:/Users/maisui/.local/share/opencode/worktree/6f38e6/nimble-nebula" bash verify.sh
```

```text
== src/ 提交历史 ==
efc92c1 feat: chinese search analyzers (ik_max_word + stconvert)
39e143d feat: show only 5 recent posts to logged-out visitors
ebe1c3c feat: tune trending statuses thresholds
9c8e10d feat: raise poll options to 16
cdc1342 feat: raise max toot chars to 5000
a593c94 Bump version to v4.7.6

== 与 fork HEAD 逐字节对比 (FORK=C:/Users/maisui/.local/share/opencode/worktree/6f38e6/nimble-nebula) ==
  OK    app/validators/status_length_validator.rb
  OK    app/validators/poll_options_validator.rb
  OK    app/models/trends/statuses.rb
  OK    app/controllers/api/v1/accounts/statuses_controller.rb
  OK    app/chewy/accounts_index.rb
  OK    app/chewy/statuses_index.rb
  OK    app/chewy/tags_index.rb

== 热点抽查 ==
MAX_CHARS = 5000
MAX_OPTIONS      = 16
threshold: 2
ik_max_word
limit(5)

>> 全部通过
```

另跑了一次无 `FORK` 的降级模式 `bash verify.sh`，输出含
`>> 跳过字节级比对（未提供 FORK）`，5 项热点仍全部命中，末尾 `>> 全部通过`，退出码 0。

**结论**：5/5 补丁干净应用，7 个文件与 fork HEAD 逐字节一致，5 项热点抽查全绿。

## 2. v5.0.0-beta.1 干跑（2026-11-25T15:19:08+08:00）

命令：

```bash
MASTODON_REF=v5.0.0-beta.1 bash build.sh
```

完整输出（退出码 0）：

```text
>> Assembling Mastodon v5.0.0-beta.1 + 5 patches (base v4.7.2)
>> Applying patches (3-way)...
Applying: feat: raise max toot chars to 5000
Applying: feat: raise poll options to 16
Applying: feat: tune trending statuses thresholds
Applying: feat: show only 5 recent posts to logged-out visitors
Applying: feat: chinese search analyzers (ik_max_word + stconvert)
>> OK: src/ = Mastodon v5.0.0-beta.1 + el5 定制, 构建镜像即可:
   docker build -f src/Dockerfile -t maisuier/mastodon:v5.0.0-beta.1 src
   docker build -f src/streaming/Dockerfile -t maisuier/mastodon-streaming:v5.0.0-beta.1 src/streaming
```

5 个补丁逐项结论：

| # | 补丁 | 结果 |
|---|------|------|
| 1 | 0001 raise max toot chars to 5000 | 干净应用（`Applying:` 一行通过，无冲突/hunk 提示） |
| 2 | 0002 raise poll options to 16 | 干净应用 |
| 3 | 0003 tune trending statuses thresholds | 干净应用 |
| 4 | 0004 show only 5 recent posts to logged-out | 干净应用 |
| 5 | 0005 chinese search analyzers (ik + stconvert) | 干净应用 |

辅助证据：

```text
$ git -C src status --short
(空，工作区干净)

$ git -C src log --oneline -6
25cf7ac feat: chinese search analyzers (ik_max_word + stconvert)
285d8ef feat: show only 5 recent posts to logged-out visitors
c249efa feat: tune trending statuses thresholds
3b3f7f9 feat: raise poll options to 16
eb2f1d0 feat: raise max toot chars to 5000
08b0542 Bump version to v5.0.0-beta.1 (#41513)

$ # 5 项热点抽查（v5 装配产物）
MAX_CHARS = 5000
MAX_OPTIONS      = 16
threshold: 2
ik_max_word
limit(5)
```

**结论**：**5/5 干净应用**，无需修补丁；升 5.x 的补丁工作量预算目前为零。
按约定本次**只记录不修**，未做镜像构建、未做数据迁移验证；干跑产生的 `src/` 已 `rm -rf` 删除。
真实跨大版本升级仍须按官方路径逐版本走并跑数据库迁移（见 README 第 4 节）。
