# SmartPi Android - Contexte du projet

## Objectif

Compiler une image Android moderne pour le **SmartPi One** (Allwinner H3, 1GB RAM).

## Hardware cible

- **SoC** : Allwinner H3 (sun8iw7p1)
- **CPU** : ARM Cortex-A7 Quad-core 1.2GHz
- **RAM** : 1GB DDR3
- **GPU** : Mali400 MP2
- **Architecture** : ARMv7 (32-bit)

## Image existante du fabricant

Le fabricant a fourni une image Android :
- **Nom** : `sun8iw7p1_android_dolphin-p1_uart0`
- **Outil de flash** : PhoenixCard 4.2.8
- **Format** : Image Allwinner (pas dd standard)

## Recherches effectuées

### Projets GitHub explorés

| Projet | Lien | Status |
|--------|------|--------|
| **GloDroid** | https://github.com/GloDroid/glodroid_manifest | Actif, Android 13-14, mais H3 plus supporté dans v2.0 |
| **H3Droid** | https://github.com/kotc/h3droid | Inactif (2018), pas de sources (images seulement) |
| **android2orangepi** | https://github.com/android2orangepi-dev/android_allwinner_manifest | Migré vers GloDroid |
| **allwinner-android** | https://github.com/allwinner-android | 103 repos de composants Android |
| **orangepi_h3_linux** | https://github.com/orangepi-xunlong/orangepi_h3_linux | Kernel Linux, contient config dolphin-p1 |
| **lichee** | https://github.com/joek85/lichee | U-Boot + Kernel pour Android Allwinner |

### Config dolphin-p1 trouvée

La configuration `dolphin-p1` (correspondant à l'image du fabricant) existe dans :
```
https://github.com/orangepi-xunlong/orangepi_h3_linux/tree/master/OrangePi-Kernel/chips/sun8iw7p1/configs/dolphin-p1
```

Fichiers disponibles :
- `bootlogo.bmp`
- `orange_pi2.fex`
- `sys_config.fex`
- `sys_partition.fex`
- `test_config.fex`

## Options Android pour H3

| Version Android | Projet | Difficulté | Notes |
|-----------------|--------|------------|-------|
| Android 4.4 (KitKat) | BSP Allwinner | Facile | Ancien, images disponibles |
| Android 7.1 (Nougat) | BSP Allwinner | Moyen | Dernière version officielle H3 |
| Android 10+ | GloDroid 1.0 | Difficile | Nécessite portage |
| Android 13-14 | GloDroid 2.0 | Très difficile | H3 non supporté |

## Contraintes de compilation

### Ressources nécessaires

- **Espace disque** : ~300GB pour les sources AOSP
- **RAM** : 32GB+ recommandé (minimum 16GB avec swap)
- **Temps de build** : 3-6h sur machine puissante
- **OS** : Linux (Ubuntu 20.04/22.04 recommandé)

### GitHub Actions

Les runners gratuits sont insuffisants :
- 7GB RAM, 14GB stockage, limite 6h

Options payantes :
| Runner | RAM | Stockage | Prix |
|--------|-----|----------|------|
| 16-core | 64 GB | 300 GB | ~$0.032/min |
| 64-core | 256 GB | 2 TB | ~$0.128/min |

**Coût estimé** : ~$6-8 par build Android

### Alternatives

1. **Self-hosted runner** - PC Linux local
2. **Oracle Cloud** - Tier gratuit (4 cores ARM, 24GB RAM)
3. **Hetzner** - Serveur dédié ~30€/mois

## Compilation sur Mac

- **AOSP officiel** : Support Mac abandonné depuis Android 12
- **Mac Intel** : Possible pour Android 10 et avant
- **Mac Apple Silicon** : Difficile (Rosetta + hacks)
- **Recommandation** : Utiliser VM Linux ou serveur distant

## Prochaines étapes suggérées

1. **Fork GloDroid 1.0** (branche legacy avec support H3)
2. **Adapter pour SmartPi One** (basé sur config dolphin-p1/Orange Pi)
3. **Créer workflow GitHub Actions** avec larger runners ou self-hosted
4. **Tester l'image** sur SmartPi One

## Structure de projet recommandée

```
SMARTPI-ANDROID/
├── .github/
│   └── workflows/
│       └── build-android.yml
├── device/
│   └── smartpi/
│       └── smartpi1/          # Config spécifique SmartPi One
├── kernel/
│   └── allwinner/
│       └── h3/                # Kernel sources
├── vendor/
│   └── smartpi/               # Blobs propriétaires (Mali GPU, etc.)
├── local_manifests/
│   └── smartpi.xml            # Manifest pour repo sync
└── README.md
```

## Liens utiles

- SDK Allwinner : https://linux-sunxi.org/SDK_build_howto
- GloDroid : https://glodroid.github.io/
- Orange Pi sources : https://github.com/orangepi-xunlong
- Allwinner Android : https://github.com/allwinner-android

## Projet parent

Ce projet est lié à **SmartPi-armbian** qui gère les builds Linux :
- Debian Bookworm/Trixie
- Ubuntu Jammy/Noble
- DietPi

Repository : https://github.com/[votre-username]/SmartPi-armbian
