import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../domain/models/seller_models.dart';
import '../config/formatters.dart';
import '../config/status_dictionary.dart';
import '../motion/ns_haptics.dart';
import '../theme/ns_colors.dart';
import '../theme/ns_radius.dart';
import '../theme/ns_spacing.dart';
import '../theme/ns_typography.dart';

/// Komponen ikon SVG terpusat dari `assets/icons/{name}.svg` (`desain.md` Bab 4.1).
class NsIcon extends StatelessWidget {
  const NsIcon(
    this.name, {
    super.key,
    this.size = 20,
    this.color,
    this.semanticLabel,
  });

  final String name;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? IconTheme.of(context).color ?? NsColors.textPrimary;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel == null,
      child: SvgPicture.asset(
        'assets/icons/$name.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
        placeholderBuilder: (_) => SizedBox(width: size, height: size),
      ),
    );
  }
}

/// Brand mark asli Nalaro Store dengan aksen Brave Pink.
class NsBrandMark extends StatelessWidget {
  const NsBrandMark({
    super.key,
    this.size = 32,
    this.showLabel = false,
    this.color,
  });

  final double size;
  final bool showLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final badge = Image.asset(
      'assets/brand/nalarostore-mark.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Nalaro Store',
      filterQuality: FilterQuality.medium,
      color: color,
    );
    if (!showLabel) return badge;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(width: NsSpacing.sm),
        Text(
          'nalaro store',
          style: NsTypography.titleSm.copyWith(
            letterSpacing: -0.4,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Tombol utama (`NsPrimaryButton`) menggunakan `brandAction` (#D30C3F) dengan teks putih (kontras 5.39:1).
/// Maksimum satu `NsPrimaryButton` per konteks layar (`desain.md` Bab 7.1 & 7.2).
class NsPrimaryButton extends StatelessWidget {
  const NsPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.iconName,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? iconName;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final button = SizedBox(
      height: NsSpacing.minTouchTarget,
      width: isFullWidth ? double.infinity : null,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: NsColors.brandAction,
          foregroundColor: NsColors.brandOnPrimary,
          disabledBackgroundColor: NsColors.borderDefault,
          disabledForegroundColor: NsColors.textSecondary,
          shape: const RoundedRectangleBorder(borderRadius: NsRadius.control),
          padding: const EdgeInsets.symmetric(horizontal: NsSpacing.lg),
          elevation: 0,
        ),
        onPressed: enabled
            ? () {
                NsHaptics.selection();
                onPressed?.call();
              }
            : null,
        child: isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: NsColors.brandOnPrimary,
                    ),
                  ),
                  const SizedBox(width: NsSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: NsTypography.label.copyWith(
                        color: NsColors.brandOnPrimary,
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (iconName != null) ...[
                    NsIcon(
                      iconName!,
                      size: 18,
                      color: enabled
                          ? NsColors.brandOnPrimary
                          : NsColors.textSecondary,
                    ),
                    const SizedBox(width: NsSpacing.xs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: NsTypography.label.copyWith(
                        color: enabled
                            ? NsColors.brandOnPrimary
                            : NsColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
    return button;
  }
}

/// Tombol sekunder permukaan putih dengan border halus (`NsSecondaryButton`).
class NsSecondaryButton extends StatelessWidget {
  const NsSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.iconName,
    this.isDestructive = false,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? iconName;
  final bool isDestructive;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final fgColor =
        isDestructive ? NsColors.statusDangerText : NsColors.textPrimary;
    final borderColor =
        isDestructive ? NsColors.statusDangerBorder : NsColors.borderDefault;

    return SizedBox(
      height: NsSpacing.minTouchTarget,
      width: isFullWidth ? double.infinity : null,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: fgColor,
          backgroundColor: NsColors.surfaceCard,
          side: BorderSide(color: borderColor),
          shape: const RoundedRectangleBorder(borderRadius: NsRadius.control),
          padding: const EdgeInsets.symmetric(horizontal: NsSpacing.md),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconName != null) ...[
              NsIcon(iconName!, size: 17, color: fgColor),
              const SizedBox(width: NsSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: NsTypography.label.copyWith(color: fgColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol teks ringkas (`NsTextAction`).
class NsTextAction extends StatelessWidget {
  const NsTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.iconName,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? iconName;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? NsColors.brandAction;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: NsSpacing.minTouchTarget),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: NsSpacing.sm),
          shape: const RoundedRectangleBorder(borderRadius: NsRadius.control),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconName != null) ...[
              NsIcon(iconName!, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(label, style: NsTypography.label.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}

/// Tombol ikon dengan area sentuh minimal 48x48 dp dan label semantik wajib (`NsIconButton`).
class NsIconButton extends StatelessWidget {
  const NsIconButton({
    super.key,
    required this.iconName,
    required this.semanticLabel,
    required this.onPressed,
    this.badgeCount = 0,
    this.color = NsColors.textPrimary,
    this.badgeBackgroundColor = NsColors.brandAction,
    this.badgeForegroundColor = Colors.white,
  });

  final String iconName;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final int badgeCount;
  final Color color;
  final Color badgeBackgroundColor;
  final Color badgeForegroundColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: badgeCount > 0
          ? '$semanticLabel, $badgeCount belum dibaca'
          : semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: InkWell(
          borderRadius: NsRadius.control,
          onTap: onPressed,
          child: SizedBox(
            width: NsSpacing.minTouchTarget,
            height: NsSpacing.minTouchTarget,
            child: Stack(
              alignment: Alignment.center,
              children: [
                NsIcon(iconName, size: 21, color: color),
                if (badgeCount > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBackgroundColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: const TextStyle(
                          color: badgeForegroundColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Input field bertop-label dengan validasi inline (`NsInputField`).
class NsInputField extends StatelessWidget {
  const NsInputField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.helperText,
    this.errorText,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.readOnly = false,
    this.enabled = true,
    this.suffix,
    this.onChanged,
    this.inputFormatters,
    this.textInputAction,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final bool readOnly;
  final bool enabled;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: NsTypography.label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          readOnly: readOnly,
          enabled: enabled,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          style: NsTypography.bodyMd.copyWith(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hintText,
            errorText:
                (errorText != null && errorText!.isNotEmpty) ? errorText : null,
            suffixIcon: suffix,
          ),
        ),
        if (helperText != null &&
            helperText!.isNotEmpty &&
            (errorText == null || errorText!.isEmpty)) ...[
          const SizedBox(height: 5),
          Text(helperText!, style: NsTypography.caption),
        ],
      ],
    );
  }
}

/// Field pencarian dengan leading icon, clear button, dan loading indicator (`NsSearchField`).
class NsSearchField extends StatelessWidget {
  const NsSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.isLoading = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: NsTypography.bodyMd.copyWith(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Padding(
              padding: EdgeInsets.all(13),
              child: NsIcon('search', size: 18, color: NsColors.textSecondary),
            ),
            suffixIcon: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : value.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Bersihkan pencarian',
                        onPressed: () {
                          controller.clear();
                          onChanged('');
                          onClear?.call();
                        },
                        icon: const NsIcon(
                          'close',
                          size: 16,
                          color: NsColors.textSecondary,
                        ),
                      )
                    : null,
          ),
        );
      },
    );
  }
}

/// Label status yang selalu memadukan teks + ikon semantik (`NsStatusLabel`).
/// Tidak pernah mengandalkan warna saja (`desain.md` Bab 2.1 & 7.1).
class NsStatusLabel extends StatelessWidget {
  const NsStatusLabel({
    super.key,
    required this.statusCode,
    this.customText,
  });

  final String statusCode;
  final String? customText;

  @override
  Widget build(BuildContext context) {
    final tone = NsStatusDictionary.tone(statusCode);
    final text = customText ?? NsStatusDictionary.label(statusCode);
    final iconName = NsStatusDictionary.iconName(statusCode);

    Color bg;
    Color fg;
    Color border;
    switch (tone) {
      case NsSemanticTone.success:
        bg = NsColors.statusSuccessBg;
        fg = NsColors.statusSuccessText;
        border = NsColors.statusSuccessBorder;
      case NsSemanticTone.warning:
        bg = NsColors.statusWarningBg;
        fg = NsColors.statusWarningText;
        border = NsColors.statusWarningBorder;
      case NsSemanticTone.danger:
        bg = NsColors.statusDangerBg;
        fg = NsColors.statusDangerText;
        border = NsColors.statusDangerBorder;
      case NsSemanticTone.pink:
        bg = NsColors.surfacePressed;
        fg = NsColors.brandAction;
        border = NsColors.brandPrimary;
      case NsSemanticTone.neutral:
        bg = NsColors.statusNeutralBg;
        fg = NsColors.statusNeutralText;
        border = NsColors.statusNeutralBorder;
    }

    return Semantics(
      label: 'Status: $text',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: NsRadius.chip,
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NsIcon(iconName, size: 13, color: fg),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: NsTypography.bodySm.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu angka KPI tenang tanpa dekorasi berlebihan (`NsKpiTile`).
class NsKpiTile extends StatelessWidget {
  const NsKpiTile({
    super.key,
    required this.label,
    required this.value,
    this.periodCaption,
    this.onTap,
  });

  final String label;
  final String value;
  final String? periodCaption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NsColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: NsRadius.card,
        side: const BorderSide(color: NsColors.borderDefault),
      ),
      child: InkWell(
        borderRadius: NsRadius.card,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(NsSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: NsTypography.bodySm),
              const SizedBox(height: 6),
              Text(value, style: NsTypography.metric),
              if (periodCaption != null) ...[
                const SizedBox(height: 4),
                Text(periodCaption!, style: NsTypography.caption),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris navigasi atau menu ringkas (`NsListRow`).
class NsListRow extends StatelessWidget {
  const NsListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  final String title;
  final String? subtitle;
  final String? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final fg = isDestructive ? NsColors.statusDangerText : NsColors.textPrimary;
    return Material(
      color: NsColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: NsRadius.card,
        side: const BorderSide(color: NsColors.borderDefault),
      ),
      child: InkWell(
        borderRadius: NsRadius.card,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NsSpacing.md,
              vertical: NsSpacing.sm,
            ),
            child: Row(
              children: [
                if (leadingIcon != null) ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDestructive
                          ? NsColors.statusDangerBg
                          : NsColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: NsIcon(leadingIcon!, size: 18, color: fg),
                  ),
                  const SizedBox(width: NsSpacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: NsTypography.bodyLg.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: NsTypography.bodySm),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    const NsIcon(
                      'chevron-right',
                      size: 18,
                      color: NsColors.textMuted,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu pesanan (`NsOrderCard`) dengan aksi kontekstual dan menu titik tiga aksesibel (`desain.md` Bab 8.5).
class NsOrderCard extends StatelessWidget {
  const NsOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onQuickAction,
    this.quickActionLabel,
  });

  final OrderModel order;
  final VoidCallback onTap;
  final VoidCallback? onQuickAction;
  final String? quickActionLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NsColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: NsRadius.card,
        side: const BorderSide(color: NsColors.borderDefault),
      ),
      child: InkWell(
        borderRadius: NsRadius.card,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(NsSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: NsTypography.titleSm,
                    ),
                  ),
                  Text(
                    NsFormatters.shortDate(order.createdAt),
                    style: NsTypography.caption,
                  ),
                  if (onQuickAction != null && quickActionLabel != null)
                    PopupMenuButton<String>(
                      tooltip: 'Tindakan pesanan ${order.orderNumber}',
                      onSelected: (_) => onQuickAction?.call(),
                      itemBuilder: (_) => [
                        PopupMenuItem<String>(
                          value: 'action',
                          child: Text(quickActionLabel!),
                        ),
                      ],
                      icon: const NsIcon(
                        'sliders',
                        size: 17,
                        color: NsColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: NsSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName,
                          style: NsTypography.bodyLg.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            NsStatusLabel(statusCode: order.paymentStatus),
                            NsStatusLabel(statusCode: order.fulfillmentStatus),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: NsSpacing.sm),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        NsFormatters.rupiah(order.totalIdr),
                        style: NsTypography.titleSm.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const NsIcon(
                        'chevron-right',
                        size: 16,
                        color: NsColors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu produk (`NsProductCard`) dengan thumbnail 64x76 dp, stok, status, dan menu aksi setara swipe (`desain.md` Bab 8.7).
class NsProductCard extends StatelessWidget {
  const NsProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    this.onArchive,
    this.lowStockThreshold = 5,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback? onArchive;
  final int lowStockThreshold;

  @override
  Widget build(BuildContext context) {
    final available = product.totalAvailableStock;
    final isLowStock =
        product.status == 'active' && available <= lowStockThreshold;

    return Material(
      color: NsColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: NsRadius.card,
        side: const BorderSide(color: NsColors.borderDefault),
      ),
      child: InkWell(
        borderRadius: NsRadius.card,
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(NsSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 76,
                decoration: BoxDecoration(
                  color: NsColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: NsColors.borderDefault),
                ),
                alignment: Alignment.center,
                child: const NsIcon(
                  'box',
                  size: 22,
                  color: NsColors.textSecondary,
                ),
              ),
              const SizedBox(width: NsSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NsTypography.titleSm,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${product.category} · ${product.variants.length} varian',
                      style: NsTypography.bodySm,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          NsFormatters.rupiah(product.effectiveCatalogPriceIdr),
                          style: NsTypography.bodyLg.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        NsStatusLabel(statusCode: product.status),
                        Text(
                          '$available tersedia',
                          style: NsTypography.bodySm.copyWith(
                            color: isLowStock
                                ? NsColors.statusWarningText
                                : NsColors.textSecondary,
                            fontWeight:
                                isLowStock ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opsi produk ${product.name}',
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'archive') onArchive?.call();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('Edit produk'),
                  ),
                  if (onArchive != null && product.status != 'archived')
                    const PopupMenuItem<String>(
                      value: 'archive',
                      child: Text('Arsipkan produk'),
                    ),
                ],
                icon: const NsIcon(
                  'edit',
                  size: 18,
                  color: NsColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stepper inventaris lokal (`NsInventoryStepper`) yang tidak memanggil server sebelum konfirmasi (`desain.md` Bab 7.4).
class NsInventoryStepper extends StatelessWidget {
  const NsInventoryStepper({
    super.key,
    required this.value,
    required this.minValue,
    required this.onChanged,
    this.maxValue = 100000,
  });

  final int value;
  final int minValue;
  final int maxValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NsColors.surfaceSubtle,
        borderRadius: NsRadius.control,
        border: Border.all(color: NsColors.borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NsIconButton(
            iconName: 'minus',
            semanticLabel: 'Kurangi jumlah stok lokal',
            onPressed: value > minValue
                ? () {
                    NsHaptics.selection();
                    onChanged(value - 1);
                  }
                : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: NsTypography.titleMd.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          NsIconButton(
            iconName: 'plus',
            semanticLabel: 'Tambah jumlah stok lokal',
            onPressed: value < maxValue
                ? () {
                    NsHaptics.selection();
                    onChanged(value + 1);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

/// Empty state tenang dengan ikon lembut, 1 baris judul, 1-2 baris panduan, dan CTA opsional (`NsEmptyState`).
class NsEmptyState extends StatelessWidget {
  const NsEmptyState({
    super.key,
    required this.iconName,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final String iconName;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NsSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: NsColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NsColors.borderDefault),
              ),
              alignment: Alignment.center,
              child: NsIcon(iconName, size: 26, color: NsColors.textSecondary),
            ),
            const SizedBox(height: NsSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: NsTypography.titleSm,
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: NsTypography.bodyMd.copyWith(
                color: NsColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: NsSpacing.md),
              NsSecondaryButton(
                label: actionLabel!,
                iconName: 'plus',
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Panel error inline dengan opsi Coba lagi (`NsInlineError`).
class NsInlineError extends StatelessWidget {
  const NsInlineError({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(NsSpacing.md),
        decoration: BoxDecoration(
          color: NsColors.statusDangerBg,
          borderRadius: NsRadius.card,
          border: Border.all(color: NsColors.statusDangerBorder),
        ),
        child: Row(
          children: [
            const NsIcon(
              'alert',
              size: 20,
              color: NsColors.statusDangerText,
            ),
            const SizedBox(width: NsSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: NsTypography.bodyMd.copyWith(
                  color: NsColors.statusDangerText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: NsSpacing.xs),
              NsTextAction(
                label: 'Coba lagi',
                color: NsColors.statusDangerText,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Strip indikator jaringan offline atau data tersimpan (`NsConnectivityStrip`).
class NsConnectivityStrip extends StatelessWidget {
  const NsConnectivityStrip({
    super.key,
    required this.isOffline,
    this.lastUpdatedText,
    this.onRetry,
  });

  final bool isOffline;
  final String? lastUpdatedText;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: NsSpacing.md,
        vertical: NsSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: NsColors.statusWarningBg,
        border: Border(
          bottom: BorderSide(color: NsColors.statusWarningBorder),
        ),
      ),
      child: Row(
        children: [
          const NsIcon('info', size: 16, color: NsColors.statusWarningText),
          const SizedBox(width: NsSpacing.xs),
          Expanded(
            child: Text(
              lastUpdatedText != null
                  ? 'Koneksi terputus. Menampilkan data terakhir ($lastUpdatedText).'
                  : 'Koneksi terputus. Menampilkan data terakhir.',
              style: NsTypography.bodySm.copyWith(
                color: NsColors.statusWarningText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onRetry != null)
            NsTextAction(
              label: 'Coba lagi',
              color: NsColors.statusWarningText,
              onPressed: onRetry,
            ),
        ],
      ),
    );
  }
}

/// Skeleton loading sesuai geometri kartu sebenarnya (`NsSkeleton`).
class NsSkeleton extends StatelessWidget {
  const NsSkeleton({
    super.key,
    this.height = 76,
    this.width = double.infinity,
  });

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: NsColors.surfaceSubtle,
        borderRadius: NsRadius.card,
        border: Border.all(color: NsColors.borderDefault),
      ),
    );
  }
}

/// Sheet konfirmasi tindakan penting/irreversible (`NsConfirmSheet`) sesuai `desain.md` Bab 5.5 & 8.6.
Future<bool?> showNsConfirmSheet({
  required BuildContext context,
  required String title,
  required String description,
  required String confirmLabel,
  String cancelLabel = 'Batal',
  bool isDestructive = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          left: NsSpacing.lg,
          right: NsSpacing.lg,
          top: NsSpacing.md,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + NsSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: NsColors.borderDefault,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: NsSpacing.md),
            Text(title, style: NsTypography.titleMd),
            const SizedBox(height: NsSpacing.xs),
            Text(
              description,
              style: NsTypography.bodyMd.copyWith(
                color: NsColors.textSecondary,
              ),
            ),
            const SizedBox(height: NsSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: NsSecondaryButton(
                    label: cancelLabel,
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                  ),
                ),
                const SizedBox(width: NsSpacing.sm),
                Expanded(
                  child: isDestructive
                      ? NsSecondaryButton(
                          label: confirmLabel,
                          isDestructive: true,
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                        )
                      : NsPrimaryButton(
                          label: confirmLabel,
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                        ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
