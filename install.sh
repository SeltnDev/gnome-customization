#!/usr/bin/env bash
# GNOME masaüstünü bu depodaki ayarlarla kurar.
# Desteklenen paket yöneticileri: pacman (+yay/paru), apt, dnf, zypper.
# Diğer dağıtımlarda paket adımı atlanır; geri kalan her şey çalışır.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$ROOT/config"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
EXT_DIR="$DATA_HOME/gnome-shell/extensions"
WALLPAPER_DIR="$DATA_HOME/backgrounds/gnome-desktop-setup"
FONT_DIR="$DATA_HOME/fonts/gnome-desktop-setup"
EGO="https://extensions.gnome.org"
GFONTS="https://github.com/google/fonts/raw/main/ufl"

DO_PACKAGES=1
DO_EXTENSIONS=1
UPDATE_EXTENSIONS=0

usage() {
  cat <<EOF
Kullanım: ./install.sh [seçenekler]

  --no-packages         Sistem paketlerini (yazı tipi, simge teması) kurma
  --no-extensions       GNOME eklentilerini indirme/kurma
  --update-extensions   Kurulu eklentileri de en son sürümle yeniden indir
  -h, --help            Bu yardımı göster
EOF
}

for arg in "$@"; do
  case "$arg" in
    --no-packages) DO_PACKAGES=0 ;;
    --no-extensions) DO_EXTENSIONS=0 ;;
    --update-extensions) UPDATE_EXTENSIONS=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Bilinmeyen seçenek: $arg" >&2; usage; exit 1 ;;
  esac
done

if [[ -t 1 ]]; then
  B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
else
  B=''; G=''; Y=''; R=''; N=''
fi
step() { echo; echo "${B}==> $*${N}"; }
ok()   { echo "  ${G}✓${N} $*"; }
warn() { echo "  ${Y}!${N} $*"; WARNINGS+=("$*"); }
die()  { echo "${R}Hata:${N} $*" >&2; exit 1; }
WARNINGS=()

# --- Ön kontroller ------------------------------------------------------------
[[ $EUID -ne 0 ]] || die "Bu script'i root olarak değil, normal kullanıcınızla çalıştırın (gerekirse sudo kendisi sorar)."
command -v gnome-shell >/dev/null || die "GNOME Shell bulunamadı. Önce GNOME masaüstünü kurun."
[[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] || die "Oturum D-Bus'ı yok. Script'i GNOME oturumunun içindeki bir terminalden çalıştırın."

SHELL_MAJOR="$(gnome-shell --version | grep -oE '[0-9]+' | head -1)"
echo "${B}GNOME Shell $SHELL_MAJOR${N} algılandı."

BACKUP="$CONFIG_HOME/gnome-desktop-setup-backup-$(date +%Y%m%d-%H%M%S).ini"

# --- 1. Paketler --------------------------------------------------------------
pkg_install() {
  # Paketleri tek tek kurar; bulunamayan paket kurulumu durdurmaz.
  local pkg
  for pkg in "$@"; do
    case "$PM" in
      pacman) sudo pacman -S --needed --noconfirm "$pkg" >/dev/null 2>&1 ;;
      apt)    sudo apt-get install -y "$pkg" >/dev/null 2>&1 ;;
      dnf)    sudo dnf install -y "$pkg" >/dev/null 2>&1 ;;
      zypper) sudo zypper --non-interactive install "$pkg" >/dev/null 2>&1 ;;
    esac && ok "$pkg" || echo "  - $pkg depoda yok, atlandı"
  done
}

if (( DO_PACKAGES )); then
  step "Sistem paketleri"
  PM=""
  for candidate in pacman apt-get dnf zypper; do
    if command -v "$candidate" >/dev/null; then PM="${candidate%-get}"; break; fi
  done

  case "$PM" in
    pacman)
      pkg_install curl dconf ttf-ubuntu-font-family
      AUR=""
      for helper in paru yay; do command -v "$helper" >/dev/null && { AUR="$helper"; break; }; done
      if [[ -n "$AUR" ]]; then
        "$AUR" -S --needed --noconfirm yaru-icon-theme >/dev/null 2>&1 && ok "yaru-icon-theme (AUR)" \
          || echo "  - yaru-icon-theme AUR'dan kurulamadı"
      else
        echo "  - AUR yardımcısı (yay/paru) yok; yaru-icon-theme atlandı"
      fi
      ;;
    apt)
      sudo apt-get update -qq >/dev/null 2>&1 || true
      pkg_install curl dconf-cli fonts-ubuntu yaru-theme-icon
      ;;
    dnf)    pkg_install curl dconf yaru-icon-theme ;;
    zypper) pkg_install curl dconf ubuntu-fonts yaru-icon-theme ;;
    *)      warn "Paket yöneticisi tanınmadı; paketler atlandı. curl ve dconf'un kurulu olduğundan emin olun." ;;
  esac
fi

command -v dconf >/dev/null || die "dconf komutu yok. Dağıtımınızın 'dconf' (Debian/Ubuntu'da 'dconf-cli') paketini kurun."
command -v curl  >/dev/null || die "curl yok. Lütfen kurun."

# --- 2. Yazı tipleri (paketle gelmediyse Google Fonts'tan) --------------------
step "Yazı tipleri"
font_fallback() {
  # $1 = aile adı, $2 = Google Fonts klasörü, $3... = dosya adları
  local family="$1" dir="$2"; shift 2
  if fc-list : family | tr ',' '\n' | grep -qx "$family"; then
    ok "$family"
    return
  fi
  mkdir -p "$FONT_DIR"
  local f
  for f in "$@"; do
    curl -fsSL -o "$FONT_DIR/$f" "$GFONTS/$dir/$f" || { warn "$family indirilemedi ($f)"; return; }
  done
  ok "$family (Google Fonts'tan indirildi)"
  FONTS_CHANGED=1
}
FONTS_CHANGED=0
if grep -q "'Ubuntu " "$CFG/gnome.ini"; then
  font_fallback "Ubuntu" ubuntu Ubuntu-Regular.ttf Ubuntu-Italic.ttf Ubuntu-Medium.ttf Ubuntu-Bold.ttf Ubuntu-BoldItalic.ttf Ubuntu-Light.ttf
fi
if grep -q "'Ubuntu Mono " "$CFG/gnome.ini"; then
  font_fallback "Ubuntu Mono" ubuntumono UbuntuMono-Regular.ttf UbuntuMono-Italic.ttf UbuntuMono-Bold.ttf UbuntuMono-BoldItalic.ttf
fi
(( FONTS_CHANGED )) && fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true

# --- 3. Eklentiler ------------------------------------------------------------
install_from_ego() {
  local uuid="$1" info url tmp
  info="$(curl -fsSL "$EGO/extension-info/?uuid=${uuid//@/%40}&shell_version=$SHELL_MAJOR" 2>/dev/null)" || {
    warn "$uuid: GNOME $SHELL_MAJOR ile uyumlu sürüm extensions.gnome.org'da bulunamadı"
    return 1
  }
  url="$(printf '%s' "$info" | grep -oE '"download_url": *"[^"]*"' | sed -E 's/.*"(\/[^"]*)"$/\1/')"
  [[ -n "$url" ]] || { warn "$uuid: indirme adresi alınamadı"; return 1; }

  tmp="$(mktemp -d)"
  if ! curl -fsSL -o "$tmp/ext.zip" "$EGO$url"; then
    rm -rf "$tmp"; warn "$uuid indirilemedi"; return 1
  fi
  if ! gnome-extensions install --force "$tmp/ext.zip" >/dev/null 2>&1; then
    # gnome-extensions başarısız olursa elle aç
    rm -rf "${EXT_DIR:?}/$uuid"; mkdir -p "$EXT_DIR/$uuid"
    if ! (command -v unzip >/dev/null && unzip -oq "$tmp/ext.zip" -d "$EXT_DIR/$uuid"); then
      rm -rf "$tmp"; warn "$uuid kurulamadı (unzip gerekli)"; return 1
    fi
  fi
  rm -rf "$tmp"
}

compile_schemas() {
  local dir="$1/schemas"
  if [[ -d "$dir" && ! -f "$dir/gschemas.compiled" ]] && command -v glib-compile-schemas >/dev/null; then
    glib-compile-schemas "$dir"
  fi
}

if (( DO_EXTENSIONS )); then
  step "GNOME eklentileri"
  mkdir -p "$EXT_DIR"

  while read -r uuid; do
    [[ -n "$uuid" && "$uuid" != \#* ]] || continue
    if [[ -d "$EXT_DIR/$uuid" || -d "/usr/share/gnome-shell/extensions/$uuid" ]] && (( ! UPDATE_EXTENSIONS )); then
      ok "$uuid (zaten kurulu)"
      continue
    fi
    install_from_ego "$uuid" && compile_schemas "$EXT_DIR/$uuid" && ok "$uuid"
  done < "$ROOT/extensions.txt"

  for src in "$ROOT"/extensions/*/; do
    [[ -f "$src/metadata.json" ]] || continue
    uuid="$(basename "$src")"
    rm -rf "${EXT_DIR:?}/$uuid"
    cp -r "$src" "$EXT_DIR/$uuid"
    compile_schemas "$EXT_DIR/$uuid"
    ok "$uuid (depodan)"
  done
fi

# --- 4. Duvar kâğıdı ----------------------------------------------------------
step "Duvar kâğıdı"
mkdir -p "$WALLPAPER_DIR"
cp -f "$ROOT"/wallpapers/* "$WALLPAPER_DIR/" 2>/dev/null && ok "$WALLPAPER_DIR" || warn "wallpapers/ klasörü boş"

# --- 5. Ayarlar ---------------------------------------------------------------
step "Ayarlar uygulanıyor"
dconf dump / > "$BACKUP"
ok "Eski ayarlar yedeklendi: $BACKUP"

theme_exists() {
  local d
  for d in "$DATA_HOME/icons" "$HOME/.icons" /usr/share/icons /usr/local/share/icons; do
    [[ -d "$d/$1" ]] && return 0
  done
  return 1
}

core="$(sed "s|@WALLPAPER_DIR@|$WALLPAPER_DIR|g" "$CFG/gnome.ini")"
for key in icon-theme cursor-theme; do
  theme="$(printf '%s\n' "$core" | sed -nE "s/^$key='(.*)'$/\1/p")"
  if [[ -n "$theme" ]] && ! theme_exists "$theme"; then
    warn "$theme teması bulunamadı; $key için Adwaita kullanılıyor"
    core="$(printf '%s\n' "$core" | sed -E "s/^$key=.*/$key='Adwaita'/")"
  fi
done
printf '%s\n' "$core" | dconf load /
ok "GNOME arayüzü, yazı tipleri, pencere düğmeleri, sabitlenmiş uygulamalar"

for ini in "$CFG"/extensions/*.ini; do
  [[ -f "$ini" ]] || continue
  name="$(basename "$ini" .ini)"
  dconf load "/org/gnome/shell/extensions/$name/" < "$ini"
  ok "$name eklenti ayarları"
done

gsettings set org.gnome.shell disable-user-extensions false

for v in gtk-3.0 gtk-4.0; do
  [[ -d "$CFG/$v" ]] || continue
  mkdir -p "$CONFIG_HOME/$v"
  for f in "$CFG/$v"/*; do
    target="$CONFIG_HOME/$v/$(basename "$f")"
    [[ -f "$target" ]] && ! cmp -s "$f" "$target" && cp -f "$target" "$target.bak"
    cp -f "$f" "$target"
  done
  ok "$v"
done

# Çalışan oturumda zaten yüklü olan eklentileri hemen etkinleştir
for uuid in $(gsettings get org.gnome.shell enabled-extensions | tr -d "[],'"); do
  gnome-extensions enable "$uuid" >/dev/null 2>&1 || true
done

# --- Özet ---------------------------------------------------------------------
echo
echo "${G}${B}Kurulum tamamlandı.${N}"
if (( ${#WARNINGS[@]} )); then
  echo "${Y}Uyarılar:${N}"
  printf '  - %s\n' "${WARNINGS[@]}"
fi
cat <<EOF

Yeni eklentilerin yüklenmesi için ${B}oturumu kapatıp yeniden açın${N}.
Geri almak için:  dconf load / < "$BACKUP"
EOF
