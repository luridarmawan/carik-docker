# Carik Bot Engine with Docker

Repositori ini menyediakan berkas konfigurasi Docker dan Docker Compose untuk menjalankan **Carik Bot Engine** berbasis Object Pascal dan FastPlaz di lingkungan container secara ringkas dan terisolasi.

Kelebihan kompilasi biner *native* Object Pascal menjadikan Carik sangat ringan, cepat, dan hemat sumber daya server.

---

## Kebutuhan Sistem

- Docker Engine (versi 20.10 atau yang lebih baru)
- Docker Compose v2

---

## Panduan Penggunaan

### 1. Menyiapkan Berkas Lingkungan (.env)

Salin berkas contoh `.env.example` menjadi `.env`:

```bash
cp .env.example .env
```

Sesuaikan nilai port atau masukkan token bot Telegram jika diperlukan.

### 2. Menjalankan Container

Jalankan container menggunakan Docker Compose:

```bash
docker compose up -d --build
```

Setelah proses selesai, layanan Carik Bot akan aktif dan dapat diakses melalui peramban:

- **Base URL Chatbot:** `http://localhost:8080/carik/`
- **Pemeriksaan Status:** `http://localhost:8080/`

### 3. Memantau Log

Untuk melihat keluaran log container yang sedang berjalan:

```bash
docker compose logs -f
```

### 4. Menghentikan Layanan

Untuk menghentikan layanan:

```bash
docker compose down
```

---

## Struktur Berkas dan Volume

- `config.json` : Berkas konfigurasi utama Carik (token messenger, database, dan parameter sistem).
- `files/nlp/`   : Direktori kamus entitas, intent, dan respons percakapan (SimpleAI FastPlaz).
- `carik_data`   : Volume penyimpanan data runtime.
- `carik_temp`   : Volume penyimpanan berkas sementara (*session & cache*).

Perubahan pada berkas konfigurasi maupun kamus NLP pada host akan langsung tersinkronisasi ke dalam container tanpa memerlukan proses *build* ulang.

---

## Lisensi dan Pengembang

Carik dikembangkan oleh **Luri Darmawan** dan para kontributor komunitas. Informasi selengkapnya mengenai framework FastPlaz dan ekosistem Carik dapat dipelajari pada situs resmi [carik.id](https://carik.id) dan [fastplaz.com](https://fastplaz.com).
