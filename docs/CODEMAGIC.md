# Codemagic：独立的 Mac 构建

GitHub 继续保存代码和 PR，Codemagic 直接拉取仓库并在云端 Mac 编译，不依赖 GitHub Actions。
当前配置只做模拟器验证，不需要 Apple Developer 证书，也不会提交 TestFlight 或 App Store。

## 第一次连接

1. 在 [Codemagic](https://codemagic.io/signup/) 注册或登录**个人账户**。
   官方当前提供每月 500 分钟 macOS M2 免费额度；Team 不含此免费额度。
2. Add application → GitHub，安装/授权 Codemagic CI/CD GitHub App。
   选择 **Only select repositories → qianquandong/Batwalk**。仓库仍保持私有。
3. 添加 Batwalk，项目类型选择 iOS / 使用 `codemagic.yaml` 的原生项目。
4. 配置扫描分支选择 **`improve/watch-release-readiness`**；配置尚在 PR #1，`main` 暂时没有。
5. Start new build → 同一分支 → **Batwalk · Watch + iPhone checks** (`batwalk-verify`)。

GitHub 登录、两步验证以及首次账户连接需要由账户持有人完成。不要把登录密码或访问令牌写入仓库。

## 两条工作流

| 工作流 | 内容 | 超时 |
|---|---|---|
| `batwalk-verify` | 核心规则测试、Watch 编译、iPhone 宿主测试、三只样板与友谊页截图、启用可选能力的无签名编译 | 45 分钟 |
| `batwalk-watch-screenshots` | Watch 编译和全部 Watch 演示场景截图 | 30 分钟 |

两条均为**手动运行**，默认不随每次提交重复消耗额度。机器固定为免费额度适用的 M2，
Xcode 固定为 26.3，与项目上一次通过的 Apple 构建工具链一致。
Codemagic 官方列出了该镜像包含的 watchOS 26.2 和 iOS 模拟器。

运行后在 Build → Artifacts 下载 `.png`、测试 `.xcresult` 和日志。
`batwalk-verify` 的成功必须覆盖所有步骤；截图本身不代表宿主测试或能力构建通过。
日志中 GitHub 格式的 `::error::` 文本仍然可读，完整 Xcode 日志会作为文件保留。

环境准备尊重 Codemagic 已选中的 Xcode，不使用只匹配 GitHub 镜像路径的选择脚本。
模拟器脚本兼容 `CM_ENV`、`GITHUB_ENV`；本地使用可以设置 `BATWALK_ENV_FILE`。
同一时刻只保留一个启动中的模拟器，以减少 M2 实例内存压力。

## GitHub 额度不足时自动接管

Codemagic 应用：[Batwalk](https://codemagic.io/app/6aca84b1218c730e102b08bf/settings)。
当前对话中的 Codex 定时检查每 30 分钟查看 `main` 和本仓库未合并 PR 的最新提交。
`scripts/github-ci-fallback.py` 通过现有 GitHub CLI 登录读取 CI，不复制或保存登录令牌。
只有失败任务尚未执行、且 GitHub 明确报告付款失败或分钟数/花费上限时，才列为接管候选。
编译错误、测试失败、取消、未知故障都不会触发接管。

检查器会核对 Codemagic 构建历史和本地记录，针对同一提交的 `batwalk-verify` 只启动一次。
启动前再次核对分支最新提交；已被新提交替代的旧版本会跳过。
只使用个人账户 M2 免费额度，不会开启付费、签名发布或更改 GitHub 的检查结果。
截图专用工作流保留手动运行。

这个接管检查运行在本地 Codex，**电脑需开机、联网，Codex 需保持运行**；
GitHub CLI 与 Codemagic 浏览器登录也需有效。已启动的 Mac 构建由 Codemagic 云端继续执行。
两项 Codemagic 工作流自身仍无 push 触发器，避免与正常 GitHub CI 重复构建。

## 验证范围

配置已通过官方 YAML schema 与脚本检查，额度故障识别通过 6 项测试，并已针对真实
GitHub 付款阻塞识别出接管候选。首次云端构建已经启动；成功前不能将此配置描述为已经通过
Watch/iPhone 构建。云端模拟器可以补上目前缺失的编译、宿主测试和截图；实际 Watch 的
抬腕手感、HealthKit 后台交付与耗电仍需真机测试。

## 官方参考

- [个人账户免费额度](https://docs.codemagic.io/billing/pricing/)
- [连接 GitHub 仓库](https://docs.codemagic.io/getting-started/adding-apps/)
- [配置文件格式](https://docs.codemagic.io/yaml-basic-configuration/yaml-getting-started/)
- [Xcode 26.3 镜像与模拟器](https://docs.codemagic.io/specs-macos/xcode-26-3/)
- [无签名模拟器构建](https://docs.codemagic.io/yaml-code-signing/ios-simulator-builds/)
- [Codex 本地定时任务的运行条件](https://learn.chatgpt.com/docs/automations?surface=app)
