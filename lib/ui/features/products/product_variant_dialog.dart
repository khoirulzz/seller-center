import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/seller_models.dart';

/// The route owns its controllers until its reverse transition is complete.
class ProductVariantDialog extends StatefulWidget {
  const ProductVariantDialog({
    super.key,
    this.variant,
    required this.otherSkus,
  });
  final ProductVariant? variant;
  final Set<String> otherSkus;
  @override
  State<ProductVariantDialog> createState() => _ProductVariantDialogState();
}

class _ProductVariantDialogState extends State<ProductVariantDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController sku, label, qty, price;
  late bool active;
  @override
  void initState() {
    super.initState();
    final v = widget.variant;
    sku = TextEditingController(text: v?.sku ?? '');
    label = TextEditingController(text: v?.optionLabel ?? '');
    qty = TextEditingController(text: (v?.stockQty ?? 0).toString());
    price = TextEditingController(text: v?.priceOverrideIdr?.toString() ?? '');
    active = v?.status != 'inactive';
  }

  @override
  void dispose() {
    sku.dispose();
    label.dispose();
    qty.dispose();
    price.dispose();
    super.dispose();
  }

  void submit() {
    if (!form.currentState!.validate()) return;
    final v = widget.variant;
    Navigator.pop(
      context,
      ProductVariant(
        id: v?.id,
        sku: sku.text.trim(),
        optionLabel: label.text.trim(),
        stockQty: int.parse(qty.text),
        reservedQty: v?.reservedQty ?? 0,
        priceOverrideIdr: price.text.isEmpty ? null : int.parse(price.text),
        status: active ? 'active' : 'inactive',
        imageUrl: v?.imageUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.variant == null ? 'Tambah varian' : 'Edit varian'),
        scrollable: true,
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: label,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nama pilihan *',
                  hintText: 'Biru / L',
                  helperText: 'Pilihan yang dilihat pembeli.',
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Isi nama pilihan.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: sku,
                maxLength: 80,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Kode SKU *',
                  hintText: 'BATIK-BIRU-L',
                  helperText: 'Kode unik untuk setiap varian produk ini.',
                ),
                validator: (v) => (v?.trim().isEmpty ?? true)
                    ? 'Isi kode SKU.'
                    : widget.otherSkus.contains(v!.trim().toLowerCase())
                        ? 'SKU sudah digunakan varian lain.'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: qty,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Total stok *',
                  helperText:
                      '${widget.variant?.reservedQty ?? 0} sedang dipesan. Total termasuk stok tersebut.',
                ),
                validator: (v) => (int.tryParse(v ?? '') ?? -1) <
                        (widget.variant?.reservedQty ?? 0)
                    ? 'Stok minimal ${widget.variant?.reservedQty ?? 0}.'
                    : int.parse(v!) > 100000
                        ? 'Stok maksimal 100.000.'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: price,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onFieldSubmitted: (_) => submit(),
                decoration: const InputDecoration(
                  labelText: 'Harga varian (opsional)',
                  prefixText: 'Rp ',
                  helperText: 'Kosongkan untuk memakai harga dasar.',
                ),
                validator: (v) => v!.isNotEmpty &&
                        (int.tryParse(v) == null || int.parse(v) > 1000000000)
                    ? 'Harga maksimal Rp1.000.000.000.'
                    : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Varian aktif'),
                subtitle:
                    const Text('Dapat dipilih pembeli jika produk aktif.'),
                value: active,
                onChanged: (v) => setState(() => active = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(onPressed: submit, child: const Text('Terapkan')),
        ],
      );
}

class StockAmountDialog extends StatefulWidget {
  const StockAmountDialog({
    super.key,
    required this.product,
    required this.variant,
  });
  final Product product;
  final ProductVariant variant;
  @override
  State<StockAmountDialog> createState() => _StockAmountDialogState();
}

class _StockAmountDialogState extends State<StockAmountDialog> {
  late final controller = TextEditingController(
    text: widget.variant.stockQty.toString(),
  );
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Perbarui stok'),
        scrollable: true,
        content: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.product.name} • ${widget.variant.optionLabel}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Total stok baru *',
                  helperText:
                      '${widget.variant.reservedQty} sedang dipesan. Total termasuk stok tersebut.',
                ),
                validator: (v) =>
                    (int.tryParse(v ?? '') ?? -1) < widget.variant.reservedQty
                        ? 'Stok minimal ${widget.variant.reservedQty}.'
                        : int.parse(v!) > 100000
                            ? 'Stok maksimal 100.000.'
                            : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate())
                Navigator.pop(context, int.parse(controller.text));
            },
            child: const Text('Tinjau'),
          ),
        ],
      );
}
