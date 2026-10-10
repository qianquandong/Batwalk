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

## 验证范围

配置已在本地进行 YAML 与脚本检查。首次云端运行前，不能将此配置描述为已经通过
Watch/iPhone 构建。云端模拟器可以补上目前缺失的编译、宿主测试和截图；实际 Watch 的
抬腕手感、HealthKit 后台交付与耗电仍需真机测试。

## 官方参考

- [个人账户免费额度](https://docs.codemagic.io/billing/pricing/)
- [连接 GitHub 仓库](https://docs.codemagic.io/getting-started/adding-apps/)
- [配置文件格式](https://docs.codemagic.io/yaml-basic-configuration/yaml-getting-started/)
- [Xcode 26.3 镜像与模拟器](https://docs.codemagic.io/specs-macos/xcode-26-3/)
- [无签名模拟器构建](https://docs.codemagic.io/yaml-code-signing/ios-simulator-builds/)
