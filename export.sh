#!/usr/bin/env bash
# Şu anki GNOME masaüstünü bu depoya aktarır (config/, wallpapers/, extensions/).
# Masaüstünde bir şey değiştirdikten sonra çalıştırıp değişiklikleri commit edin.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$ROOT/config"
WALL="$ROOT/wallpapers"
BUNDLED="$ROOT/extensions"
USER_EXT="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions"

# Aktarılacak çekirdek GNOME anahtarları: "şema|anahtar anahtar ..."
CORE_KEYS=(
  "org.gnome.desktop.interface|gtk-theme icon-theme cursor-theme color-scheme accent-color font-name document-font-name monospace-font-name font-antialiasing font-hinting clock-show-weekday clock-show-date clock-show-seconds show-battery-percentage enable-hot-corners enable-animations"
  "org.gnome.desktop.wm.preferences|button-layout titlebar-font"
  "org.gnome.desktop.background|picture-uri picture-uri-dark picture-options primary-color"
  "org.gnome.desktop.screensaver|picture-uri picture-options primary-color"
  "org.gnome.mutter|center-new-windows dynamic-workspaces edge-tiling"
  "org.gnome.shell|favorite-apps enabled-extensions"
  "org.gnome.settings-daemon.plugins.color|night-light-enabled night-light-schedule-automatic night-light-schedule-from night-light-schedule-to night-light-temperature"
)

# Makineye ya da arayüz durumuna özgü, taşınmaması gereken eklenti anahtarları
SKIP_KEYS='^(prefs-opened|prefs-visible-page|recently-installed-apps|overridden-settings|available-monitors|primary-monitor)='

command -v python3 >/dev/null || { echo "export.sh python3 gerektirir." >&2; exit 1; }

mkdir -p "$CFG/extensions" "$WALL"
rm -f "$CFG/extensions/"*.ini

# --- Çekirdek ayarlar + duvar kâğıtları ---------------------------------------
{
  echo "# export.sh tarafından üretildi; elle düzenlemek yerine export.sh'i yeniden çalıştırın."
  for entry in "${CORE_KEYS[@]}"; do
    schema="${entry%%|*}"
    gsettings list-schemas | grep -qx "$schema" || continue
    echo
    echo "[${schema//.//}]"
    for key in ${entry#*|}; do
      gsettings range "$schema" "$key" >/dev/null 2>&1 || continue
      value="$(gsettings get "$schema" "$key")"
      if [[ "$value" == "'file://"* ]]; then
        path="$(python3 -c 'import sys,urllib.parse as u; print(u.unquote(u.urlparse(sys.argv[1]).path))' "${value:1:-1}")"
        if [[ -f "$path" ]]; then
          cp -f "$path" "$WALL/"
          value="'file://@WALLPAPER_DIR@/$(basename "$path")'"
        fi
      fi
      echo "$key=$value"
    done
  done
} > "$CFG/gnome.ini"

# --- Eklentiler ---------------------------------------------------------------
enabled="$(gsettings get org.gnome.shell enabled-extensions | tr -d "[],'" )"
: > "$ROOT/extensions.txt"

for uuid in $enabled; do
  # Depoda kaynağı bulunan eklentiler oradan kurulur, diğerleri extensions.gnome.org'dan
  [[ -d "$BUNDLED/$uuid" ]] || echo "$uuid" >> "$ROOT/extensions.txt"

  dir="$USER_EXT/$uuid"
  # Depodaki eklentinin kaynağını kurulu (en güncel) sürümle eşitle
  if [[ -d "$BUNDLED/$uuid" && -f "$dir/metadata.json" ]]; then
    rm -rf "${BUNDLED:?}/$uuid"
    cp -r "$dir" "$BUNDLED/$uuid"
    rm -f "$BUNDLED/$uuid/schemas/gschemas.compiled"
  fi
  [[ -d "$dir" ]] || dir="/usr/share/gnome-shell/extensions/$uuid"
  path="$(grep -ho 'path="/org/gnome/shell/extensions/[^"]*"' "$dir"/schemas/*.xml 2>/dev/null | head -1 | cut -d'"' -f2 || true)"
  [[ -n "$path" ]] || continue

  name="$(basename "$path")"
  dconf dump "$path" | grep -Ev "$SKIP_KEYS" > "$CFG/extensions/$name.ini"

  # Dash to Panel ayarları monitör kimliğiyle saklanır; başka donanımda da
  # çalışması için kimlikleri monitör sırasına ("0", "1", ...) çeviriyoruz.
  python3 - "$CFG/extensions/$name.ini" <<'PY'
import json, re, sys
from gi.repository import Gio

try:
    bus = Gio.bus_get_sync(Gio.BusType.SESSION)
    state = bus.call_sync('org.gnome.Mutter.DisplayConfig', '/org/gnome/Mutter/DisplayConfig',
                          'org.gnome.Mutter.DisplayConfig', 'GetCurrentState',
                          None, None, Gio.DBusCallFlags.NONE, -1, None).unpack()
except Exception:
    sys.exit(0)

ids = {}
for i, logical in enumerate(state[2]):
    connector, vendor, _product, serial = logical[5][0]
    ids[f'{vendor}-{serial}' if vendor and serial else connector] = str(i)

ini = sys.argv[1]
lines = open(ini, encoding='utf-8').read().splitlines()
for n, line in enumerate(lines):
    m = re.match(r"^([\w-]+)='(\{.*\})'$", line)
    if not m:
        continue
    try:
        data = json.loads(m.group(2))
    except ValueError:
        continue
    if not any(k in ids for k in data):
        continue
    data = {ids.get(k, k): v for k, v in data.items()}
    lines[n] = f"{m.group(1)}='{json.dumps(data, separators=(',', ':'))}'"
open(ini, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
PY
done

# --- GTK ----------------------------------------------------------------------
for v in gtk-3.0 gtk-4.0; do
  for f in settings.ini gtk.css; do
    src="${XDG_CONFIG_HOME:-$HOME/.config}/$v/$f"
    if [[ -f "$src" ]]; then
      mkdir -p "$CFG/$v"
      cp -f "$src" "$CFG/$v/$f"
    fi
  done
done

echo "Masaüstü aktarıldı → $ROOT"
echo "  çekirdek ayarlar : config/gnome.ini"
echo "  eklenti ayarları : $(ls "$CFG/extensions" | tr '\n' ' ')"
echo "  indirilecekler   : $(tr '\n' ' ' < "$ROOT/extensions.txt")"
