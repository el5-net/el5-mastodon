# el5-mastodon：Mastodon 补丁包仓库

本仓库**只保存"我的修改"**——5 个 `git format-patch` 补丁和一套装配脚本。
上游 Mastodon 源码不入库，只按 tag 引用；构建时拉取官方源码，再用 `git am --3way`
把补丁打上去，生成 `src/`（可直接构建镜像）。仓库里没有上游代码，也没有旧 fork 的历史。

快速开始（日常只需要这两条）：

```bash
bash build.sh          # 拉上游 + 打补丁 -> src/
bash verify.sh         # 验证 5 处定制都在（可选 FORK=<旧 fork 路径> 加做逐字节比对）
```

## 1. 这个仓库是什么，为什么放弃 fork

旧模式是 fork 一份 Mastodon 再改：每次升级都要把上游几个月的上百个提交 merge 进来，
冲突动辄上千文件，绝大多数和自己的改动无关；如果把上游 squash 进 fork，上游的逐提交历史
就没了，下次再 merge 连可用的 merge-base 都找不到，三方合并退化成全文件对比。
两种做法都把维护者时间耗在"和别人的代码打架"上。

现在反过来：**官方源码归官方，本仓库只存自己的 5 个补丁**。上游按 tag 引用，补丁是唯一的
资产。升级不再 merge，只改一个版本号重新装配；冲突面收敛到真正改过的 7 个文件。

## 2. 为什么用 `git am --3way`，为什么不做模块系统

- `git format-patch` 导出的补丁自带基线 blob 信息（基线为 `v4.7.2`，记录在 `PATCH_BASE`）。
  `git am --3way` 用这些 blob 做三方合并：上游在**别处**改了代码，git 会自动消化；
  只有上游正好也改了同一处，才会停下来报冲突。这比 `patch -p1` 的"行号对不上就挂"稳得多。
- `format-patch` / `am` 是 Linux 内核社区几十年验证的原生工作流，git 自带、零依赖，
  不需要发明任何新机制。Windows 上唯一的坑是 `core.autocrlf` 改写补丁行尾，已由
  `.gitattributes` 的 `*.patch -text` 挡住。
- **不做模块系统、Python loader、依赖图**：单人维护，只有 5 个功能、7 个文件，
  复杂度预算为零。能用一行脚本解决的，不引入第二层抽象。

## 3. 升级 SOP

1. 看 Mastodon 官方 release notes，留意有无 GHSA / 破坏性变更（安全版本别攒，见下节）。
2. 改 `build.sh` 顶部的 `MASTODON_REF` **一行**即可（也可用环境变量覆盖，如
   `MASTODON_REF=v4.7.6 bash build.sh`）。`PATCH_BASE` 不要随手改——它决定三方合并的祖先。
3. 跑 `bash build.sh`。看 `git am --3way` 的输出：5 个补丁依次 `Applying...` 且最后打印
   `>> OK:` 即成功；`src/` 是完整可装配产物。
4. 跑 `bash verify.sh`：热点抽查全部命中即通过；本地还留着旧 fork 时可加
   `FORK=<旧 fork 路径>` 追加逐字节比对。
5. 干净则提交这次版本号变更、打 tag 触发 CI。CI 接线（后续单元）后，tag push 会自动构建
   并推送镜像：Docker Hub `maisuier/mastodon` 与 `maisuier/mastodon-streaming`，同时推 ghcr。

### 补丁撞上了怎么办

`git am --3way` 停在哪个补丁会**具名报错**（`Patch failed at 000N ...` 并列出冲突文件），
不会悄悄跳过。按下面处理：

```bash
git -C src am --show-current-patch=diff   # 看撞在哪个补丁、哪个 hunk
git -C src status                          # 看冲突文件
# 直接在 src/ 里手工改好冲突文件（保留自己的定制语义）
git -C src add <冲突文件>
git -C src am --continue                   # 让本次装配走完
# 把修正回写为补丁，替换 patches/ 中对应的那一个（format-patch 固定输出 0001-*，须改名）：
git -C src log --oneline --grep="<该补丁的提交标题>" -1   # 找到它的提交 sha
git -C src format-patch -1 <sha> -o /tmp/reexport
cp /tmp/reexport/0001-*.patch patches/0003-feat-tune-trending-statuses-thresholds.patch
rm -rf src && bash build.sh && bash verify.sh            # 从零复验
```

（上例以修复 0003 为例；目标文件名按实际补丁编号/标题替换。）

若不想在本轮修，直接放弃本次装配：`git -C src am --abort && rm -rf src`，
回头再改 `patches/` 里的对应补丁重跑。`build.sh` 失败时也会打印这几条指引。
注意：**换 PATCH_BASE 等于换三方合并的祖先，所有补丁都要重新导出**，别只改一行蒙混过关。
另外，这样回写的补丁其基线 blob 会变成修复时的版本（如 v4.7.6），而 `build.sh` 只 fetch
`PATCH_BASE`（v4.7.2）与目标 tag，下次升级时 `--3way` 可能静默退化为普通 apply；
修完冲突后建议尽快按 `tools/make-patches.sh` 的思路把整个补丁系列在当前基线上重导一遍，
并同步更新 `build.sh` 的 `PATCH_BASE`。

## 4. 跳版本规则

- **同一大版本内随便跳**：v4.7.2 → v4.7.6 这类 patch/minor 升级，上游 tag 是完整状态，
  改一行 `MASTODON_REF` 直接装配即可，不必逐个版本走。
- **跨大版本禁止跳**：4.x → 5.x 必须按 Mastodon 官方升级路径逐版本走，并在每个中间版本
  执行数据库迁移；直接跳会跳过迁移，可能损坏生产数据。跨大版本还要重新评估 5 个补丁
  （`docs/DRILLS.md` 里的 v5.0.0-beta.1 干跑记录就是升级预算输入）。
- **安全版本别攒**：带 GHSA 修复的版本发布后尽快升级。教训样本：v4.7.5 一个版本就含
  3 个 GHSA，攒着不升等于把窗口期留给自己。

## 5. 部署侧依赖（不在本仓库范围）

5 号补丁把中文搜索改成 `ik_max_word` + `stconvert` 分析器。**Elasticsearch 必须自行安装
`analysis-ik` 和 `analysis-stconvert` 插件**（每个 ES 节点都装并重启），然后重建 Chewy 索引
（例如 `RAILS_ENV=production ./bin/rails chewy:reset`），否则中文搜索会静默失效。
这是实例运维职责，不属于本仓库/镜像的构建范围；本仓库只保证补丁被打进 `src/`。

## 6. 主题

本实例不再维护第三方主题。fork 时期积累的 127 个主题样式文件已放弃，不迁入本仓库，
也不存在 `overlay/` 主题目录；装配产物使用上游默认主题。

## 7. 仓库结构

```
patches/                 5 个 format-patch 补丁（基线 v4.7.2；原样保存，勿改行尾）
build.sh                 装配脚本：fetch v4.7.2 + MASTODON_REF 两个 tag -> checkout -> am --3way
verify.sh                验证脚本：热点抽查；传 FORK= 时追加与旧 fork 逐字节比对
tools/make-patches.sh    一次性提取脚本（历史用途，从旧 fork 导出补丁；勿日常运行、勿删）
docs/DRILLS.md           升级演练留档（v4.7.6 正式装配 / v5.0.0-beta.1 干跑）
README.md                本文件
.gitattributes           *.patch -text：防止 Windows CRLF 改写补丁 blob
.gitignore               src/（可重建产物）、PLAN.md（任务记录，非仓库内容）
```

`src/` 随时可删可重建：`rm -rf src && bash build.sh`。它不入库，也不会污染这个仓库的历史。

## 8. 首次接入 GitHub 与 CI

1. 在 GitHub 建一个**空**仓库（不要勾选初始化 README），本地加远端并 push 当前分支：
   `git remote add origin <仓库 URL>` → `git push -u origin feat/patch-repo-bootstrap`。
   （远端由用户本人创建；仓库当前没有 remote，也没有推送过。）
2. Settings → Secrets and variables → Actions → New repository secret，配置
   `DOCKERHUB_USERNAME`、`DOCKERHUB_TOKEN`（Docker Hub Access Token）。
   `GITHUB_TOKEN` 由 Actions 自动提供，workflow 顶层已声明 `packages: write`，无需手动配置。
3. 每次 push / PR 自动跑 `assemble.yml` 门禁：语法检查 + CRLF 防护断言 + 装配 + 热点抽查，
   零 secret 依赖。
4. 打 `v4.7.6` tag 并 push（`git tag v4.7.6 && git push origin v4.7.6`）即触发 `release.yml`：
   构建并推送 `maisuier/mastodon:<tag>` / `:latest`、`maisuier/mastodon-streaming` 同款标签，
   以及 `ghcr.io/<owner>/mastodon(-streaming)` 同款标签。tag push 总会推 ghcr
   （`GITHUB_TOKEN` 恒存在）；Docker Hub 需配置 `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN`，
   未配则跳过该侧并打印提示。
   手动演练：Actions → Run workflow，`push` input 默认 false（只构建不推）；可用 `version`
   input 指定要装配的上游版本（留空用 `build.sh` 默认值），镜像 tag 随之绑定。
5. ghcr 包首次出现后，到 package settings 设可见性并链接仓库（Link repository），否则外部看不到。
