# HUD

**文档 :**  [English](./README.md) | [中文](./README_CHI.md)

此插件可以将以下数据显示到HUD（KeyHintText）

- 玩家自己的数据

    - 健康、耐力、速度和库存使用

- 瞄准的目标

    - 目标玩家的 健康、体力、速度、库存占用

    - 目标丧尸的 类型和生命值

    - 目标弹药的 类型

    - 目标道具的 名称


**其他功能**

- 支持客户偏好，客户可以自定义 HUD 显示的数据

- 支持多种语言，目前支持：英语、简体中文、繁体中文


![image](./img/Img_230910_011443.png)

注意：仅 NMRIH 可用，其他游戏需要自己改 offset


## 依赖

- [SourceMod 1.12](https://www.sourcemod.net/downloads.php?branch=stable) or higher

- [vscript_proxy](https://github.com/dysphie/nmrih-vscript-proxy/blob/main/vscript_proxy.inc)

## 安装
- Grab the latest ZIP from releases
- Extract the contents into `addons/sourcemod`
- Load the plugin `sm plugins load hud`
