import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/formatters.dart';
import '../../../core/errors/ns_error_mapper.dart';
import '../../../core/widgets/ns_form_exit_guard.dart';
import '../../../domain/models/seller_models.dart';
import '../../state/seller_app_state.dart';

class PlatformAdminScreen extends StatelessWidget {
  const PlatformAdminScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Admin platform')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.admin_panel_settings_outlined, size: 64),
            const SizedBox(height: 24),
            Text(
              'Akun admin Nalaro',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(appState.user?.email ?? ''),
            const SizedBox(height: 12),
            const Text(
              'Akun ini tidak menjadi anggota toko. Pengelolaan seluruh toko tersedia melalui dashboard admin web. Setiap akses ke toko dipilih secara eksplisit dan dicatat.',
            ),
            const SizedBox(height: 20),
            SelectableText('${AppConfig.defaultApiBaseUrl}/admin'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: '${AppConfig.defaultApiBaseUrl}/admin'),
                );
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Alamat dashboard admin disalin.'),
                    ),
                  );
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Salin alamat dashboard admin'),
            ),
            TextButton(
              onPressed: appState.signOut,
              child: const Text('Keluar dari akun'),
            ),
          ],
        ),
      );
}

class ResponsibleProfileScreen extends StatefulWidget {
  const ResponsibleProfileScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override
  State<ResponsibleProfileScreen> createState() => _ResponsibleProfileState();
}

class _ResponsibleProfileState extends State<ResponsibleProfileScreen> {
  final form = GlobalKey<FormState>();
  final fields = List.generate(6, (_) => TextEditingController());
  bool loading = true, busy = false, dirty = false;
  String? error;
  String? sid;
  int epoch = 0;
  @override
  void initState() {
    super.initState();
    load();
    widget.appState.addListener(changed);
  }

  void changed() {
    if (sid != widget.appState.activeStore?.id) {
      dirty = false;
      load();
    }
  }

  Future<void> load() async {
    final current = ++epoch;
    sid = widget.appState.activeStore?.id;
    setState(() => loading = true);
    try {
      if (sid == null) return;
      final p = await widget.appState.repository.fetchResponsibleProfile(sid!);
      if (!mounted || current != epoch) return;
      final values = [
        p.fullName,
        p.position,
        p.phone,
        p.email,
        p.birthDate ?? '',
        p.address,
      ];
      for (var i = 0; i < 6; i++) {
        fields[i].text = values[i];
      }
      error = null;
    } catch (e) {
      if (mounted && current == epoch) error = NsErrorMapper.toUserMessage(e);
    } finally {
      if (mounted && current == epoch) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    epoch++;
    widget.appState.removeListener(changed);
    for (final f in fields) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy || sid == null || !form.currentState!.validate()) return;
    final current = epoch;
    setState(() => busy = true);
    try {
      await widget.appState.repository.saveResponsibleProfile(
        sid!,
        ResponsibleProfile(
          fullName: fields[0].text.trim(),
          position: fields[1].text.trim(),
          phone: fields[2].text.trim(),
          email: fields[3].text.trim(),
          birthDate: fields[4].text.isEmpty ? null : fields[4].text,
          address: fields[5].text.trim(),
        ),
      );
      if (!mounted || current != epoch) return;
      setState(() => dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informasi penanggung jawab disimpan.')),
      );
    } catch (e) {
      if (mounted && current == epoch)
        setState(() => error = NsErrorMapper.toUserMessage(e));
    } finally {
      if (mounted && current == epoch) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => NsFormExitGuard(
        dirty: dirty,
        busy: busy,
        confirmExit: () async {
          final leave = await showDialog<bool>(
            context: context,
            builder: (dialog) => AlertDialog(
              title: const Text('Tinggalkan perubahan?'),
              content: const Text('Perubahan profil belum disimpan.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const Text('Lanjut mengisi'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('Tinggalkan'),
                ),
              ],
            ),
          );
          if (leave == true && mounted) setState(() => dirty = false);
          return leave == true;
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Penanggung jawab')),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: form,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        'Profil pribadi untuk operasional toko. Hanya pemilik dan manager yang dapat mengakses informasi ini.',
                      ),
                      const SizedBox(height: 20),
                      for (var i = 0; i < 6; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextFormField(
                            controller: fields[i],
                            enabled: !busy && i != 4,
                            maxLength: i == 5
                                ? 2000
                                : i == 0
                                    ? 120
                                    : i == 1
                                        ? 80
                                        : i == 2
                                            ? 25
                                            : i == 3
                                                ? 254
                                                : 10,
                            maxLines: i == 5 ? 3 : 1,
                            keyboardType: i == 2
                                ? TextInputType.phone
                                : i == 3
                                    ? TextInputType.emailAddress
                                    : TextInputType.text,
                            decoration: InputDecoration(
                              labelText: [
                                'Nama lengkap',
                                'Jabatan',
                                'Nomor telepon',
                                'Email operasional (opsional)',
                                'Tanggal lahir (opsional)',
                                'Alamat operasional',
                              ][i],
                            ),
                            onChanged: (_) => setState(() => dirty = true),
                            validator: (value) {
                              final v = (value ?? '').trim();
                              if ((i == 0 || i == 1) && v.length < 2)
                                return 'Isi minimal 2 karakter.';
                              if (i == 2 &&
                                  !RegExp(r'^[+0-9 ()-]{8,25}$').hasMatch(v))
                                return 'Nomor telepon tidak valid.';
                              if (i == 3 &&
                                  v.isNotEmpty &&
                                  !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(v)) return 'Email tidak valid.';
                              return null;
                            },
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      DateTime.tryParse(fields[4].text) ??
                                          DateTime(1990),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime.now(),
                                );
                                if (d != null && mounted)
                                  setState(() {
                                    fields[4].text =
                                        NsFormatters.calendarDate(d);
                                    dirty = true;
                                  });
                              },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text('Pilih tanggal lahir'),
                      ),
                      if (fields[4].text.isNotEmpty)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                    fields[4].clear();
                                    dirty = true;
                                  }),
                          child: const Text('Hapus tanggal lahir'),
                        ),
                      if (DateTime.tryParse(fields[4].text)
                          case final DateTime birth)
                        Text(
                          'Umur: ${DateTime.now().year - birth.year - ((DateTime.now().month < birth.month || (DateTime.now().month == birth.month && DateTime.now().day < birth.day)) ? 1 : 0)} tahun',
                        ),
                      if (error != null)
                        Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: busy ? null : save,
                        child: Text(busy ? 'Menyimpan…' : 'Simpan informasi'),
                      ),
                    ],
                  ),
                ),
        ),
      );
}

class CustomerChatScreen extends StatefulWidget {
  const CustomerChatScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override
  State<CustomerChatScreen> createState() => _CustomerChatState();
}

class _CustomerChatState extends State<CustomerChatScreen>
    with WidgetsBindingObserver {
  Timer? timer;
  bool foreground = true,
      loading = true,
      polling = false,
      sending = false,
      olderBusy = false,
      hasMore = false;
  String? sid, cid, error, pendingId, pendingBody;
  int epoch = 0;
  List<CustomerConversation> conversations = [];
  List<CustomerMessage> messages = [];
  final composer = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.appState.addListener(changed);
    sid = widget.appState.activeStore?.id;
    refresh();
  }

  void changed() {
    if (sid != widget.appState.activeStore?.id) {
      epoch++;
      timer?.cancel();
      sid = widget.appState.activeStore?.id;
      cid = null;
      conversations = [];
      messages = [];
      composer.clear();
      refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) {
      refresh();
    } else {
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    epoch++;
    timer?.cancel();
    widget.appState.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    composer.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    timer?.cancel();
    if (polling || !foreground || sid == null) return;
    polling = true;
    final current = epoch, store = sid!, conversation = cid;
    try {
      final list = await widget.appState.repository.fetchConversations(store);
      ChatMessagesBundle? data;
      if (conversation != null)
        data = await widget.appState.repository.fetchChatMessages(
          store,
          conversation,
        );
      if (!mounted || current != epoch) return;
      setState(() {
        conversations = list;
        if (data != null) {
          final merged = {
            for (final m in messages) m.id: m,
            for (final m in data.messages) m.id: m,
          };
          messages = merged.values.toList()
            ..sort((a, b) {
              final cmp = a.createdAt.compareTo(b.createdAt);
              return cmp == 0 ? a.id.compareTo(b.id) : cmp;
            });
          if (messages.length <= 50) hasMore = data.hasMore;
        }
        loading = false;
        error = null;
      });
      if (conversation != null &&
          data != null &&
          data.messages.isNotEmpty &&
          foreground)
        await widget.appState.repository.markChatRead(
          store,
          conversation,
          data.messages.last.id,
        );
    } catch (e) {
      if (mounted && current == epoch)
        setState(() {
          error = NsErrorMapper.toUserMessage(e);
          loading = false;
        });
    } finally {
      polling = false;
      if (mounted && foreground)
        timer = Timer(const Duration(seconds: 8), refresh);
    }
  }

  Future<void> send() async {
    if (sending || cid == null || sid == null || composer.text.trim().isEmpty)
      return;
    final current = epoch, text = composer.text.trim();
    pendingId = pendingBody == text ? pendingId : _uuid();
    pendingBody = text;
    setState(() => sending = true);
    try {
      await widget.appState.repository.sendChatMessage(
        sid!,
        cid!,
        text,
        pendingId!,
      );
      if (!mounted || current != epoch) return;
      composer.clear();
      pendingId = null;
      pendingBody = null;
      await refresh();
    } catch (e) {
      if (mounted && current == epoch)
        setState(() => error = NsErrorMapper.toUserMessage(e));
    } finally {
      if (mounted && current == epoch) setState(() => sending = false);
    }
  }

  Future<void> older() async {
    if (messages.isEmpty || sid == null || cid == null) return;
    final current = epoch;
    setState(() => olderBusy = true);
    try {
      final data = await widget.appState.repository.fetchChatMessages(
        sid!,
        cid!,
        before: messages.first.id,
      );
      if (!mounted || current != epoch) return;
      setState(() {
        messages = [...data.messages, ...messages];
        hasMore = data.hasMore;
      });
    } catch (e) {
      if (mounted && current == epoch)
        setState(() => error = NsErrorMapper.toUserMessage(e));
    } finally {
      if (mounted && current == epoch) setState(() => olderBusy = false);
    }
  }

  void choose(String? id) {
    epoch++;
    timer?.cancel();
    setState(() {
      cid = id;
      messages = [];
      hasMore = false;
      composer.clear();
      pendingId = null;
      pendingBody = null;
      error = null;
      loading = true;
      sending = false;
    });
    refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
            cid == null
                ? 'Chat pelanggan'
                : conversations
                        .where((c) => c.id == cid)
                        .firstOrNull
                        ?.customerName ??
                    'Percakapan',
          ),
          leading:
              cid == null ? null : BackButton(onPressed: () => choose(null)),
        ),
        body: Column(
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (loading) const LinearProgressIndicator(),
            Expanded(
              child: cid == null
                  ? RefreshIndicator(
                      onRefresh: refresh,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (!loading && conversations.isEmpty)
                            const ListTile(
                              title: Text('Belum ada percakapan'),
                              subtitle: Text(
                                'Pembeli dapat menghubungi toko melalui tombol Chat toko di web.',
                              ),
                            ),
                          for (final c in conversations)
                            Card(
                              child: ListTile(
                                title: Text(c.customerName),
                                subtitle: Text(
                                  '${c.productName.isEmpty ? '' : '${c.productName} · '}${c.lastMessage}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: c.unread > 0
                                    ? Badge(label: Text('${c.unread}'))
                                    : null,
                                onTap: () => choose(c.id),
                              ),
                            ),
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'Menampilkan hingga 100 percakapan terbaru. Diperbarui saat aplikasi aktif.',
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (hasMore)
                          TextButton(
                            onPressed: olderBusy ? null : older,
                            child: const Text('Muat pesan sebelumnya'),
                          ),
                        for (final m in messages)
                          Align(
                            alignment: m.senderKind == 'seller'
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * .82,
                              ),
                              decoration: BoxDecoration(
                                color: m.senderKind == 'seller'
                                    ? const Color(0xFFFFE5EE)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectableText(m.body),
                                  const SizedBox(height: 6),
                                  Text(
                                    NsFormatters.dateTime(m.createdAt),
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            if (cid != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final text in [
                              'Halo, ada yang bisa kami bantu?',
                              'Pesanan sedang kami periksa.',
                              'Terima kasih sudah berbelanja.',
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ActionChip(
                                  label: Text(text),
                                  onPressed: sending
                                      ? null
                                      : () {
                                          composer.text = text;
                                        },
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: composer,
                              enabled: !sending,
                              maxLength: 4000,
                              minLines: 1,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Pesan',
                                counterText: '',
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: sending ? null : send,
                            tooltip: 'Kirim pesan',
                            icon: sending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(),
                                  )
                                : const Icon(Icons.send_outlined),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}

String _uuid() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class MerchantNotificationsScreen extends StatefulWidget {
  const MerchantNotificationsScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override
  State<MerchantNotificationsScreen> createState() =>
      _MerchantNotificationsState();
}

class _MerchantNotificationsState extends State<MerchantNotificationsScreen> {
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      await widget.appState.refreshNotifications();
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) setState(() => error = NsErrorMapper.toUserMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Notifikasi'),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  await widget.appState.repository.markAllNotificationsRead();
                  await load();
                } catch (e) {
                  if (mounted)
                    setState(() => error = NsErrorMapper.toUserMessage(e));
                }
              },
              child: const Text('Baca semua'),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (loading) const LinearProgressIndicator(),
              if (error != null) Text(error!),
              if (!loading &&
                  widget.appState.repository.getNotificationsForUser().isEmpty)
                const ListTile(title: Text('Belum ada notifikasi operasional')),
              for (final n
                  in widget.appState.repository.getNotificationsForUser())
                Card(
                  child: ListTile(
                    leading: Icon(
                      n.isRead
                          ? Icons.notifications_none
                          : Icons.notifications_active_outlined,
                    ),
                    title: Text(n.title),
                    subtitle: Text(
                      '${n.summary}\n${NsFormatters.dateTime(n.createdAt)}',
                    ),
                    isThreeLine: true,
                    onTap: () async {
                      try {
                        await widget.appState.repository
                            .markNotificationRead(n.id);
                        if (!context.mounted) return;
                        context.push(
                          n.resourceType == 'chat'
                              ? '/chat'
                              : n.resourceType == 'inventory'
                                  ? '/produk?tab=inventory'
                                  : '/pesanan',
                        );
                      } catch (e) {
                        if (mounted)
                          setState(
                              () => error = NsErrorMapper.toUserMessage(e));
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      );
}

class NotificationPoller extends StatefulWidget {
  const NotificationPoller({
    super.key,
    required this.appState,
    required this.child,
  });
  final SellerAppState appState;
  final Widget child;
  @override
  State<NotificationPoller> createState() => _NotificationPollerState();
}

class _NotificationPollerState extends State<NotificationPoller>
    with WidgetsBindingObserver {
  Timer? timer;
  bool foreground = true, polling = false;
  String? sid;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.appState.addListener(changed);
    schedule();
  }

  void changed() {
    if (sid != widget.appState.activeStore?.id) schedule();
  }

  void schedule() {
    timer?.cancel();
    sid = widget.appState.activeStore?.id;
    timer = Timer(Duration.zero, poll);
  }

  Future<void> poll() async {
    if (!foreground || polling) return;
    polling = true;
    try {
      await widget.appState.refreshNotifications();
    } catch (_) {
      /* Existing data stays visible until the next foreground refresh. */
    } finally {
      polling = false;
      if (mounted && foreground) {
        timer?.cancel();
        timer = Timer(const Duration(seconds: 30), poll);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground)
      schedule();
    else
      timer?.cancel();
  }

  @override
  void dispose() {
    timer?.cancel();
    widget.appState.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
