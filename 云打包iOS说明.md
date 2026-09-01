# 云端打包 iOS（.ipa）操作说明

> 适用：本机为 Windows、代码托管在 Gitee，但需要产出 iOS 安装包（.ipa）。
> 方案：**Codemagic** —— 云端 macOS 构建机，免费套餐每月 500 分钟，支持 SSH 直连 Gitee 仓库，无需把代码迁移到 GitHub。

---

## 一、前置条件（缺一不可）

| 项 | 说明 | 需要花钱？ |
|---|---|---|
| Apple Developer 账号 | 在 https://developer.apple.com 注册，加入 Apple Developer Program | **¥688/年**（个人） |
| 唯一的 Bundle ID | 在 Apple 开发者后台注册 App ID（如 `com.yourname.chatapp`） | 含在年费内 |
| App Store Connect API Key | 用于 Codemagic 自动生成证书/描述文件、上传 TestFlight | 无额外费用 |
| 分发证书 + 描述文件 | 用于给 IPA 签名（不签名只能出包，装不到真机） | 含在年费内 |

> ⚠️ **先跑未签名管线不需要上面任何苹果账号**，可以先用它验证云端构建是否跑通。

---

## 二、第一步：修改 Bundle ID（建议先做）

当前工程的 Bundle ID 还是 Flutter 默认值 `com.example.chatApp`，**无法用于正式分发/上架**。

1. 在 Apple 开发者后台 → Certificates, Identifiers & Profiles → Identifiers 注册一个新 App ID，Bundle ID 填你想要的唯一值，例如 `com.yourname.chatapp`。
2. 把工程里的 Bundle ID 改成同一个值：编辑 `ios/Runner.xcodeproj/project.pbxproj` 中所有
   `PRODUCT_BUNDLE_IDENTIFIER = com.example.chatApp;` → `PRODUCT_BUNDLE_IDENTIFIER = com.yourname.chatapp;`
3. 同步修改 `codemagic.yaml` 里 `ios-ipa-signed` 工作流的 `bundle_identifier`。

---

## 三、第二步：把配置推送到 Gitee

在 `flutter_app` 目录执行（git 仓库根就是这里）：

```bash
git add codemagic.yaml 云打包iOS说明.md
git commit -m "add codemagic ios build config"
git push origin main
```

---

## 四、第三步：把 Gitee 仓库接入 Codemagic

1. 打开 https://codemagic.io ，注册账号（可用 Google/Apple/GitHub 登录）。
2. 生成一对 SSH 密钥（Windows PowerShell）：
   ```powershell
   ssh-keygen -t ed25519 -C "codemagic" -f "$env:USERPROFILE\.ssh\codemagic"
   ```
   生成的公钥是 `codemagic.pub`，私钥是 `codemagic`。
3. 把**公钥**内容添加到 Gitee：仓库 → 管理 → 部署公钥（Deploy Keys）→ 添加公钥。
4. 回到 Codemagic → **Add application** → 仓库来源选 **Other**（Gitee 没有原生按钮）：
   - Repository URL 填 Gitee 仓库的 SSH 地址，如 `git@gitee.com:premeditationn/lengtingyu.git`
   - 上传**私钥**文件
   - 分支选 `main`
5. 保存后，Codemagic 即可拉取你的代码。

---

## 五、第四步：先跑“未签名 IPA”验证管线（无需苹果账号）

1. Codemagic 应用页面 → **Start new build**。
2. Workflow 选择 **iOS 未签名 IPA**（`ios-ipa-unsigned`），开始构建。
3. 等待约 10~20 分钟（首次需拉 SDK/依赖较久）。
4. 构建成功后，在 **Artifacts** 里下载 `build/ios/ipa/*.ipa`。
   - 这个包**没有签名**，只能用来确认云端构建正常，不能安装到 iPhone。
5. 若构建失败：点击失败步骤看日志，常见原因见下方“常见问题”。

> 到这里说明云端打包管线已通。下面才是“能装到手机/上架”的签名步骤。

---

## 六、第五步：配置签名，产出可安装的 IPA

1. **创建 App Store Connect API Key**：
   - 登录 https://appstoreconnect.apple.com → 用户与访问 → 集成 → App Store Connect API → 生成密钥。
   - 下载 `.p8` 文件（只能下载一次），记下 **Issuer ID** 和 **Key ID**。
2. **上传到 Codemagic**：Team integrations → Developer Portal → Manage keys → 填入 `.p8`、Issuer ID、Key ID，起一个名字（如 `codemagic_appstore_key`）。
3. **让 Codemagic 自动生成证书和描述文件**：有了 API Key 后，Codemagic 可自动创建/获取签名证书和描述文件（也可手动上传 `.p12` 证书和 `.mobileprovision` 描述文件）。
4. **更新 `codemagic.yaml`**：
   - `ios-ipa-signed` 工作流的 `integrations.app_store_connect` 改成你保存的 key 名；
   - `bundle_identifier` 改成你注册的 Bundle ID。
5. 提交推送，然后 **Start new build** → 选 **iOS 签名 IPA**（`ios-ipa-signed`）。
6. 成功后 Artifacts 里的 `.ipa` 即为**签名包**：
   - 可用 Apple Configurator / 爱思助手安装到你的 iPhone（App Store 分发类型的包走 TestFlight 更合适）；
   - 或在 Codemagic 里启用 `publishing.app_store_connect` 自动上传 **TestFlight**（先创建内部测试员分组）。

---

## 七、常见问题

| 现象 | 原因 / 解决 |
|---|---|
| 构建报 `No profiles for 'com.xxx'` | Bundle ID 与描述文件不匹配，检查注册的 App ID 和 `bundle_identifier` 是否一致 |
| `pod install` 失败 | 网络或版本问题，可在环境里固定 `cocoapods` 版本，或重跑一次 |
| 构建超时 | `max_build_duration` 调大（当前 120 分钟） |
| 免费时长用完 | 免费 500 分钟/月；未签名调试别频繁触发；可勾选缓存加速（Codemagic 会缓存 pub/pods） |
| SSH 连接仓库失败 | 检查 Gitee 部署公钥是否添加、私钥是否正确上传 |

---

## 八、其他备选方案（简要）

- **Gitee Go**（留在 Gitee 生态）：语法与 GitHub Actions 兼容，仓库 200 分钟永久免费 + 每月赠送时长。但托管 macOS 构建机能力有限，iOS 打包支持不稳定，若选择需自行验证。
- **GitHub Actions**：最成熟，需把仓库镜像到 GitHub（当前代码在 Gitee，需迁移）。免费额度 macOS 按 10 倍计费。
- 本仓库内已有 `build-apk.yml` 是 GitHub Actions 的安卓打包配置，但它目前在 git 仓库（`flutter_app`）**之外**，要生效需移入 `flutter_app/.github/workflows/`。

---

## 九、待办清单（你可执行的部分）

- [ ] 注册 Apple Developer Program 并创建 App ID（Bundle ID）
- [ ] 修改工程 Bundle ID 并同步 `codemagic.yaml`
- [ ] 生成 SSH 密钥，Gitee 加公钥，Codemagic 加私钥
- [ ] 推代码 → 先跑未签名构建验证
- [ ] 创建 App Store Connect API Key 并上传 Codemagic
- [ ] 跑签名构建，下载/上传 IPA
