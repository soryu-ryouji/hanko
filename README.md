# 审批单盖章接力

基于 Godot 4.7 制作的中文竖屏小游戏。玩法参考[《稟議書ハンコリレー》](https://yorimichi-games.com/hanko/)，界面、职位、姓名和提示均已中文化。

## 运行

1. 使用 Godot 4.7 或更新版本打开 `project.godot`。
2. 等待字体和纹理导入，按 **F6/F5** 或点击右上角运行按钮。
3. 主场景为 `scenes/main.tscn`，默认窗口为 540×960。

也可在项目目录运行：

```powershell
& 'D:\Developments\Godot\Godot_v4.7.2-stable_win64_console.exe' --path .
```

## 操作

| 操作 | 鼠标 / 触摸 | 键盘 |
|---|---|---|
| 开始 | 点击开始按钮 | 空格 / Enter |
| 抬起印章 | 按住画面 | 按住空格 / Enter |
| 盖章 | 松开 | 松开空格 / Enter |
| 重新开始 | 点击“再来一单” | 结算后按空格 / Enter |
| 帮助 | 右上角 `?` | F1 |
| 静音 | 右上角“声 / 静” | M |

## 规则

- 从新员工到董事长共 21 棒，从审批单右下角开始，每排从右向左，再向上移动。
- 按住时，印章从 0° 向垂直方向转动；松开时按当前角度盖章，角度精确到 0.1°。
- 第一位可以盖 0°。之后必须严格大于上一位，相同或更小都会退回。
- 90.0° 仍然有效，超过 90° 则失败。持续按住会在 100° 自动盖章并失败。
- 职位越高，转动速度越快。应尽量只增加很小的角度，为后续审批者留下空间。
- 最佳批准人数、剩余角度、审批单编号和静音设置保存在 Godot 的 `user://save.cfg`。

## 验证

```powershell
pwsh -File tools/test.ps1
```

测试包括 50 项规则断言和 11 项输入集成断言，覆盖临界角度、超角、提前按住、通关、重开、鼠标、触摸、键盘、帮助和静音。

重新生成真实渲染截图：

```powershell
& 'D:\Developments\Godot\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tools/capture.gd
```

截图输出到 `build/`。该脚本使用独立测试存档，完成后自动清理。

## 资源

- 桌面与纸张纹理由本机 ComfyUI 生成，模型为 `flux1-dev-fp8.safetensors`。
  - `wood_desk.png`：1024×1024，种子 `731942608`。
  - `paper_fiber.png`：1024×1024，种子 `194827351`。
- 中文字体为 Noto Sans SC Regular / Bold，采用 SIL Open Font License，许可证位于 `assets/fonts/OFL.txt`。
- 音效由 `scripts/sound.gd` 在启动时合成，无外部音频依赖。

## 说明

当前交付为完整 Godot 工程。本机未安装 Godot 导出模板，因此未生成独立 EXE；如需导出，请先在 Godot 编辑器中选择“编辑器 → 管理导出模板 → 下载并安装”。
