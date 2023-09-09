# HUD

<!-- **Document :**  [English](./README.md) | [中文](./README_CHI.md) -->

This plugin can display the following data to HUD (KeyHintText)

- Players' own

    - health, stamina, speed, and inventory usage

- Targeted targets

    - Target player's health, stamina, speed, and inventory usage

    - Target zombie's type and health

    - Type of target ammunition

    - Name of the target item

Other:

- Support customer preferences, customers can customize which data HUD displays

- Support for multiple languages, currently supported: English, SChinese, TChinese


![image](./img/Img_230910_011443.png)

note: I have only tested usability on nmrih and am not sure if other games are available.


## Requirements

- [SourceMod 1.11](https://www.sourcemod.net/downloads.php?branch=stable) or higher

- [vscript_proxy](https://github.com/dysphie/nmrih-vscript-proxy/blob/main/vscript_proxy.inc)

## Installation
- Grab the latest ZIP from releases
- Extract the contents into `addons/sourcemod`
- Load the plugin `sm plugins load hud`
