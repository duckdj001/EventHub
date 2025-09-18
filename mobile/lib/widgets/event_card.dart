import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';

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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Обложка
              SizedBox(
                width: 86,
                height: 86,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: e.coverUrl != null && e.coverUrl!.isNotEmpty
                      ? Image.network(e.coverUrl!, fit: BoxFit.cover)
                      : Container(
                          color: const Color(0xFFEFF2F7),
                          child: const Icon(Icons.image_outlined, size: 28, color: Colors.black38),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Текстовая часть
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // верхняя строка: заголовок + цена
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9F0FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _priceText,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (e.owner != null)
                      GestureDetector(
                        onTap: onOwnerTap,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: const Color(0xFFEFF2F7),
                                backgroundImage: (e.owner!.avatarUrl != null && e.owner!.avatarUrl!.isNotEmpty)
                                    ? NetworkImage(e.owner!.avatarUrl!)
                                    : null,
                                child: (e.owner!.avatarUrl == null || e.owner!.avatarUrl!.isEmpty)
                                    ? Text(
                                        e.owner!.fullName.isNotEmpty
                                            ? e.owner!.fullName.characters.first.toUpperCase()
                                            : 'U',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                e.owner!.fullName.isNotEmpty ? e.owner!.fullName : 'Организатор',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: onOwnerTap != null ? Colors.blue : Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // локация + расстояние
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.place_outlined, size: 16, color: Colors.black54),
                            const SizedBox(width: 4),
                            Text(e.city, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                          ],
                        ),
                        if (distance != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.near_me_outlined, size: 16, color: Colors.black54),
                              const SizedBox(width: 4),
                              Text(distance, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // дата
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text(
                          date,
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        if (e.isAdultOnly) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('18+', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),

                    // короткое описание + бейдж «по подтверждению»
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            e.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                        ),
                        if (e.requiresApproval) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6EAF1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'По заявке',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
