# 三只蝙蝠动画样板

2026-10-10 · C Gentle pixel · Mochi / Sticky / Walker

这次把已确认的三个独立角色做成游戏内样板：**18 段动画、74 张透明帧**。
32 只立绘也已接入角色显示。这里是可继续打磨的第一版；Apple Watch 构建、
实际播放和能耗仍需要在 Mac / 真机上验证。

| 角色 | 五个通用动作 | Lv.4 招牌动作 | 自然触发 |
|---|---|---|---|
| 麻薯 Mochi | 裹翼眨眼、裹翼睡觉、飞、被摸、吃莓果 | 翻身倒挂 `cartwheel-landing` | 上次见面后有新步数 |
| 吸盘 Sticky | 卷叶探头、头朝上睡、带卷叶飞、抱叶被摸、吸盘拿果子 | 搬进新卷叶 `moving-day` | 新的一天首次见面 |
| 步行 Walker | 四肢着地待机、伏地睡、展开前翼飞、低头蹭、低头吃 | 收翼快走，停下喝花蜜 `power-walk` | 上次见面后有新步数 |

## 游戏里的行为

- Home 点击角色：保存抚摸结果后播放 Pet；失败不播成功反应。
- Friendship 点击 Feed：保存扣果子和 EXP 后完整播放 Eat。去掉旧的 420 ms 定时任务，
  避免喂食动画中途被另一条反应覆盖。连续互动以最后一次请求为准，旧任务取消。
- Lv.4 解锁时：先完成当次 Pet / Eat，再展示招牌动作。Friendship 上也有解锁后的
  招牌动作按钮，可随时重播，不扣果子、不加 EXP。
- 低于 Lv.4 的散步归来使用通用 Fly。初次读入历史步数不当作刚完成的散步。
- 白天与黄昏用睡眠帧，夜间用待机帧。通用反应播完回到当前时间的姿态。
- 其余 29 只使用各自已确认的静态立绘。102 个独特动作中目前只制作了上述 3 个；
  Lv.2 / Lv.3 独特动作以及其余 99 个独特动作仍是设计数据。现有友谊挂饰照常解锁。

## 播放与存储

`PilotAnimationCatalog` 明确区分已有帧与完整动作设计。每段动作独立计时，待机循环之间
停 4 秒，睡眠循环之间停 3.6 秒；最快一帧 160 ms。没有 60 Hz 绘制循环。
SwiftUI 的可取消任务在切页、离开视图、后台、息屏变暗、开启“减少动态效果”时停止。
Watch 的分页额外传递选中状态，避免保留在视图树里的相邻页继续播放。
被打断的反应不会在抬腕或恢复播放时重播；减少动态效果时保留静态角色和按钮反馈。

归来记录含步数，因此与游戏存档一样放在受保护、本地且排除设备备份的目录中。
`visits.json` 用 save ID 隔离，不进入 UserDefaults、CloudKit 或手机同步。
它仅避免动画重复，不更改游戏存档格式、奖励、EXP 或版本号；Demo 模式完全在内存里。
写入失败只可能使下次启动再见到一次动画，不影响游戏进度。

生命周期实现参考 Apple 的 [SwiftUI task](https://developer.apple.com/documentation/swiftui/view/task(id:priority:_:))、
[ScenePhase](https://developer.apple.com/documentation/swiftui/scenephase) 和
[Always On 指南](https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state)。

## 素材与复现

- [素材包与 64 px 检查图](../Art/gentle-pixel/pilots-v1/README.md)
- 内置 imagegen：以三只已确认的 v3 立绘为参考，生成 3 张 4×6 帧表；另修正 Mochi
  飞行帧的翅膀间距，并补充 Walker 的 2 帧喝花蜜收尾。完整提示词保存在素材目录。
- 打包仅裁切、加透明安全边距、最近邻缩放，保留原始 alpha；不逐帧拉伸、重画或重新居中。
- 统一 64×64 逻辑画布，资源目录为 128×128 / 2x。最多 74 张解码 RGBA 帧约 4.63 MiB，
  只是像素容量估算，不代表实测进程内存或能耗。
- Shiny 暂时沿用同一新造型做色相变化。专用新配色、逐像素人工清稿、分层源文件仍待完成。

```sh
python3 Art/tools/package_pilot_animations.py
swift test --package-path Packages/BatwalkCore
```

## 如何在 Watch 上检查

Debug 版 Settings → Animation samples：可切三只角色、五个通用动作、Lv.4 开关与招牌动作。
也可以使用启动参数 `-BatwalkDemo pilot-lab`，这个预览不改真实存档。
截图场景新增 `pilot-mochi`、`pilot-sticky`、`pilot-walker`，在 Home 展示真实页面中的 Lv.4 角色。

待 Mac 构建恢复后，检查：连续 Pet / Feed、播放时切页、抬腕/放腕、减少动态效果、
昼夜切换、Lv.3→4 解锁、跨天、退出重开、32 只图鉴、Shiny，以及小屏/大字排版。

## 当前验证

- 本地 Docker / Swift 5.10：**77 个核心测试通过**，包括 7 个新增动画规则测试。
- 74 张帧、32 张静态角色打包检查通过：资源存在、尺寸一致、内容在画布内、每段有不同姿态。
- 修改的 SwiftUI / Watch 文件通过 Swift 语法解析；这不代替 Apple SDK 类型检查或构建。
- 已补充 iOS 宿主测试：32 只身份解析、全部 74 帧打包、归来记录的本地备份排除与 save ID 隔离。
  这些测试尚待 Xcode 执行。
- GitHub 先前的最新 CI 在启动前被账户付款/花费额度限制阻断。Windows 本地没有 Watch
  模拟器；本次不声明真机播放、帧率或能耗已经通过。

## Generated sets for the other 29 species (2026-10-11)

The pilots stay as they are. Every other species now has a generated Gentle-pixel
set — 38 frames each (`gen_bat_…`), 6–8 frames per universal action with the plan in
`GeneratedFramePlan` — so Day / Dusk / Night, petting and feeding are visible on every
companion, not only the three pilots. The first generated pass had no signatures;
the launch update below supersedes that limitation. Details and regeneration:
`Art/gentle-pixel/generated-frames/README.md`.

## Launch personalities (2026-10-11)

首发 20 只的 64 个专属动作现已全部可播放。本文前面的「3 个已做、99 个待做」
及测试结果是样板阶段记录；当前为 66 个可播放、36 个 wave-two 动作仍待制作。
详见 [LAUNCH_PERSONALITIES.md](LAUNCH_PERSONALITIES.md)。
