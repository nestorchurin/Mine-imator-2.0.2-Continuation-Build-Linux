# Mine-imator

<p align="center">
  <img src="https://www.mineimatorforums.com/uploads/monthly_2021_08/image.png.4699187f1f02be8222a5bf5100c1738f.png" width=800/>
  <br/>
  <br/>
  <img src="https://www.mineimatorforums.com/uploads/monthly_2023_03/336815532_programview.png.9212aa1f6d1bed63411408aa5e905ce0.png" width=800/>
</p>

Mine-imator is a 3D movie maker based on the sandbox game Minecraft, with over 8 million downloads since its launch in 2012. Version 2.0, the 10th anniversary update brings numerous additions including a new UI, new renderer, animation features, multiplatform support and 3D world importer.

Website and download: https://www.mineimator.com

The software is written using GameMaker Language and converted to a separate C++ environment using a custom built GML parser (CppGen). The final executable is built for Windows, Mac OS and Linux using the Qt framework, DirectX/OpenGL rendering and various other libraries.

## Linux fork note

This repository is a community-maintained Linux fork/packaging effort for Mine-imator.

- Upstream official website: https://www.mineimator.com
- Linux fork maintainer: Nestor Churin
- Maintainer page: https://nestor-churin.com

## Flatpak build (Linux)

This repository now includes a Flatpak manifest for Linux packaging:

- `flatpak/io.github.nestorchurin.MineImator.yml`

### Prerequisites

Install required tools:

```bash
sudo apt install flatpak flatpak-builder
```

Ensure Flathub remote exists:

```bash
flatpak remotes --show-details
```

### Build and install (user scope)

```bash
flatpak-builder --user --install --force-clean build-flatpak flatpak/io.github.nestorchurin.MineImator.yml
```

### Run

```bash
flatpak run io.github.nestorchurin.MineImator
```

### Build a distributable bundle

```bash
flatpak build-bundle ~/.local/share/flatpak/repo MineImator.flatpak io.github.nestorchurin.MineImator
```

For Flathub submission steps, see `FLATHUB_SUBMISSION.md`.
