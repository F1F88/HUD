# HUD

**Document :**  [English](./readme.md) | [中文](./readme-chi.md)

This plugin can display the following data to HUD (KeyHintText)

- Players' own

    - health, stamina, speed, ammo, inventory usage, status (bleeding, infected, vaccinated, blindness, partial blindness)

- Targeted targets

    - Target player's health, stamina, speed, ammo, inventory usage, status (bleeding, infected, vaccinated, blindness, partial blindness)

    - Target zombie's type and health

    - Target ammo box name

    - Target item name

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
