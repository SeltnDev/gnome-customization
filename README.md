# gnome-desktop-setup

Kişisel GNOME masaüstümü tek komutla yeni bir Linux kurulumuna taşıyan script.

Ortalanmış görev çubuğu, Arch menü düğmesinin hemen sağında Windows 11 tarzı arama çubuğu,
buzlu cam panel, koyu tema, Ubuntu yazı tipleri, Yaru simgeleri, pencere döşeme düzenleri ve gece ışığı.

## Neler kurulur?

| Bileşen | Ayrıntı |
|---|---|
| [Dash to Panel](https://extensions.gnome.org/extension/1160/dash-to-panel/) | Üst paneli kaldırır, ortalanmış tek bir görev çubuğu yapar (%55 saydam) |
| [ArcMenu](https://extensions.gnome.org/extension/3628/arcmenu/) | Arch logolu, alt ortada açılan başlat menüsü |
| Taskbar Search | Menü düğmesinin sağında Windows 11 tarzı arama kutusu (bu depoya ait) |
| [Blur my Shell](https://extensions.gnome.org/extension/3193/blur-my-shell/) | Panel, dash ve genel görünümde buzlu cam efekti |
| [Tiling Shell](https://extensions.gnome.org/extension/7065/tiling-shell/) | Windows 11 Snap Assistant benzeri pencere döşeme ve hazır düzenler |
| Tema | Koyu mod, mavi vurgu rengi, Yaru-blue-dark simgeleri, Yaru imleci |
| Yazı tipleri | Ubuntu 11, Ubuntu Mono 13, başlık çubuğunda Ubuntu Bold |
| Pencereler | Küçült / büyüt / kapat düğmeleri, yeni pencereler ortada açılır |
| Diğer | Duvar kâğıdı, sabitlenmiş uygulamalar, pil yüzdesi, gece ışığı (20:00–06:00, 2700 K) |

## Kurulum

GNOME oturumu içindeki bir terminalde:

```bash
git clone https://github.com/<kullanıcı-adı>/gnome-desktop-setup.git
cd gnome-desktop-setup
./install.sh
```

Bitince **oturumu kapatıp yeniden açın** (Wayland'de yeni eklentiler ancak böyle yüklenir).

| Seçenek | Açıklama |
|---|---|
| `--no-packages` | Sistem paketlerini kurma (sudo istemez) |
| `--no-extensions` | Eklentileri indirme |
| `--update-extensions` | Kurulu eklentileri de en son sürümle yeniden indir |

## Script ne yapar?

1. **Paketler:** `curl`, `dconf`, Ubuntu yazı tipi ve Yaru simge temasını dağıtımın paket yöneticisiyle kurar.
   Bulunamayan paket kurulumu durdurmaz.
2. **Yazı tipleri:** Ubuntu / Ubuntu Mono paketle gelmediyse Google Fonts'tan `~/.local/share/fonts` içine indirir.
3. **Eklentiler:** `extensions.txt` listesindekileri, çalışan GNOME sürümüyle uyumlu sürümüyle
   [extensions.gnome.org](https://extensions.gnome.org)'dan indirir. `extensions/` klasöründekileri doğrudan kurar.
4. **Duvar kâğıdı:** `wallpapers/` içeriğini `~/.local/share/backgrounds/` altına kopyalar.
5. **Ayarlar:** Önce mevcut ayarların tamamını `~/.config/gnome-desktop-setup-backup-*.ini` dosyasına yedekler,
   sonra `config/` altındaki GNOME, eklenti ve GTK ayarlarını uygular. Simge ya da imleç teması
   kurulamadıysa Adwaita'ya düşer.

### Dağıtım desteği

| Paket yöneticisi | Dağıtımlar | Not |
|---|---|---|
| `pacman` | Arch, EndeavourOS, Manjaro | Yaru, AUR'dan `paru`/`yay` ile kurulur |
| `apt` | Debian, Ubuntu, Mint, Pop!_OS | |
| `dnf` | Fedora | Ubuntu yazı tipi Google Fonts'tan iner |
| `zypper` | openSUSE | |
| diğerleri | | Paket adımı atlanır, gerisi çalışır |

Paketler dışında her şey dağıtımdan bağımsızdır; tek şart GNOME Shell 45 veya üzeridir.

## Masaüstünü güncel tutma

Masaüstünde bir şeyi değiştirdikten sonra:

```bash
./export.sh        # mevcut ayarları config/ altına yazar
git add -A && git commit -m "Masaüstü ayarlarını güncelle" && git push
```

`export.sh` yalnızca masaüstüyle ilgili anahtarları alır. Dash to Panel'in monitöre özel ayarlarını
monitör sırasına çevirir, böylece ayarlar başka bir bilgisayarda da çalışır.
`extensions/` içindeki eklentilerin kaynağını da kurulu sürümle eşitler.

## Geri alma

```bash
dconf load / < ~/.config/gnome-desktop-setup-backup-<tarih>.ini
```

## Depo yapısı

```
install.sh                       kurulum
export.sh                        mevcut masaüstünü depoya aktarma
extensions.txt                   extensions.gnome.org'dan indirilecek eklentiler
extensions/taskbar-search@yenisoy/   Windows 11 tarzı arama çubuğu (bu depoya ait)
config/gnome.ini                 tema, yazı tipi, pencere, gece ışığı, sabitlenmiş uygulamalar
config/extensions/*.ini          eklenti ayarları
config/gtk-3.0/                  GTK3 ayarları
wallpapers/                      duvar kâğıtları
```

## Taskbar Search eklentisi

Menü düğmesinin sağına, panelin buzlu cam görünümüne uyan hap biçimli bir arama kutusu ekler.
Kutuya doğrudan yazılır; Enter'a basınca ArcMenu açılır ve yazılan metni onun içinde arar
(boş Enter yalnızca menüyü açar, Esc kutuyu temizler). ArcMenu yoksa GNOME'un genel görünüm aramasını kullanır.
Dash to Panel ile birlikte ve onsuz çalışır. Etiket, sistem dili Türkçeyse "Ara", değilse "Search" olur.

## Emeği geçenler

- Duvar kâğıdı: `split.png`, [archlinux-wallpaper](https://archlinux.org/packages/extra/any/archlinux-wallpaper/) paketinden (CC0)
- [Dash to Panel](https://extensions.gnome.org/extension/1160/dash-to-panel/),
  [ArcMenu](https://extensions.gnome.org/extension/3628/arcmenu/),
  [Blur my Shell](https://extensions.gnome.org/extension/3193/blur-my-shell/),
  [Tiling Shell](https://extensions.gnome.org/extension/7065/tiling-shell/)
- Ubuntu yazı tipi: Ubuntu Font Licence 1.0, Yaru: Canonical

---

<sub>Bu kurulum scripti ve README, [Claude](https://claude.com/claude-code) (Anthropic) tarafından hazırlanmıştır.</sub>
