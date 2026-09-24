# Carik Bot Engine with Docker

> Jalankan **Carik Bot Engine** (Object Pascal + FastPlaz) sebagai container yang ringan, cepat, dan siap produksi.

[![Docker](https://img.shields.io/badge/docker-ready-blue?logo=docker)](https://hub.docker.com/r/fastplaz/ubuntu) [![Compose](https://img.shields.io/badge/compose-v2-2496ED?logo=docker)](https://docs.docker.com/compose/) [![Pascal](https://img.shields.io/badge/powered%20by-FastPlaz%20%2F%20FreePascal-red)](https://fastplaz.com)

Kelebihan biner *native* Free Pascal membuat Carik sangat hemat RAM/CPU — ideal untuk VPS kecil maupun deployment skala besar. Repositori `carik-docker` ini memisahkan konfigurasi deployment dari kode engine agar update engine (`carik-linux.tar.gz`) tidak mengganggu infrastruktur.

**Cabang `development`** = integrasi fitur berikutnya sebelum merge ke `main`. Untuk produksi stabil, gunakan `main`.

---

## Daftar Isi
- [Arsitektur](#arsitektur)
- [Kebutuhan Sistem](#kebutuhan-sistem)
- [Quick Start (3 Langkah)](#quick-start-3-langkah)
- [Konfigurasi (.env & config.json)](#konfigurasi-env--configjson)
- [Volume & Persistensi](#volume--persistensi)
- [Healthcheck & Observability](#healthcheck--observability)
- [Hardening & Keamanan](#hardening--keamanan)
- [Alur Pengembangan (Branching)](#alur-pengembangan-branching)
- [Troubleshooting](#troubleshooting)
- [Lisensi](#lisensi)

---

## Arsitektur

```
Host (laptop/VPS)
 ├─ .env (+ HOST_PORT, TELEGRAM_TOKEN)
 ├─ config.json  ──bind──► /projects/carik/config/config.json
 ├─ files/nlp/*  ──bind:ro─► /projects/carik/files/nlp/
 ├─ carik_data   (volume) ─► /projects/carik/data
 ├─ carik_temp   (volume) ─► /projects/carik/ztemp
 └─ docker-compose.yml
        └─ carikbot (fastplaz/ubuntu + Apache + Carik engine)
               ├─ /var/www/html/carik  → symlink → /projects/carik
               ├─ HEALTHCHECK: curl http://localhost:${PORT:-80}/carik/
               └─ ENTRYPOINT: /app/run.sh (inject TELEGRAM_TOKEN via jq)
```

Base image `fastplaz/ubuntu` sudah berisi Apache2 + runtime FastPlaz. `Dockerfile` hanya menambah `curl`/`jq`, permission `www-data`, dan `HEALTHCHECK`.

---

## Kebutuhan Sistem

| Komponen | Minimal |
|---|---|
| Docker Engine | 20.10+ |
| Docker Compose | v2 (`docker compose` tanpa hyphen) |
| `carik-linux.tar.gz` | Unduh dari [Releases Carik](https://github.com/luridarmawan/Carik/releases) dan letakkan di root repo (tidak di-commit, di-ignore di `.gitignore` contoh) |
| RAM | 128 MB cukup untuk 1 bot (tanpa ML eksternal) |
| Port host bebas | default `8080` |

> Jika `carik-linux.tar.gz` belum ada, build akan gagal pada `COPY carik-linux.tar.gz`. Ambil release terbaru, bukan dari branch.

---

## Quick Start (3 Langkah)

**1. Siapkan env**

```bash
cp .env.example .env
# edit .env — isi HOST_PORT dan TELEGRAM_TOKEN jika pakai Telegram
cat .env
# HOST_PORT=8080
# TELEGRAM_TOKEN=123456:ABC...
```

**2. Jalankan**

```bash
docker compose up -d --build
docker compose logs -f   # Ctrl+C untuk keluar log
```

**3. Verifikasi**

```bash
curl -i http://localhost:8080/carik/          # BaseURL chatbot
curl -i "http://localhost:8080/echo/?val1=halo" # Test echo FastPlaz
docker inspect --format='{{json .State.Health}}' $(docker compose ps -q carikbot) | jq
```

Hentikan:

```bash
docker compose down        # volume tetap (data tidak hilang)
docker compose down -v     # hapus volume juga (reset total)
```

---

## Konfigurasi (.env & config.json)

`.env` adalah cara paling aman — tidak perlu edit `config.json` manual. `files/run.sh` akan inject saat start via `jq --arg token`.

| Variabel | Default | Deskripsi |
|---|---|---|
| `HOST_PORT` | `8080` | Port di host yang di-map ke `80` container. Ubah jika bentrok (mis. `3000`). |
| `TELEGRAM_TOKEN` | *(kosong)* | Token Bot Telegram. Jika diisi, akan overwrite `telegram.default.token` di `config.json` secara idempoten (aman untuk `| & / "`). Kosongkan jika tidak pakai Telegram. |
| `PORT` | `80` | Port internal Apache di container. Jarang diubah; hanya jika image dipakai tanpa compose. Di-compose sudah di-set `PORT=80` dan `HOST_PORT` diteruskan untuk banner. |

Contoh `.env` lengkap:

```env
HOST_PORT=8080
TELEGRAM_TOKEN=123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11
# PORT=80  # uncomment hanya jika perlu
```

`config.json` tetap di-bind mount (`./config.json:/projects/carik/config/config.json`) sehingga perubahan di host langsung terlihat di container tanpa rebuild. Jika `TELEGRAM_TOKEN` di-set, file host akan dimodifikasi **sekali** saat start (idempoten, tidak duplikat saat restart).

Untuk konfigurasi lain (database, `ai.basedir`, `redis`, dll.) edit `config.json` langsung — lihat `config.json:1` sebagai template.

---

## Volume & Persistensi

| Host | Container | Mode | Fungsi |
|---|---|---|---|
| `./config.json` | `/projects/carik/config/config.json` | `rw` (harus writable untuk inject token) | Konfigurasi utama |
| `./files/nlp/` | `/projects/carik/files/nlp/` | `ro` | Kamus SimpleAI (entities/intents/response). Read-only agar tidak tertimpa dari container. |
| `carik_data` | `/projects/carik/data` | volume | Data runtime (DB file, dsb.) — **persist** antar `down`/`up` |
| `carik_temp` | `/projects/carik/ztemp` | volume | Session & cache — **persist** |

> Pada branch `main` lama, semua data ephemeral (hilang saat `down`). Sejak PR #5 + hardening `484e6ed`, data aman di named volume.

Backup volume:

```bash
docker run --rm -v carik-docker_carik_data:/data -v $(pwd):/backup alpine tar czf /backup/carik_data.tgz /data
```

---

## Healthcheck & Observability

`Dockerfile:34` mendefinisikan:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:${PORT:-80}/carik/ || curl -f http://localhost/carik/ || exit 1
```

`curl` di-install di `Dockerfile:6` agar tidak false-unhealthy. Cek status:

```bash
docker compose ps
docker inspect --format='{{.State.Health.Status}}' $(docker compose ps -q carikbot)
# healthy | starting | unhealthy
```

Log startup `run.sh` menampilkan banner:

```
============================================================
 Carik Bot Engine (FastPlaz / Object Pascal Runtime)
============================================================
 Status       : Aktif
 Container    : http://localhost:80/carik/
 Host         : http://localhost:8080/carik/
 NLP Engine   : FastPlaz SimpleAI (files/nlp/)
============================================================
```

Jika `PORT` kustom di-set, `run.sh` akan patch `/etc/apache2/ports.conf` dan `000-default.conf` secara spesifik (tidak `*.conf` greedy).

---

## Hardening & Keamanan

Perubahan sejak PR #4 → hardening `484e6ed` (sudah di `main`, kini di `development`):

- **Inject token aman**: `jq --arg token "$TELEGRAM_TOKEN" '.telegram.default.token = $token'` — tahan karakter `| & / \ "`. Fallback `python3` → `sed` escaped. PR awal hanya `sed "s|\"token\": \"\"|...|g"` yang gagal jika token mengandung `|`.
- **Idempoten**: `jq` overwrite nilai, bukan replace string `""` saja — restart berkali-kali tetap 1 nilai.
- **`curl` + `jq` di image**: `HEALTHCHECK` tidak lagi gagal karena binary hilang.
- **`files/nlp:ro`**: mencegah container menulis balik kamus.
- **Hapus `container_name`**: memungkinkan `docker compose up --scale` dan multi-stack tanpa konflik nama.
- **`ENV PORT=80`**: healthcheck konsisten bahkan tanpa compose.
- **`chown` dengan warn**: `chown www-data` yang gagal (mis. base image tanpa user) kini log `[warn]` bukan silent `|| true`.
- **Debug bypass**: `docker run carik-bot bash` tetap bisa (ENTRYPOINT deteksi `bash`/`sh`).

**Jangan commit `.env`** (sudah di `.dockerignore` & `.gitignore` contoh). Token di `docker inspect` terlihat di `Env` — untuk produksi sensitif, pertimbangkan Docker Secrets atau `env_file` dengan permission `600`.

---

## Alur Pengembangan (Branching)

```
main (stabil, prod) ◄── PR squash
 ▲
 └─ development (integrasi, branch ini) ◄── fitur/*, fix/*, hardening/*
```

- `development` selalu merge dari `main` terbaru (`a55f2ad` saat ini).
- Fitur baru: buat branch `fitur/nama` dari `development`, PR ke `development`, lalu periodik PR `development → main`.
- Rilis `carik-linux.tar.gz` tidak di-version di git — update manual di kedua branch.

Untuk sinkron:

```bash
git checkout development && git pull
git merge main   # atau git pull origin main
```

---

## Troubleshooting

| Gejala | Penyebab | Solusi |
|---|---|---|
| `COPY failed: carik-linux.tar.gz not found` | File release belum di root | `curl -L -o carik-linux.tar.gz https://github.com/luridarmawan/Carik/releases/latest/download/carik-linux.tar.gz` |
| `permission denied` di `ztemp/data` | Volume baru masih `root:root` | `run.sh` otomatis `chown www-data`; jika tetap, `docker compose down -v && docker compose up -d` |
| `HEALTHCHECK unhealthy` | `curl` gagal atau Carik belum ready | `docker compose logs carikbot`, cek `curl -v http://localhost:8080/carik/` dari host, tunggu `start-period 10s` |
| `TELEGRAM_TOKEN` tidak masuk | `config.json` di-mount `:ro` | Pastikan compose pakai `:ro` hanya untuk `files/nlp`, bukan `config.json` (sudah benar di `docker-compose.yml:15-16`) |
| Port `8080` bentrok | Host sudah pakai `8080` | `echo HOST_PORT=3000 >> .env && docker compose up -d` |
| `docker compose` vs `docker-compose` | Compose v1 vs v2 | Gunakan `docker compose` (spasi). Alias lama masih jalan tapi deprecated. |

---

## Lisensi dan Pengembang

Carik dikembangkan oleh **Luri Darmawan** dan kontributor komunitas. Framework [FastPlaz](https://fastplaz.com) (Free Pascal). Lihat [carik.id](https://carik.id) untuk dokumentasi engine dan lisensi.

> Kontribusi: PR ke `development` lebih cepat di-review. Sertakan `docker compose config` dan `bash -n files/run.sh` di deskripsi PR.
