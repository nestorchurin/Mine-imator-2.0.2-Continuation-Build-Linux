# Flathub submission guide

This project is packaged as a community Linux fork of Mine-imator.

## 1) Local pre-check

Install tools:

```bash
sudo apt install flatpak flatpak-builder
flatpak install -y flathub org.flatpak.Builder
```

Build and install locally:

```bash
flatpak-builder --user --install --force-clean build-flatpak flatpak/io.github.nestorchurin.MineImator.yml
flatpak run io.github.nestorchurin.MineImator
```

Run Flathub linter:

```bash
flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest io.github.nestorchurin.MineImator.yml
```

## 2) Create submission PR

1. Fork `flathub/flathub` on GitHub.
2. Clone your fork and checkout `new-pr` base:

```bash
git clone --branch=new-pr git@github.com:<your-github>/flathub.git
cd flathub
git checkout -b add-io-github-nestorchurin-mineimator new-pr
```

3. Copy these files into the Flathub repo root:

- `io.github.nestorchurin.MineImator.yml` (copy from this repository root)
- `flathub.json` (from this repository root)

4. Commit and push:

```bash
git add io.github.nestorchurin.MineImator.yml flathub.json
git commit -m "Add io.github.nestorchurin.MineImator"
git push -u origin add-io-github-nestorchurin-mineimator
```

5. Open PR to `flathub/flathub` branch `new-pr`.

## 3) Notes

- Keep app permissions minimal and explain any broad filesystem/network access in PR discussion.
- Since this is a community package, keep the disclaimer in metainfo description.
- If reviewers request app-id/domain changes, update metainfo ID and manifest app-id together.
