# EmacsMacPluginModule

`EmacsMacPluginModule` 是一个用于在 Emacs 中实现动态光标等效果的 macOS 插件， 仅适用于mac。该插件通过 `module-load` 加载由 Swift 编写的 `.dylib` 实现 Emacs 与 Swift 之间的互相调用，用的是 [SavchenkoValeriy/emacs-swift-module](https://github.com/SavchenkoValeriy/emacs-swift-module) 的实现方式，并借鉴了 [xenodium/EmacsMacOSModule](https://github.com/xenodium/EmacsMacOSModule) 如何运用这些技术。光标的动画效果参考了 [manateelazycat/holo-layer](https://github.com/manateelazycat/holo-layer.git) 项目的实现。

## 安装

### 先决条件

- Emacs
- Swift 和 Swift Package Manager
- macOS

### 步骤

1. 克隆仓库到您的 Emacs `site-lisp` 目录：

   ```sh
   git clone https://github.com/happyo/EmacsMacPluginModule.git ~/.emacs.d/site-lisp/EmacsMacPluginModule
   ```

2. 在 Emacs 配置文件（`~/.emacs.d/init.el` 或 `~/.emacs`）中添加以下代码：

   ```elisp
   (add-to-list 'load-path "~/.emacs.d/site-lisp/EmacsMacPluginModule")

   (require 'mac-plugin)

   ;; 如果下载的仓库目录不是上面的，可以自己指定macos-project-root为仓库实际的目录
   (mac-plugin-load-release)
   (atmosphere-enable)
   (mac-plugin-set-cursor-color "#fcc800")
   (mac-plugin-set-shadow-opacity 1)
   ```

3. emacs中手动调用M-x， 执行build dylib的命令， 只需要 build 一次就够了：

   ```elisp
   (macos-module-build-release)
   ```

   或者自己cd到仓库的目录，手动执行：

   ```sh
   swift build -c release
   ```


## 使用

### 加载模块

在 Emacs 中加载模块：

```elisp
(mac-plugin-load-release)
```

### 启用光标动画效果

启用光标动画效果：

```elisp
(atmosphere-enable)
```

### 设置光标颜色

设置光标颜色（例如，设置为 `#fcc800`）：

```elisp
(mac-plugin-set-cursor-color "#fcc800")
```

### 设置阴影不透明度

设置阴影不透明度（例如，设置为 `1`）：

```elisp
(mac-plugin-set-shadow-opacity 1)
```

## 贡献

欢迎提交问题和请求，也欢迎发送 Pull Request 来贡献您的代码！

## 参考项目

- [SavchenkoValeriy/emacs-swift-module](https://github.com/SavchenkoValeriy/emacs-swift-module)
- [xenodium/EmacsMacOSModule](https://github.com/xenodium/EmacsMacOSModule)
- [manateelazycat/holo-layer](https://github.com/manateelazycat/holo-layer.git)

## 许可证

本项目采用 GPL 许可证，详情请参阅 LICENSE 文件。

## 未来计划

我们计划添加更多 macOS 插件，以进一步增强 Emacs 的功能。如果您有任何建议或希望看到的新功能，请随时提出。

这样，你的 README 文件中不仅包含了安装和使用说明，还参考了相关的项目，并表达了将来增加更多 macOS 插件的计划。你可以将这个内容直接复制粘贴到你的 GitHub 仓库的 `README.md` 文件中。
