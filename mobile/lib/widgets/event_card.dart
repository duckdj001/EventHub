import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extension.dart';
import '../theme/components/app_surface.dart';

String _fmtRu(DateTime d) {
  try { return DateFormat('d MMM, HH:mm', 'ru_RU').format(d); }
  catch (_) { return DateFormat('d MMM, HH:mm').format(d); }
}

class EventCard extends StatelessWidget {
  final Event e;
  final VoidCallback onTap;
  final double? distanceKm;
  final VoidCallback? onOwnerTap;

  const EventCard({
    super.key,
    required this.e,
    required this.onTap,
    this.distanceKm,
    this.onOwnerTap,
  });

  String get _priceText {
    if (!e.isPaid) return 'Бесплатно';
    final cur = (e.currency ?? '₽').toUpperCase();
    final sign = (cur == 'RUB' || cur == 'RUR') ? '₽' : cur;
    return e.price != null ? '$sign ${e.price}' : 'Платно';
  }

  @override
  Widget build(BuildContext context) {
    final date = _fmtRu(e.startAt.toLocal());
    final distance =
        distanceKm != null ? '${distanceKm!.toStringAsFixed(distanceKm! < 10 ? 1 : 0)} км' : null;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appExt = theme.extension<AppThemeExtension>();

    return AppSurface(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: appExt?.panelRadius ?? BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: e.coverUrl != null && e.coverUrl!.isNotEmpty
                      ? Image.network(e.coverUrl!, fit: BoxFit.cover)
                      : Container(
                          color: colorScheme.surfaceVariant,
                          child: Icon(Icons.image_outlined, size: 32, color: colorScheme.onSurfaceVariant),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _priceText,
                            style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (e.owner != null)
                      GestureDetector(
                        onTap: onOwnerTap,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: colorScheme.surfaceVariant,
                              backgroundImage: (e.owner!.avatarUrl != null && e.owner!.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(e.owner!.avatarUrl!)
                                  : null,
                              child: (e.owner!.avatarUrl == null || e.owner!.avatarUrl!.isEmpty)
                                  ? Text(
                                      e.owner!.fullName.isNotEmpty
                                          ? e.owner!.fullName.characters.first.toUpperCase()
                                          : 'U',
                                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              e.owner!.fullName.isNotEmpty ? e.owner!.fullName : 'Организатор',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: onOwnerTap != null ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (e.owner != null) const SizedBox(height: 6),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.place_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(e.city, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                        if (distance != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.near_me_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(distance, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(date, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                        if (e.isAdultOnly) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('18+',
                                style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.error, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            e.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        if (e.requiresApproval) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.secondary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'По заявке',
                              style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.secondary, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
