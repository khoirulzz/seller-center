import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/ns_colors.dart';
import '../../../core/widgets/ns_widgets.dart';
import '../../../domain/models/seller_models.dart';

/// Direct actions not already represented by the five primary navigation tabs.
class SellerQuickActions extends StatelessWidget {
  const SellerQuickActions({super.key, required this.role});

  final StoreRole role;

  @override
  Widget build(BuildContext context) {
    final actions = <({String label, String icon, String path, bool tab})>[
      if (role.canManageCatalog)
        (label: 'Tambah produk', icon: 'plus', path: '/produk/editor', tab: false),
      if (role.canManageCatalog)
        (label: 'Stok', icon: 'box', path: '/produk?tab=stock', tab: true),
      if (role.canViewCustomersAndAnalytics)
        (label: 'Pelanggan', icon: 'users', path: '/toko/customers', tab: false),
      if (role.canManageSettings)
        (label: 'Penanggung jawab', icon: 'shield', path: '/responsible', tab: false),
      if (role.canManageSettings)
        (label: 'Pengaturan toko', icon: 'settings', path: '/toko/settings', tab: false),
      if (role.canChooseBillingPlan)
        (label: 'Paket & tagihan', icon: 'credit-card', path: '/toko/billing', tab: false),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      key: const Key('seller-quick-actions'),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: NsColors.surfaceCard,
        border: Border.all(color: NsColors.borderDefault),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Akses cepat', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Kelola pekerjaan penting tanpa mencari menu.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NsColors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(1);
              final columns = constraints.maxWidth >= 640
                  ? 6
                  : scale > 1.3 && constraints.maxWidth < 400
                      ? 2
                      : constraints.maxWidth >= 280
                          ? 3
                          : 2;
              const gap = 8.0;
              final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                alignment: WrapAlignment.start,
                spacing: gap,
                runSpacing: 12,
                children: [
                  for (final action in actions)
                    SizedBox(
                      width: tileWidth,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: Key('seller-shortcut-${action.icon}'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            if (action.tab) {
                              context.go(action.path);
                            } else {
                              context.push(action.path);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 6,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 48,
                                  width: 48,
                                  decoration: BoxDecoration(
                                    color: NsColors.surfacePressed,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  alignment: Alignment.center,
                                  child: NsIcon(
                                    action.icon,
                                    color: NsColors.brandAction,
                                    size: 23,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  scale > 1.3 && action.label == 'Penanggung jawab'
                                      ? 'Profil pengelola'
                                      : action.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: NsColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
