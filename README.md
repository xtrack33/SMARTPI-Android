# SmartPi Android 10

Android 10 (Q) pour **SmartPi One** basé sur Allwinner H3.

## Hardware

| Composant | Spécification |
|-----------|---------------|
| **SoC** | Allwinner H3 (sun8iw7p1) |
| **CPU** | ARM Cortex-A7 Quad-core @ 1.008 GHz |
| **RAM** | 1GB DDR3 |
| **GPU** | Mali400 MP2 (driver Lima open-source) |
| **Architecture** | ARMv7 (32-bit) |

## Caractéristiques

- **GPU Open-Source** : Driver Lima/Mesa (pas de blobs propriétaires Mali)
- **Kernel 5.4** : Linux mainline avec support sun8i
- **Architecture Treble** : Séparation vendor/system

## Structure du projet

```
SMARTPI-ANDROID/
├── .github/workflows/       # CI/CD GitHub Actions
├── device/smartpi/smartpi1/ # Device tree
│   ├── BoardConfig.mk       # Configuration carte
│   ├── device.mk            # Packages et propriétés
│   ├── fstab.smartpi1       # Partitions
│   └── init.smartpi1.rc     # Scripts init
├── vendor/smartpi/smartpi1/ # Configs vendor
├── local_manifests/         # Manifest pour repo sync
├── tools/                   # Scripts d'extraction
├── scripts/                 # Scripts de build
└── extracted_full/          # Données extraites image fabricant
```

## Build rapide (Ubuntu 20.04/22.04)

### Prérequis

```bash
# Dépendances
sudo apt install -y git-core gnupg flex bison build-essential zip curl \
    zlib1g-dev libc6-dev-i386 libncurses5 x11proto-core-dev libx11-dev \
    lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig \
    python3 python-is-python3 bc cpio gettext libssl-dev rsync wget \
    openjdk-11-jdk ccache

# Installer repo
mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
export PATH=~/bin:$PATH
```

**Ressources requises:**
- RAM: 16GB minimum (32GB recommandé)
- Disque: 300GB libre
- Temps: 3-6 heures

### Build

```bash
# 1. Cloner ce repo
git clone https://github.com/nicMusic/SMARTPI-ANDROID.git
cd SMARTPI-ANDROID

# 2. Lancer le build complet
./scripts/build_local.sh userdebug
```

### Build étape par étape

```bash
./scripts/build_local.sh userdebug deps    # Installer dépendances
./scripts/build_local.sh userdebug sync    # Sync sources AOSP (~100GB)
./scripts/build_local.sh userdebug build   # Compiler Android
./scripts/build_local.sh userdebug package # Créer l'image finale
```

## Flash sur SmartPi One

### Méthode 1: dd (Linux/Mac)

```bash
# ATTENTION: Vérifier le bon device!
lsblk  # ou diskutil list sur Mac

sudo dd if=smartpi1-android10.img of=/dev/sdX bs=4M status=progress
sync
```

### Méthode 2: PhoenixCard (Windows)

Utiliser l'outil dans `dophin/PhoenuxCard4.2.8/`

## Configuration hardware extraite

| Paramètre | Valeur |
|-----------|--------|
| UART Debug | PA04/PA05 @ 115200 baud |
| SD Card | PF00-PF05 (4-bit) |
| eMMC | PC05-PC16 (8-bit) |
| LED Power | PL10 |
| LED Status | PA15 |
| GPU Clock | 576 MHz |
| DDR Clock | 672 MHz |

## Roadmap

- [x] Extraction image fabricant Android 7.0
- [x] Récupération config hardware (.fex)
- [x] Device tree SmartPi One
- [x] Configuration Lima/Mesa (GPU open-source)
- [x] Scripts de build
- [ ] Premier boot Android 10
- [ ] Support WiFi (RTL8189/XR829)
- [ ] Support Bluetooth
- [ ] Support HDMI audio
- [ ] Décodage vidéo CedarX

## Références

- [linux-sunxi](https://linux-sunxi.org/) - Documentation Allwinner
- [Mesa Lima](https://docs.mesa3d.org/drivers/lima.html) - Driver GPU open-source
- [Allwinner H3](https://linux-sunxi.org/H3) - Datasheet

## Licence

- Code AOSP: Apache 2.0
- Device tree: Apache 2.0
- Scripts: MIT

---

Basé sur l'image fabricant **dolphin-p1** (Android 7.0, build janvier 2024)
