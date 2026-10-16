import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/repositories/seller_repository.dart';
import '../theme/ns_colors.dart';

/// Private store media is fetched through the authenticated repository. Never
/// attach a bearer token to arbitrary merchant-supplied external image URLs.
class NsProductImage extends StatefulWidget {
  const NsProductImage({
    super.key,
    required this.repository,
    this.url,
    this.bytes,
    this.fit = BoxFit.cover,
    this.label = 'Foto produk',
    this.preview = true,
  });
  final SellerRepository repository;
  final String? url;
  final Uint8List? bytes;
  final BoxFit fit;
  final String label;
  final bool preview;
  @override
  State<NsProductImage> createState() => _NsProductImageState();
}

class _NsProductImageState extends State<NsProductImage> {
  Future<Uint8List>? future;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant NsProductImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url ||
        old.bytes != widget.bytes ||
        old.repository != widget.repository)
      load();
  }

  void load({bool retry = false}) {
    future = widget.bytes != null
        ? Future.value(widget.bytes)
        : (widget.url?.isNotEmpty ?? false)
        ? widget.repository.fetchMediaBytes(widget.url!, refresh: retry)
        : null;
  }

  void open() {
    if (!widget.preview || future == null) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(widget.label)),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.7,
              maxScale: 5,
              child: NsProductImage(
                repository: widget.repository,
                url: widget.url,
                bytes: widget.bytes,
                label: widget.label,
                preview: false,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: ColoredBox(
      color: NsColors.surfaceSubtle,
      child: future == null
          ? const Center(
              child: Icon(Icons.image_outlined, color: NsColors.textSecondary),
            )
          : FutureBuilder<Uint8List>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(
                    child: IconButton(
                      tooltip: 'Foto belum dimuat. Ketuk untuk mencoba lagi',
                      onPressed: () => setState(() => load(retry: true)),
                      icon: const Icon(Icons.refresh),
                    ),
                  );
                if (!snapshot.hasData)
                  return const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                return Semantics(
                  button: widget.preview,
                  label:
                      '${widget.label}${widget.preview ? ', ketuk untuk memperbesar' : ''}',
                  child: InkWell(
                    onTap: widget.preview ? open : null,
                    child: Image.memory(
                      snapshot.data!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: widget.fit,
                      cacheWidth: widget.preview ? 700 : null,
                      excludeFromSemantics: true,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('Format foto tidak dapat dibuka.'),
                      ),
                    ),
                  ),
                );
              },
            ),
    ),
  );
}
