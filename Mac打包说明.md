# Mac 云端打包 IPA 快速上手（租 Mac / 云 Mac 通用）

> 适用：你在 Windows 上开发，但需要用 Mac 产出 iOS 安装包（.ipa）。
> 核心：**同一份 Flutter 源码**在 Mac + Xcode 上编译，直接导出 IPA，无需"转换"。

---

## 一、你需要准备

1. **一台能用的 Mac**（租的云 Mac / 朋友的真 Mac 都行）
   - 云 Mac 参考：MacinCloud（约 ¥7-25/小时）、国内云 Mac 服务（几十元/次）
2. **Xcode**（在 App Store 下载，很大，提前装好）
3. **Flutter SDK**（`https://docs.flutter.dev/get-started/install/macos`）
4. **源码**：把 `flutter_app` 目录拷到 Mac 上，或从你的 Gitee 仓库 `git clone` 下来
5. **签名证书**（要装真机才需要）：`.p12` 证书 + `.mobileprovision` 描述文件

---

## 二、先打"未签名 IPA"验证（不需要证书，最快）

把 `flutter_app` 放到 Mac 上，终端进入该目录：

```bash
chmod +x build_ipa.sh
./build_ipa.sh
```

约 10-20 分钟后，产物在 `build/ios/ipa/Runner.ipa`，拷走即可。
这个包没有签名，只能确认构建流程没问题。

---

## 三、再打"签名 IPA"（能装 iPhone / 传 TestFlight）

1. 双击打开 `ios/Runner.xcworkspace`（Xcode）
2. 双击左侧 `Runner` 工程 → **Signing & Capabilities**
   - 勾选 **Automatically manage signing**
   - Team 选你的 Apple 开发者账号
   - Bundle Identifier 填 `com.example.chatApp`（或你在 Apple 后台注册的 ID）
   - 确认报错为 0（若提示没有描述文件，Xcode 会自动创建，需要登录你的 Apple 账号）
3. 若用**手动证书**：把你已有的 `.p12` 导入钥匙串，`.mobileprovision` 拖到 Xcode 的描述文件列表
4. 终端执行：

```bash
./build_ipa.sh --signed
```

产物 `build/ios/ipa/Runner.ipa` 即为**签名包**：
- 用 Apple Configurator / 爱思助手可装到 iPhone
- 或上传 App Store Connect 走 TestFlight

---

## 四、常见问题

| 现象 | 解决 |
|---|---|
| `pod install` 失败 | 网络问题，重试；或先执行 `sudo gem install cocoapods` |
| Xcode 报证书/Team 错误 | 确认已登录 Apple 开发者账号、Bundle ID 与描述文件一致 |
| 构建很慢 | 首次需下载引擎和依赖，属正常；之后会走缓存 |
| 没有 Apple 开发者账号 | 打不了签名包（需 ¥688/年）；未签名验证不受影响 |

---

## 五、和 Codemagic 的关系（可二选一）

- **租 Mac**：手动但可控，1-2 小时搞定，适合想自己操作 Xcode 的情况
- **Codemagic**：免费 500 分钟/月，网页点一下自动出包，适合省事
- 两者产出的 IPA 完全相同，**不用重复打包**
