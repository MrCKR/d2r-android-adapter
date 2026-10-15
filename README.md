# D2R Android Adapter

Diablo II: Resurrected Switch 版本在 Android 上的游戏适配器，运行于 [`switch-android-runtime`](https://github.com/MrCKR/switch-android-runtime) 之上。

> 当前状态：**方案验证/适配分析阶段，尚未提供 APK 或可运行构建**。

## 目标

将上游 [`jhaizhou-ops/d2r-mobile`](https://github.com/jhaizhou-ops/d2r-mobile) 中针对 Apple 平台的 D2R 兼容层思路，拆分为：

```text
通用 Android Runtime
    +
D2R-specific Adapter
    =
Android 上运行 D2R Switch 版的实验性移植
```

最终验证目标：在开发者的真实 Android 手机上，使用用户自己合法导出的 Switch 游戏文件，完成：

1. 启动 App；
2. 识别正确的游戏版本；
3. 加载 ARM64 游戏模块；
4. 显示主菜单；
5. 进入离线游戏；
6. 完成触屏/手柄输入、音频和存档；
7. 记录稳定性、性能、发热和兼容性。

## 这个仓库负责什么

- D2R Switch 版本识别和版本指纹；
- D2R 模块加载配置；
- D2R 专用补丁和重定位描述；
- D2R 使用到的 NVN/系统服务扩展；
- D2R Shader、纹理和资源的构建描述；
- D2R 输入、触屏和分辨率配置；
- D2R 存档和离线启动配置；
- D2R Android 兼容性测试与性能基线。

## 这个仓库不负责什么

以下内容必须留在 Runtime 仓库：

- Android Activity、Surface 和 Vulkan 初始化；
- 通用 ARM64 loader；
- 通用线程、内存、文件系统和服务 HLE；
- 通用 NVN 抽象和 Vulkan 后端；
- 通用输入、音频和诊断框架。

如果某段代码不需要知道“这是 D2R”，就不应该放在本仓库。

## 阶段计划

### A. 上游分析和版本固定

- [ ] 固定上游 D2R Mobile 的参考提交；
- [ ] 记录目标 Switch 游戏版本；
- [ ] 列出 Apple/Metal 实现与 Android/Vulkan 实现的对应关系；
- [ ] 建立不含游戏内容的版本指纹和元数据格式；
- [ ] 明确所有必须重新实现的 iOS/macOS 专用部分。

### B. D2R Adapter SDK 接入

- [ ] 实现 Adapter manifest；
- [ ] 实现游戏版本检测；
- [ ] 实现启动配置和资源挂载；
- [ ] 接入模块 patch/relocation 描述；
- [ ] 接入 D2R 的服务扩展表；
- [ ] 接入 D2R 图形 profile 和 Shader 清单。

### C. 最小启动闭环

- [ ] 启动加载器；
- [ ] 资源目录选择和校验；
- [ ] D2R 模块映射；
- [ ] 主菜单画面；
- [ ] 日志中记录首个未实现调用；
- [ ] 将崩溃位置、模块、线程和服务调用导出。

### D. 游戏内闭环

- [ ] 角色创建；
- [ ] 离线进入营地；
- [ ] 触屏移动和技能输入；
- [ ] 音频；
- [ ] 读写存档；
- [ ] 前后台切换；
- [ ] 30/60 FPS 和功耗记录。

### E. 设备适配

第一目标设备是当前开发手机：vivo V2256A / Qualcomm `taro` / Android 16 / arm64-v8a。需要实际测量：

- Vulkan API 版本；
- GPU 名称和驱动版本；
- BC/ASTC/ETC2 支持；
- 可用显存和统一内存；
- 外部存储权限与 SAF 行为；
- 长时间运行时温控降频。

## 预期难点

- Apple 的 Metal 后端不能直接复用到 Android；
- Android 必须新增 Vulkan 后端；
- Switch Shader 需要适合 Vulkan 的 SPIR-V/pipeline 流程；
- D2R 的地址和补丁只对特定版本有效；
- Android GPU/驱动差异比 Apple 设备大；
- iOS 的代码嵌入和 Android NDK 的加载限制不同；
- 进入主菜单之前通常就会触发大量文件、图形和系统服务调用。

## 数据和许可证边界

本仓库不包含也不接受：

- D2R 游戏程序或资源；
- NSP/XCI、prod.keys；
- 游戏 Shader、音频、贴图、文本和存档；
- 任何账号、Token、签名证书或私钥。

只提交工具、接口、版本指纹、补丁描述和由合法用户在本地生成的构建产物规则。请同时遵守上游项目许可证以及游戏发行商的相关条款。

## 相关项目

- [通用 Switch Android Runtime](https://github.com/MrCKR/switch-android-runtime)
- [上游 d2r-mobile](https://github.com/jhaizhou-ops/d2r-mobile)
