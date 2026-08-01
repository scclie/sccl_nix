# sccl_nix
> [!NOTE]  
> /// NixOS config: `flakes` + `home-manager` + `disko` + `sops-nix`  
> /// Modular host-profile architecture w/ sccl.* options — scale across machines & users

![desktop_img](img/niri.webp)

## What's Inside¿
> [!NOTE] 
> /// Personal setup: `host::sacculos` + `profile::paper`  
> /// U can use as reference or starting point!! feel free 2 yoink anything~

**Window Manager:**
- **Niri** — scrollable tiling wayland compositord
- Custom layouts: `Colemak-DH | Rulemak-DH` — works 4 all hosts & profiles *(parametrized via flake specialArgs, per host kbd variant)*

**System features (nixos/modules/):**
- `core.nix` — sccl.* option definitions (all default `false`), hosts enable what they need
- `boot.nix`, `nix.nix`, `net.nix`, `audio.nix`, `bluetooth.nix` — system services
- `automount.nix` — udisks2 + polkit USB automag
- `secrets.nix` — sops-nix integration for SSH/GPG keys
- `zapret.nix` — DPI bypass 4 blocked sites
- `playground.nix` — Docker + dev tools (system-level)

**Host layer (hosts/):**
- Auto-discovered by flake (drop dir → `nixosConfigurations.<name>`)
- `gpu.nix` — hardware-specific (amd or nvidia)
- `local-packages.nix` — system-wide packages 4 this machine only

**Profiles (profiles/):**
- `bootstrap/` — minimal (~1-2 GB) 4 fresh installs from USB (nmtui + vim + ssh)
- `shared/` — base configs & packages 4 all users (fish, alacritty, niri, waybar...)
- `paper/` — my chunky profile (steam, blender, krita, opencode...)

**Secrets (sops-nix):** `secrets/common.yaml` — encrypted w/ age key, safe 4 public repo

**DevShells (shells/):** auto-discovered by flake, `nix develop .#playground`

## Table of Contents

- [Architecture](#architecture)
- [Options System](#options-system)
- [Secrets (sops-nix)](#secrets-sops-nix)
- [Installation](#installation)
- [Adding New Hosts](#adding-new-hosts)
- [Adding New Profiles](#adding-new-profiles)
- [Config Structure](#config-structure)

---

## Architecture

```mermaid
flowchart TD
    F[❄️ flake.nix<br/>auto-discovery: hosts + shells]

    NM[⚙️ nixos/modules/core.nix<br/>sccl.* options → conditional config]

    H1[🖥️  hosts/sacculos<br/>desktop + amd gpu]
    H2[💻 hosts/laptop<br/>portable + nvidia gpu]

    P1[👤 profiles/paper<br/>main user: steam, blender...]
    P2[👤 profiles/guest<br/>second user: firefox, vlc...]
    PS[📦 profiles/shared<br/>base: fish, niri, waybar...]

    PB[🪶 profiles/bootstrap<br/>minimal: nmtui, vim, ssh]

    S[🔐 secrets/<br/>sops-nix encrypted]
    SH[🐚 shells/<br/>auto-discovered devShells]

    F --> H1
    F --> H2
    F --> SH

    H1 --> NM
    H2 --> NM

    H1 --> P1
    H1 --> P2
    H2 --> P2

    H1 --> PB
    H2 --> PB

    P1 --> PS
    P2 --> PS

    classDef flakeStyle fill:#517599,stroke:#5e81ac,stroke-width:2px,color:#000
    classDef hostStyle fill:#88c0d0,stroke:#5e81ac,stroke-width:2px,color:#000
    classDef profileStyle fill:#a3be8c,stroke:#8fbcbb,stroke-width:2px,color:#000
    classDef sharedStyle fill:#ebcb8b,stroke:#d08770,stroke-width:2px,color:#000
    classDef moduleStyle fill:#b48ead,stroke:#bf616a,stroke-width:2px,color:#000
    classDef secretStyle fill:#bf616a,stroke:#d08770,stroke-width:2px,color:#000
    classDef shellStyle fill:#d08770,stroke:#ebcb8b,stroke-width:2px,color:#000

    class F flakeStyle
    class H1,H2 hostStyle
    class P1,P2,PB profileStyle
    class PS sharedStyle
    class NM moduleStyle
    class S secretStyle
    class SH shellStyle
```

### How it works

**Separation of concerns:**
- `flake.nix` → minimum logic: auto-discovers hosts + shells, passes `specialArgs`
- `nixos/modules/core.nix` → defines ALL `sccl.*` options (default: `false`), imports modules
- `nixos/modules/<feature>.nix` → each module self-gates via `lib.mkIf config.sccl.<feature>.enable`
- `hosts/` → declares `sccl.{ui,audio,net,...}.enable = true`, imports profiles + hardware files
- `profiles/` → user configs (home-manager): packages, dotfiles, WM binds

**No more `if hostName !=` hacks** — zapret excluded on laptop simply by NOT setting `sccl.zapret.enable`.

**Bootstrap mode** — set `sccl.bootstrap = true` → minimal user (nmtui+vim+ssh), ~1-2 GB closure. After install: `sccl.bootstrap = false` + `nixos-rebuild switch` → full system.

**Example:**
```
hosts/sacculos (desktop) → profiles/paper (main)   → profiles/shared (base)
                         → profiles/guest (second)  → profiles/shared (base)
                         → profiles/bootstrap (install)

hosts/laptop   (portable) → profiles/paper (same)   → profiles/shared (base)
                           → profiles/guest (same)   → profiles/shared (base)
                           → profiles/bootstrap (install)
```

Same user profile works on different machines, same shared base for all users, bootstrap available anywhere!

---

## Options System

Every system feature has an option under `sccl.*`. All default to `false`:

```nix
sccl.ui.enable           # stylix + greetd display manager
sccl.audio.enable        # pipewire
sccl.bluetooth.enable    # bluetooth + blueman
sccl.net.enable          # networkmanager + proxy + firewall
sccl.automount.enable    # udisks2 USB automount
sccl.secrets.enable      # sops-nix
sccl.zapret.enable       # DPI bypass
sccl.flclashx.enable     # FlClashX proxy GUI
sccl.playground.enable   # Docker + dev tools (system-level)
sccl.chaotic.enable      # chaotic-nyx repo
sccl.nix-ld.enable       # nix-ld for proprietary binaries
sccl.bootstrap           # bool: minimal install profile
```

Host enables what it needs in `configuration.nix`:

```nix
sccl = {
  ui.enable = true;
  audio.enable = true;
  bluetooth.enable = true;
  net.enable = true;
  automount.enable = true;    # desktop only
  zapret.enable = true;       # desktop only (repo banned on laptop)
  flclashx.enable = true;
  playground.enable = true;   # desktop only
  nix-ld.enable = true;
};
```

---

## Secrets (sops-nix)

Encrypted w/ age key → safe 4 public repo. SSH/GPG keys live in `secrets/common.yaml`.

### Setup

```bash
# 1. Generate age key (age + sops are in shared packages)
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# 2. Save private key to Bitwarden (or any pw manager)
#    Keep ~/.config/sops/age/keys.txt on disk for daily use

# 3. Copy PUBLIC key (age1...) into secrets/.sops.yaml:
#    age: age1abcdef...   ← replace the placeholder

# 4. Encrypt secrets (run from repo root)
sops --config secrets/.sops.yaml secrets/common.yaml
# → editor opens, paste your actual SSH/GPG keys:
#
#   ssh:
#     id_ed25519: |
#       -----BEGIN OPENSSH PRIVATE KEY-----
#       ...
#     id_ed25519_git: |
#       ...
#   gpg:
#     signing_key: |
#       -----BEGIN PGP PRIVATE KEY BLOCK-----
#       ...
#
# → save & exit → file is now encrypted, safe to commit
```

Enable: `sccl.secrets.enable = true` in host config. On rebuild with `sops-nix`, SSH keys decrypt to `~/.ssh/`, GPG imports automatically.

---

## Installation

### Option 1: Bootstrap (one machine + USB stick)

```bash
# 1. Boot nixos-minimal livecd
# 2. Clone repo & setup host
git clone https://github.com/papersaccul/sccl_nix.git /mnt/etc/nixos
cd /mnt/etc/nixos

# 3. Copy host template
cp -r hosts/sacculos hosts/<hostname>
# Edit hostname + disko paths in hosts/<hostname>/

# 4. Generate hardware config
nixos-generate-config --root /mnt --show-hardware-config --no-filesystems \
  > hosts/<hostname>/hardware-configuration.nix

# 5. Set bootstrap mode in configuration.nix:
#    sccl.bootstrap = true;

# 6. Install (~1-2 GB closure)
nixos-install --flake .#<hostname>

# 7. Reboot → minimal system (nmtui for wifi, vim, ssh)
# 8. Switch to full profile:
#    sccl.bootstrap = false;
sudo nixos-rebuild switch --flake .#<hostname>
```

### Option 2: nixos-anywhere (two machines, faster)

```bash
# 1. Boot target with nixos-minimal livecd (or any ISO w/ SSH)
# 2. On your dev machine: clone repo, configure host
git clone https://github.com/papersaccul/sccl_nix.git
cd sccl_nix
cp -r hosts/sacculos hosts/<hostname>
# Edit hostname + disko paths

# 3. Push & install (closure built locally → no USB space issues)
nix run github:nix-community/nixos-anywhere -- \
  --generate-hardware-config nixos-generate-config \
    hosts/<hostname>/hardware-configuration.nix \
  --flake .#<hostname> \
  root@<target-ip>

# 4. Reboot → full system ready
```

### Option 3: Migrate existing NixOS

```bash
# 1. Backup
sudo cp -r /etc/nixos /etc/nixos.backup

# 2. Clone & setup
git clone https://github.com/papersaccul/sccl_nix ~/sccl_nix
cd ~/sccl_nix
# Setup host (see "Adding New Hosts")

# 3. Test then switch
sudo nixos-rebuild test --flake .#<hostname>
sudo nixos-rebuild switch --flake .#<hostname>
```

---

## Adding New Hosts

```bash
# 1. Create host dir
mkdir -p hosts/<hostname>

# 2. Copy from existing host
cp -r hosts/sacculos/* hosts/<hostname>/

# 3. Edit configuration.nix:
#    - networking.hostName = "<hostname>";
#    - sccl = { ... };  # enable features u need
#    - gpu.nix → amd or nvidia config
#    - local-packages.nix → machine-specific system packages

# 4. Edit disko.nix — change disk paths
# 5. Generate hardware-configuration.nix (see Installation)

# Build & test
nixos-rebuild build --flake .#<hostname>
```

Flake auto-discovers the new host — no edits needed 💅

---

## Adding New Profiles

```bash
mkdir -p profiles/<username>/modules
```

**`profiles/<username>/user.nix`** — system user + groups + shell:
```nix
{ config, pkgs, ... }:
{
  users.users.<username> = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "video" "audio" ];
    shell = pkgs.fish;
    initialPassword = "changeme";
  };
  security.sudo.wheelNeedsPassword = false;
}
```

**`profiles/<username>/home.nix`** — home-manager entry point:
```nix
{ config, pkgs, inputs, ... }:
{
  imports = [
    ../shared/packages.nix
    ../shared/modules
    ./packages.nix
    ./modules
  ];
  home = {
    username = "<username>";
    homeDirectory = "/home/<username>";
    stateVersion = "26.05";
  };
  programs.home-manager.enable = true;
}
```

**Import in host config:**
```nix
# hosts/<hostname>/configuration.nix
imports = [
  ...
  ../../profiles/<username>/user.nix
];

home-manager.users.<username> = import ../../profiles/<username>/home.nix;
```

---

## Config Structure

```tree
sccl_nix
 ├── flake.nix                 # inputs + mkHost + auto-discovery (hosts & shells)
 ├── flake.lock
 │
 ├── shells/
 │   └── playground.nix        # auto-discovered devShells (nix develop .#playground)
 │
 ├── secrets/                  # sops-nix encrypted secrets
 │   ├── .sops.yaml            # age public key config
 │   └── common.yaml           # SSH/GPG keys (encrypted, safe 4 public repo)
 │
 ├── nixos/
 │   └── modules/              # system services (host-independent)
 │       ├── core.nix          # ALL sccl.* options + module imports
 │       ├── automount.nix     # udisks2 + polkit (sccl.automount.enable)
 │       ├── audio.nix         # pipewire (sccl.audio.enable)
 │       ├── bluetooth.nix     # (sccl.bluetooth.enable)
 │       ├── boot.nix          # systemd-boot + plymouth
 │       ├── display-manager.nix # greetd + tuigreet
 │       ├── env.nix           # EDITOR, session variables
 │       ├── flclashx.nix      # FlClashX proxy (sccl.flclashx.enable)
 │       ├── keyboard.nix      # parametrized (vial/colemak) via specialArgs
 │       ├── net.nix           # networkmanager + proxy (sccl.net.enable)
 │       ├── nix.nix           # nix settings + GC
 │       ├── nix-ld.nix        # proprietary binary support (sccl.nix-ld.enable)
 │       ├── playground.nix    # Docker + tools (sccl.playground.enable)
 │       ├── secrets.nix       # sops-nix (sccl.secrets.enable)
 │       ├── stylix.nix        # nord theme + fonts (sccl.ui.enable)
 │       ├── timezone.nix      # Europe/Moscow
 │       ├── xdg-portal.nix    # WM-agnostic portal config
 │       └── zapret.nix        # DPI bypass (sccl.zapret.enable)
 │
 ├── hosts/
 │   └── <hostname>/
 │       ├── configuration.nix  # sccl.* options + profile imports
 │       ├── disko.nix          # disk partitioning
 │       ├── hardware-configuration.nix
 │       ├── gpu.nix            # amd or nvidia (host-specific)
 │       └── local-packages.nix # system-wide packages (host-specific)
 │
 └── profiles/
     ├── bootstrap/            # minimal install profile (~1-2 GB)
     │   ├── user.nix          # bootstrap user + nmtui + vim + ssh
     │   └── home.nix          # minimal home-manager
     ├── shared/               # base configs 4 all users
     │   ├── packages.nix      # CLI tools, firefox, themes, fonts
     │   └── modules/          # fish, niri, alacritty, waybar...
     └── paper/                # full user profile
         ├── user.nix          # paper + paper-dis users
         ├── home.nix          # imports shared + paper modules
         ├── packages.nix      # steam, blender, krita...
         └── modules/          # opencode/ (config + module), playground
```

## License

> [!IMPORTANT]
> This configuration is provided as-is for personal use!! Modify as needed for ur own systems~ Use at ur own risk (but it should work fine lol)
>
> feel free 2 fork, star, or yoink whatever u need!!
