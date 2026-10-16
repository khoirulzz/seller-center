/// Kamus label status resmi Nalaro Store (`src/live/api.ts`) agar 100% konsisten dengan website.
enum NsSemanticTone {
  neutral,
  success,
  warning,
  danger,
  pink,
}

abstract final class NsStatusDictionary {
  static const Map<String, String> _labels = {
    'draft': 'Draft',
    'published': 'Terbit',
    'paused': 'Dijeda',
    'suspended': 'Ditangguhkan',
    'active': 'Aktif',
    'inactive': 'Nonaktif',
    'archived': 'Diarsipkan',
    'pending': 'Menunggu konfirmasi',
    'confirmed': 'Dikonfirmasi',
    'processing': 'Diproses',
    'completed': 'Selesai',
    'canceled': 'Dibatalkan',
    'expired': 'Kedaluwarsa',
    'unpaid': 'Belum dibayar',
    'paid': 'Dibayar',
    'failed': 'Belum berhasil',
    'refunded': 'Dikembalikan',
    'unfulfilled': 'Belum diproses',
    'packing': 'Dikemas',
    'shipped': 'Dikirim',
    'delivered': 'Terkirim',
    'pickup_ready': 'Siap diambil',
    'picked_up': 'Sudah diambil',
    'trial': 'Masa coba',
    'grace': 'Masa tenggang',
    'past_due': 'Jatuh tempo',
    'overdue': 'Jatuh tempo',
    'monthly': 'Bulanan',
    'yearly': 'Tahunan',
    'initial': 'Stok awal',
    'adjustment': 'Penyesuaian',
    'reserve': 'Reservasi',
    'release': 'Reservasi dilepas',
    'fulfill': 'Penjualan',
    'return': 'Pengembalian',
    'order.create': 'Pesanan diterima',
    'payment.verify': 'Pembayaran terverifikasi',
    'payment.reject': 'Pembayaran perlu diperiksa',
    'order.cancel': 'Pesanan dibatalkan',
    'order.expire': 'Batas pembayaran berakhir',
    'fulfillment.packing': 'Pesanan dikemas',
    'fulfillment.shipped': 'Pesanan dikirim',
    'fulfillment.delivered': 'Pesanan diterima pembeli',
    'fulfillment.pickup_ready': 'Pesanan siap diambil',
    'fulfillment.picked_up': 'Pesanan sudah diambil',
    'owner': 'Pemilik',
    'manager': 'Manajer',
    'fulfillment': 'Staf Pengiriman',
    'pickup': 'Ambil di toko',
    'local_flat': 'Kurir toko',
  };

  static String label(String? rawStatus) {
    if (rawStatus == null || rawStatus.isEmpty) return 'Status diperbarui';
    return _labels[rawStatus] ?? rawStatus;
  }

  static NsSemanticTone tone(String? rawStatus) {
    switch (rawStatus) {
      case 'published':
      case 'active':
      case 'paid':
      case 'confirmed':
      case 'completed':
      case 'delivered':
      case 'picked_up':
      case 'payment.verify':
        return NsSemanticTone.success;
      case 'pending':
      case 'unpaid':
      case 'unfulfilled':
      case 'packing':
      case 'shipped':
      case 'pickup_ready':
      case 'trial':
      case 'grace':
      case 'past_due':
      case 'overdue':
        return NsSemanticTone.warning;
      case 'canceled':
      case 'expired':
      case 'failed':
      case 'suspended':
      case 'payment.reject':
        return NsSemanticTone.danger;
      default:
        return NsSemanticTone.neutral;
    }
  }

  static String iconName(String? rawStatus) {
    switch (tone(rawStatus)) {
      case NsSemanticTone.success:
        return 'check';
      case NsSemanticTone.warning:
        return 'clock';
      case NsSemanticTone.danger:
        return 'alert';
      case NsSemanticTone.pink:
      case NsSemanticTone.neutral:
        return 'info';
    }
  }
}
