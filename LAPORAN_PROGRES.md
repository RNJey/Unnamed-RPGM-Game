# Laporan Progres Proyek: SQL Vault (`Escape the Database`)

Dokumen ini merangkum status lengkap proyek **`SQL Vault Released v.0.1`** (`Godot 4.7.2`) dibandingkan folder awal (**`SQL Vault pre-release`**), agar seluruh anggota tim dapat melihat **fitur & fase yang sudah selesai** serta **hal yang masih ditahan (belum dijalankan)**.

> Catatan: Folder referensi `SQL Vault pre-release` tetap utuh dan tidak pernah dimodifikasi.

---

## Ringkasan Status Fase Keseluruhan

| Fase | Judul & Ruang Lingkup | Status | Persentase |
| :--- | :--- | :---: | :---: |
| **Baseline (§3)** | Setup 8 Scene Lantai/Rahasia, Player Animasi 4 Arah, Wall Collision Penuh, 15 Pintu Solid & Return Spawn, 11 Tuas, Teks Tajam, Layar Maximized | **SELESAI** | **100%** |
| **Fase 0** | 0.1 Audit Keterjangkauan Peta (Flood-Fill Fisika) & 0.2 Layar Ending Lantai 5 (`ending.tscn`) | **SELESAI** | **100%** |
| **Fase 1** | 1.1 `ExplorationHUD` (Bar HP `100/100`, Energi, Koin, Kristal, Kunci, Ramuan `[H]`, XP, Tuas), 1.2 Prompt Tuas, 1.3 `Breakable_Box` & Persistensi | **SELESAI** | **100%** |
| **Fase 2** | Engine SQL (`DDL → DML → DCL`), Judge, 25 Test Sandbox, Modal `BengkelQueryUI` (Kartu Hint bertahap & Auto Energy Chip), 11 `SQLTerminal`, Gating Tuas | **SELESAI** | **100%** |
| **Fase 3** | Pedagang Lantai 1 & 3, `ShopUI` (Upgrade, Ramuan HP, Tempa Kristal `+10 Max HP & +2 Max Energi`), Kunci & 3 Pintu Rahasia Terkunci | **SELESAI** | **100%** |
| **Fase 4** | 5 Jenis Musuh Patroli (Anti-Tersangkut Tembok + FOV Chase + Cooldown Serang + I-Frames), `GameOverUI`, NPC `Hikari` / `King Jey` / `Mikael`, Toko Rahasia `Trader` | **SELESAI** | **100%** |
| **Fase 5** | `MainMenu` (`Lanjutkan`, `Mulai Baru`, `Pilih Lantai`), Halaman `TENTANG` (`about.tscn`), `AchievementsModal` (8 Pencapaian), `PauseMenu`, `SettingsModal`, Save/Load `user://save.cfg` | **SELESAI** | **100%** |
| **Fase 6** | 4 BGM CC0 + 10 SFX (`AudioManager` + Pemilih BGM di Settings), `README.md`, **Export Windows `.exe`** *(Export ditahan sesuai permintaan)* | **SELESAI KECUALI EXPORT** | **67%** |

---

## Bagian 1 — Daftar Fitur & Fase yang SUDAH Selesai

### 1. Fondasi Peta, Player, & Sistem Inti (Baseline & Fase 0–1)
- **8 Scene Terhubung Bolak-Balik**:
  - Lantai utama: `floor_1_dungeon.tscn`, `floor_2_dungeon.tscn`, `floor_3_catacomb.tscn`, `floor_4_catacomb.tscn`, `floor_5_ground.tscn`
  - Ruang rahasia: `floor_2_secret.tscn`, `floor_3_secret1.tscn`, `floor_3_secret2.tscn`
  - Seluruh lantai punya collision dinding (`WallLayer`), `15/15` pintu solid tidak tembus keluar map, dan return spawn akurat saat berpindah antar-lantai.
- **Animasi & Kontrol Player**: Jalan 4 arah (`WASD`/Arrow), serang pedang (`J`/Klik Kiri), interaksi (`E`), serta membaca upgrade `has_speed_boots` (`120 → 170`) dan `sword_upgraded` (damage `1 → 3`).
- **`ExplorationHUD` Atas**:
  - **HP Bar `100/100`** (merah), **Energy Bar SQL `10/10`** (biru), **Koin**, **Syntax Crystal**, **Kunci Rahasia**, **Ramuan HP + tombol `[H]`**, **Rank & XP**, **Counter Tuas**, dan **Toast Pencapaian**.
- **16 Kotak Kayu (`Breakable_Box`) Permanen**: 4 kotak per lantai (Lantai 1–4); yang sudah hancur tercatat di `GameManager.destroyed_box_ids` dan tidak respawn saat pindah lantai.
- **Layar Tamat (`scenes/ui/ending.tscn`)**: Pintu Lantai 5 masuk ke layar ending (`LANTAI 5 SELESAI`) dengan statistik Rank, XP, Koin, Kristal, Waktu Selesai, `[E] Mulai Ulang`, dan `Menu Utama`.

### 2. Sistem Pembelajaran SQL Interaktif (`BengkelQueryUI` & `SQLTerminal`) (Fase 2)
- **11 Terminal SQL di Lantai 1–4 (`data/levels.json`)** berjenjang dari **DDL → DML → DCL**:
  - **Lantai 1 (DDL)**: `CREATE TABLE`, `ALTER TABLE ... ADD COLUMN`
  - **Lantai 2 (DML Dasar)**: `INSERT INTO`, `UPDATE ... SET ... WHERE`, `DELETE FROM ... WHERE`
  - **Lantai 3 (DML Query)**: `SELECT ... WHERE`, `ORDER BY`, agregasi `COUNT` / `SUM` / `AVG` / `MIN` / `MAX`
  - **Lantai 4 (DCL & Multi-Statement)**: `GRANT`, `REVOKE`, gabungan DML + DCL
- **Engine & Judge In-Memory** (`scripts/sql/query_engine.gd`, `query_judge.gd`, 25 test suite lulus `25/25 PASS`).
- **Sistem Hint Kartu Bertahap**:
  - Di atas editor SQL terdapat hingga 4 kartu token bantuan yang awalnya terkunci (`[? Kartu 1..4]`).
  - Menekan tombol **`BUKA 1 KARTU (-1)`** memakai **1 Hint Token** untuk membuka **1 kartu bantuan** secara berurutan per klik (tersimpan per terminal). Setelah terminal selesai, seluruh kartu terbuka otomatis.
- **Auto Energy Chip & Refill**:
  - Jika Energi SQL habis (`0`), `BengkelQueryUI` otomatis memakai 1 `Energy Chip` (jika tersedia) agar query tetap bisa dijalankan, dan menyelesaikan terminal langsung mengisi penuh Energi SQL.

### 3. Ekonomi, Pedagang Reguler, Toko Rahasia, & Ramuan HP (Fase 3 & 4)
- **Pedagang Reguler (`NPCMerchant` di Lantai 1 & Lantai 3)**:
  - **Pedang Kristal** (`20 Koin`): Damage pedang `1 → 3` & ayunan lebih cepat.
  - **Sepatu Cepat** (`15 Koin`): Kecepatan gerak `120 → 170`.
  - **Kunci Ruang Rahasia** (`10 Koin`): Membuka 3 pintu rahasia terkunci (`floor_2_secret`, `floor_3_secret1`, `floor_3_secret2`).
  - **Token Petunjuk SQL** (`5 Koin`): `+1` token untuk membuka 1 kartu bantuan di Terminal SQL.
  - **Ramuan HP (`8 Koin`)**: Disimpan di tas; tekan **`H`** atau klik **`PAKAI [H]`** di HUD kapan saja untuk memulihkan **`+35 HP`**.
  - **Tempa Syntax Crystal (`3 Kristal`)**: Upgrade permanen **`+10 Max HP`** (sekaligus menambah `+10 HP`) & **`+2 Max Energi SQL`** permanen (sekaligus mengisi penuh Energi).
- **Pedagang Rahasia (`Trader` di Lantai 2 Secret Room)**:
  - **Jimat Hati Kuno** (`25 Koin`): `+25 Max HP` permanen & pulihkan `+25 HP`.
  - **Inti Energi Overclock** (`20 Koin`): `+4 Max Energi SQL` permanen & isi penuh Energi.
  - **Bundel 2 Kunci Rahasia** (`15 Koin`): `+2 Kunci Ruang Rahasia`.
  - **Chip Energi Penuh** (`8 Koin`): Mengisi penuh Energi + menyimpan `+1 Energy Chip`.
  - **Bundel 2 Ramuan HP** (`12 Koin`): `+2 Ramuan HP`.
  - **Tempa Kristal Diskon (`2 Kristal`)**: Upgrade permanen **`+10 Max HP & +2 Max Energi SQL`** lebih murah dari toko biasa.

### 4. Musuh, Pertarungan, & Karakter Custom (Fase 4)
- **5 Jenis Musuh Beranimasi (`scripts/enemy.gd`)**:
  - `goblin_scout`, `mushroom_man` (`1 HP`), `goblin_ward`, `skeleton_walker`, `cultist` (`2 HP`).
  - **Patroli Cerdas Anti-Tersangkut Tembok**: Memakai pengecekan raycast 3 jalur & `test_move()` agar musuh otomatis berjalan menjauhi tembok dan tidak diam di sudut.
  - **Deteksi & Serang Adil**: Mengejar jika pemain masuk kerucut penglihatan (*Field of Vision*) tanpa terhalang dinding, cooldown serang `1.5–1.6 detik`, `1.0 detik` i-frame berkedip pada pemain, *hit-stun* (`0.38s`), dan *knockback*.
- **3 Karakter NPC Custom dengan Dialog & Hadiah (`scripts/npc_dialogue.gd` & `scripts/ui/npc_dialogue_modal.gd`)**:
  - **Kotak Dialog Tengah-Bawah (`middle-bottom`)**: Desain panel dialog diletakkan rapi di tengah-bawah layar tanpa menutupi area peta karakter di atasnya.
  - **Hikari (`HIKARI THE ADVENTURER`)** (`scenes/entities/hikari.tscn` di `floor_3_secret1.tscn`): Dapat diajak bicara (`[E]`) — dialog penjelajah rahasia + hadiah **`+25 Koin, +2 Kristal, +2 Hint, +1 Ramuan HP & +75 XP`**.
  - **King Jey (`KING JEY`)** (`scenes/entities/king_jey.tscn` di `floor_3_secret2.tscn`): Dapat diajak bicara (`[E]`) — dialog penguasa ruang rahasia + berkah **`+40 Koin, +3 Kristal, +2 Ramuan HP, +15 Max HP Permanen & +100 XP`**.
  - **Mikael (`MIKAEL BUDI SANTOSA`)** (`scenes/entities/mikael.tscn` di `floor_5_ground.tscn`): **Cutscene Lantai 5 & Pilihan Akhir** — otomatis menyapa pemain saat mendekat (bisa diajak bicara ulang dengan `[E]`), memusatkan kamera tepat ke Mikael selama dialog berlangsung, memberikan penghargaan **`+50 Koin, +5 Kristal, HP/Energi Penuh & +150 XP`**, lalu menampilkan pilihan **`Tamatkan Game (Ke Ending)`** (diiringi fanfare kemenangan `victory.wav`) atau **`Lanjut Eksplorasi Map`** agar pemain bisa langsung menuju Ending maupun tetap bebas menjelajahi dungeon.
- **Game Over Screen (`game_over.tscn`)**: Mengulang lantai saat ini dengan HP penuh tanpa menghapus XP, koin, maupun puzzle yang sudah selesai.

### 5. Menu, Halaman Tentang, Pencapaian, Pengaturan, Save/Load, & Audio (Fase 5 & 6)
- **Main Menu (`main_menu.tscn`)**: `LANJUTKAN`, `MULAI BARU`, `PILIH LANTAI` (terbuka sesuai progres), `PENCAPAIAN`, `PENGATURAN`, `TENTANG`, dan `KELUAR`.
- **Halaman Tentang / Credits (`about.tscn`)**: Profil & foto tim pengembang (`Zacky`, `Fajar`, `Jidan`), dosen pengampu, asisten praktikum, serta kredit aset/engine.
- **Sistem Pencapaian (8 Achievements) & `AchievementsModal`**:
  - Dapat dibuka baik dari **Main Menu** maupun **Pause Menu (`Esc`)**:
    1. `Hello Database!` · 2. `Arsitek Skema (DDL)` · 3. `Operator Data (DML)` · 4. `Detektif Query (SELECT)` · 5. `Penjaga Otorisasi (DCL)` · 6. `Penjelajah Rahasia` · 7. `Penghancur Kotak` (5 kotak) · 8. `Master SQL Vault`.
- **Pause Menu (`Esc`) & Settings Modal**: Mengatur volume Master/BGM/SFX, memilih 3 lagu BGM Dungeon secara langsung (`Opt 5` default, `Opt 3`, `Loopable Ambience`), toggle Fullscreen/Windowed, serta tombol **`HAPUS SEMUA DATA`** (2 klik konfirmasi untuk menghapus save, lantai terbuka & seluruh pencapaian sambil mempertahankan pengaturan audio).
- **Save/Load Otomatis & Manual (`user://save.cfg`)**: Menyimpan progres lantai, stats (`max_hp`, `max_energy`, dll.), inventaris (termasuk Ramuan HP & hint kartu terbuka per terminal), progres dunia, dan pencapaian.
- **Developer Mode (`[F12]` / Pause Menu / Settings)**: Konsol debug global (`scripts/ui/dev_panel_modal.gd`) dengan **God Mode**, **No-Clip (Tembus Tembok)**, **Grant Resources**, **Buka Semua Lantai & Upgrade**, **Auto-Solve SQL & Tuas Lantai**, **Kalahkan Semua Musuh**, **+50 Max HP & Full Refill**, **Buka Semua Pencapaian**, dan **Teleport Instan** ke semua 8 peta, Main Menu, serta layar Ending.
- **Audio CC0 (`AudioManager`)**: 4 BGM loop & 11 SFX aksi (`victory`, `sword`, `box_hit`, `coin`, `lever`, `door`, `query_ok`, `query_error`, `guard_hit`, `achievement`, `ui_confirm`).

---

## Bagian 2 — Yang Sengaja Ditahan / Belum Dikerjakan (Sesuai Instruksi)

1. **Misi SQL / Pertarungan Boss Lantai 5 *(On Hold)***:
   - `mikael.tscn` di Lantai 5 dibuat sebagai NPC **Cutscene ucapan selamat, pemberi hadiah & pilihan akhir (`Tamatkan Game` / `Lanjut Eksplorasi Map`)** (bukan pertarungan boss). Soal final `"5:Lever"` sudah ada di `data/levels.json` beserta track `bgm_boss.ogg` jika nanti ingin menambah tantangan SQL di Lantai 5.
2. **Export Build Windows `.exe` (`Fase 6.3`) *(On Hold)***:
   - `export_presets.cfg` dan paket rilis `build/SQL_Vault.exe` sengaja ditahan sampai seluruh fitur game dinyatakan final sebelum dibuatkan build Windows-nya.
