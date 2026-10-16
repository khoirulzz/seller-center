# Audit kesesuaian PRD dan desain — Nalaro Seller Center
**Tanggal:** 17 Oktober 2026  
**Repositori:** `khoirulzz/seller-center` (`main`)  
**Backend pembanding:** `khoirulzz/nalarostore` SHA `115fb6c88c67bcf20631b4613ecc7d28302114fc`  
**Basis spesifikasi:** `PRD-Nalaro-Seller-Center.md` v1.0 dan `desain.md` v1.0 (16 Oktober 2026)

> Status: **pengembangan/beta**, belum layak dinyatakan 100% PRD atau production-ready. Cek Actions commit head paling baru untuk hasil build akhir. Keberhasilan `flutter analyze` dan APK debug tidak membuktikan alur end-to-end, aksesibilitas, atau backend deployment.

## Ringkasan pemeriksaan

| Kelompok | Yang sudah diimplementasikan | Kesenjangan / verifikasi yang masih dibutuhkan |
| --- | --- | --- |
| AUTH-01/02/04/05/06/07 | Firebase REST login/signup/reset, sesi terenkripsi, restore Worker, onboarding toko, switcher dan role guard | AUTH-03 email Android App Links belum diverifikasi domain association; AUTH-08 wizard 5 langkah dan AUTH-09 biometrik P1 belum lengkap |
| HOME-01/02/03/04 | Overview 30 hari, prioritas pending/low stock, quick links, refresh dengan data lama pada store yang sama | HOME-05 collapse header dan recent orders P1; perlu uji visual dan jaringan |
| ORD-01/02/03 | Search nomor/pelanggan, filter, tanggal, pagination, detail item/timeline | ORD-09 swipe reveal dan sticky CTA belum sesuai desain final; beberapa state loading masih spinner |
| ORD-04/05/06/07/08 | Aksi berdasarkan state + role, confirmation sheet, re-fetch sebelum mutasi, penanganan kegagalan | Alasan cancel dan expected-version/idempotency formal ORD-10 butuh NEW-API Worker, tidak boleh dianggap solved oleh header klien |
| PROD-01/02/03/05/06/07/08 | Katalog, multi-variant SKU, status, gambar utama/galeri, multi-image picker, reorder, draft lokal, arsip | PROD-04 crop/rotate interaktif belum ada; aksesibilitas move-up/down belum lengkap; foto varian belum tersimpan oleh Worker meskipun schema menerima `image_url`; crop dan retry item butuh pengujian |
| INV-01/02 | Stok total/available/reserved, riwayat 200 movement server | INV-03/04 reason + expected version **belum didukung endpoint transaksional**; saat ini quick adjust memanfaatkan GET lalu PUT produk, rawan race server |
| ANA-01/02/03/06 | Metrik omzet *paid*, 7/30/custom dates, grafik harian dan CSV via share sheet | ANA-04 backend saat ini mengelompokkan tanggal **UTC**, bukan Asia/Jakarta; aplikasi memberi label UTC agar tidak menipu |
| CUST-01/02/03 | Search dan pagination, ringkasan pembayaran, kontak hanya terlihat saat item dibuka | Audit redaction PII/log dan uji aplikasi telepon/clipboard masih diperlukan |
| SET-01/02/03/04/05/06 | Grouped sections; kontak, shipping, rekening, kebijakan, media upload, readiness produk+stok dan publish confirm | SET-07 domain verification status server dan storefront preview masih belum tersedia di APK; review UX per-section dan dirty guard perlu device QA |
| BILL-01/02/03/04 | Paket, invoice, usage, copy nomor, konfirmasi paket owner-only | BILL-05 pengingat tagihan push memerlukan backend FCM |
| EXP-01/02/03/04 | CSV API berhalaman dengan total bytes cap, file sementara dan OS share sheet | Perlu uji data besar/scan antivirus dan Android scoped storage nyata |
| NOTIF-01 | Menu notifikasi saja; placeholder tanpa angka palsu | **FCM belum siap**: endpoint register/revoke device, event dispatch, store membership check, penyimpanan unread/read sinkron, Android channel dan Firebase native config belum dibuat |
| DESIGN / A11Y | Brave Pink #FF154F, accessible action #D30C3F, official icon, 5-tab shell, tablet NavigationRail, Rupiah id-ID, grafik scrollable | Belum diuji pada 320/360/390/430/600dp, dynamic text, TalkBack, reduce-motion, no-overflow screenshot review, animasi/keyboard visual dan perbandingan dengan referensi desain |

## Kontrak backend yang sudah diperiksa

1. `POST /api/merchant/stores/:sid/orders/:oid/payment` menerima `decision: "verified" | "rejected"`. Nilai UI lama `approve/reject` keliru dan sudah diperbaiki.
2. Publish memerlukan **minimal satu produk aktif dengan stok tersedia**, bank/QRIS, kontak minimal 8 karakter, kebijakan minimal 20 karakter, metode pemenuhan, dan alamat/kontak sesuai mode. Klien sekarang menampilkan pemeriksaan tersebut. **Entitlement** tetap diverifikasi Worker.
3. Foto dikirim sebagai byte JPG/PNG/WebP ke `/api/merchant/stores/:sid/media`, batas 5 MB. Respons dapat berisi URL relatif. Sekalipun foto diunggah, penghapusan orphan R2 belum memiliki API garbage collection.
4. `worker/lib/operations.ts` menyajikan analitik harian `UTC`; jangan menyebut hari lokal Jakarta sampai backend dan filtering disepakati.
5. `worker/lib/catalog.ts` belum memperbarui `image_url` saat menyimpan perubahan varian, sehingga tidak boleh mengklaim fitur foto varian tuntas.
6. Ekspor CSV backend sampai **500 baris per halaman**, klien memotong proses maksimal 20 halaman / 10 MB.

## Gerbang wajib sebelum klaim selesai

1. GitHub Actions commit head terbaru: format, analyzer tanpa error/warning, `flutter test`, APK debug.
2. Integration testing: Firebase login verified/unverified/expired/revoked, 0/1/many stores, account role owner/manager/fulfillment/unknown, pergantian tenant saat request lambat, order double-tap/409/offline.
3. Media & stock testing: JPG/PNG/WebP, ukuran >5 MB, 12 foto, cleanup orphan, item reserved, perubahan stok concurrent, pembayaran paid→fulfillment.
4. UI QA: capture viewport 320/360/390/430/600dp dan tablet, text scale >=1.6, TalkBack, keyboard insets, back gesture, swipe/menu alternatives, warna kontras, reduced motion.
5. Backend NEW-API dan infrastruktur FCM: tabel tokens/notifications, dedupe events, registration/revocation token, permission server, push send provider, authenticated deep links.
6. Android App Links: `assetlinks.json` pada domain resmi, `applicationId` dan fingerprint signing untuk debug/release, validasi link email; Google Play signing, Play Integrity/security/privacy review, crash reporting dan telemetry yang tidak mengirim PII.
7. Uji integrasi pada environment beta terpisah sebelum menghubungkan aksi mutasi ke transaksi produksi.

## Risiko saat ini

- Mengedit varian foto atau mencatat alasan quick stock adjust lewat UI saja **tidak** menyelesaikan kekurangan Worker. Memerlukan perubahan backend transaksional yang kompatibel dengan web.
- Flutter memperbarui UI setelah API sukses, tetapi tanpa end-to-end test cannot assume production deployment is reachable.
- Cakupan tes masih unit level; tidak ada bukti pengujian visual/manual perangkat atau hasil release signing.
- Penggunaan Aiven Free pada beta tidak menjamin SLA atau always-on.
