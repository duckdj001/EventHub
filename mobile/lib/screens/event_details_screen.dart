// lib/screens/event_details_screen.dart
import 'package:flutter/material.dart';

import 'package:characters/characters.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';
import '../models/participation.dart';
import '../models/review.dart';
import '../services/api_client.dart';
import '../services/participation_service.dart';
import '../services/auth_store.dart';
import '../widgets/auth_scope.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extension.dart';
import '../theme/components/components.dart';

class EventDetailsScreen extends StatefulWidget {
  final String id;
  const EventDetailsScreen({super.key, required this.id});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final api = ApiClient('http://localhost:3000');
  final ParticipationService participations = ParticipationService();

  late final DateFormat _dateFmt = DateFormat('d MMMM yyyy, HH:mm', 'ru_RU');

  Event? e;
  String? error;
  bool loading = true;

  AuthStore? _auth;
  Participation? _myParticipation;
  bool _joinBusy = false;
  bool _participantsLoading = false;
  String? _participantsError;
  final Set<String> _participantActionBusy = {};
  List<Participation> _participants = [];
  Review? _myReview;
  List<Review> _reviews = [];
  bool _reviewsLoading = false;
  String? _reviewsError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auth ??= AuthScope.of(context);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await api.get('/events/${widget.id}');
      final event = Event.fromJson(data as Map<String, dynamic>);
      if (!mounted) return;
      setState(() {
        e = event;
        loading = false;
      });
      await _loadParticipation(event);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        error = err.toString();
        loading = false;
      });
    }
  }

  Future<void> _loadParticipation([Event? event]) async {
    final ev = event ?? e;
    final auth = _auth ?? AuthScope.of(context);
    if (ev == null || auth.user == null) return;

    try {
      final my = await participations.myStatus(ev.id);
      if (!mounted) return;
      setState(() {
        _myParticipation = my;
        final spots = my?.availableSpots;
        if (spots != null && e != null) {
          e = e!.copyWith(availableSpots: spots);
        }
      });
    } catch (_) {
      // игнорируем ошибку: не критично для отображения события
    }

    try {
      final myReview = await participations.myReview(ev.id);
      if (!mounted) return;
      setState(() {
        _myReview = myReview;
      });
    } catch (_) {
      // ignore
    }

    if (auth.user!.id == ev.ownerId) {
      await _loadParticipants(ev);
    }

    await _loadReviews(ev);
  }

  Future<void> _loadParticipants(Event ev) async {
    setState(() {
      _participantsLoading = true;
      _participantsError = null;
    });
    try {
      final list = await participations.listForOwner(ev.id);
      if (!mounted) return;
      setState(() {
        _participants = list;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _participantsError = err.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _participantsLoading = false;
        });
      }
    }
  }

  Future<void> _loadReviews(Event ev, {int? rating}) async {
    setState(() {
      _reviewsLoading = true;
      if (rating != null) {
        _reviewsError = null;
      }
    });
    try {
      final list = await participations.eventReviews(ev.id, rating: rating);
      if (!mounted) return;
      setState(() {
        _reviews = list;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _reviewsError = err.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _reviewsLoading = false;
        });
      }
    }
  }

  Future<void> _joinEvent() async {
    final ev = e;
    if (ev == null) return;
    setState(() => _joinBusy = true);
    try {
      final result = await participations.request(ev.id);
      if (!mounted) return;
      setState(() {
        _myParticipation = result.participation;
        final spots = result.availableSpots ?? result.participation.availableSpots;
        if (spots != null && e != null) {
          e = e!.copyWith(availableSpots: spots);
        }
      });
      final msg = result.autoconfirmed
          ? 'Вы добавлены в список участников'
          : 'Заявка отправлена организатору';
      _toast(msg);
    } catch (err) {
      _toast('Не удалось отправить заявку: $err');
    } finally {
      if (mounted) {
        setState(() => _joinBusy = false);
      }
    }
  }

  Future<void> _cancelParticipation() async {
    final ev = e;
    if (ev == null) return;
    setState(() => _joinBusy = true);
    try {
      final updated = await participations.cancel(ev.id);
      if (!mounted) return;
      setState(() {
        _myParticipation = updated;
        final spots = updated.availableSpots;
        if (spots != null && e != null) {
          e = e!.copyWith(availableSpots: spots);
        }
      });
      _toast('Заявка отменена');
    } catch (err) {
      if (mounted) {
        _toast('Не удалось отменить участие: $err');
      }
    } finally {
      if (mounted) {
        setState(() => _joinBusy = false);
      }
    }
  }

  Future<void> _updateParticipantStatus(Participation p, String status) async {
    if (_participantActionBusy.contains(p.id)) return;
    setState(() => _participantActionBusy.add(p.id));
    try {
      final updated = await participations.setStatus(p.eventId, p.id, status);
      if (!mounted) return;
      setState(() {
        _participants = _participants
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
        final spots = updated.availableSpots;
        if (spots != null && e != null) {
          e = e!.copyWith(availableSpots: spots);
        }
      });
      final message = switch (status) {
        'approved' => 'Участник одобрен',
        'rejected' => 'Заявка отклонена',
        'cancelled' => 'Заявка отменена',
        _ => 'Статус обновлён',
      };
      _toast(message);
    } catch (err) {
      if (mounted) {
        _toast('Ошибка обновления статуса: $err');
      }
    } finally {
      if (mounted) {
        setState(() => _participantActionBusy.remove(p.id));
      }
    }
  }

  bool _canLeaveReview(Event ev) {
    final now = DateTime.now();
    final ended = ev.endAt.isBefore(now);
    final isOwner = _auth?.user?.id == ev.ownerId;
    if (!ended || isOwner) return false;
    final status = _myParticipation?.status;
    return status == 'approved' || _myReview != null;
  }

  Future<void> _openReviewSheet() async {
    final ev = e;
    if (ev == null) return;

    int rating = _myReview?.rating ?? 5;
    final controller = TextEditingController(text: _myReview?.text ?? '');
    bool busy = false;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setStateModal) {
              Future<void> submit() async {
                setStateModal(() => busy = true);
                try {
                  final review = await participations.submitReview(
                    ev.id,
                    rating: rating,
                    text: controller.text.trim().isEmpty ? null : controller.text.trim(),
                  );
                  if (!mounted) return;
                  setState(() {
                    _myReview = review;
                  });
                  Navigator.of(ctx).pop(true);
                } catch (err) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Не удалось сохранить отзыв: $err')),
                  );
                } finally {
                  if (mounted) {
                    setStateModal(() => busy = false);
                  }
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _myReview == null ? 'Оценить событие' : 'Обновить отзыв',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      final filled = star <= rating;
                      return IconButton(
                        onPressed: () => setStateModal(() => rating = star),
                        icon: Icon(
                          filled ? Icons.star : Icons.star_border,
                          color: filled ? Colors.amber : Colors.grey,
                        ),
                      );
                    }),
                  ),
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Комментарий (необязательно)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Сохранить'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (submitted == true) {
      final evCurrent = e;
      if (evCurrent != null) {
        await _loadReviews(evCurrent);
      }
    }
  }

  Future<void> _openParticipantRating(Event ev, Participation participation) async {
    int rating = participation.participantReview?.rating ?? 5;
    final controller = TextEditingController(text: participation.participantReview?.text ?? '');
    bool busy = false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setStateModal) {
              Future<void> submit() async {
                setStateModal(() => busy = true);
                try {
                  final review = await participations.rateParticipant(
                    ev.id,
                    participation.id,
                    rating: rating,
                    text: controller.text.trim().isEmpty ? null : controller.text.trim(),
                  );
                  if (!mounted) return;
                  setState(() {
                    _participants = _participants.map((p) {
                      if (p.id == participation.id) {
                        return p.copyWith(participantReview: ParticipantReview(
                          id: review.id,
                          rating: review.rating,
                          text: review.text,
                          createdAt: review.createdAt,
                        ));
                      }
                      return p;
                    }).toList();
                  });
                  Navigator.of(ctx).pop(true);
                } catch (err) {
                  if (mounted) {
                    _toast('Не удалось сохранить оценку участнику: $err');
                  }
                } finally {
                  if (mounted) setStateModal(() => busy = false);
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participation.participantReview == null ? 'Оценить участника' : 'Изменить оценку',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      final filled = star <= rating;
                      return IconButton(
                        onPressed: () => setStateModal(() => rating = star),
                        icon: Icon(
                          filled ? Icons.star : Icons.star_border,
                          color: filled ? Colors.amber : Colors.grey,
                        ),
                      );
                    }),
                  ),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Комментарий (необязательно)'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Сохранить'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (result == true) {
      await _loadParticipants(ev);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Событие')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null)
              ? Center(child: Text('Ошибка: $error'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final ev = e!;
    final auth = _auth;
    final isOwner = auth?.user?.id == ev.ownerId;
    final addressWidgets = _buildAddress(ev);
    final scheduleText = _formatSchedule(ev.startAt, ev.endAt);
    final capacity = ev.capacity;
    final freeSlots = _freeSlots(ev);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: (ev.coverUrl != null && ev.coverUrl!.isNotEmpty)
                ? Image.network(ev.coverUrl!, fit: BoxFit.cover)
                : Container(color: const Color(0xFFEFF2F7)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSurface(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ev.title,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xs),
        if (ev.isAdultOnly)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('18+', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
            ),
          ),
        if (ev.isAdultOnly) const SizedBox(height: AppSpacing.sm),

        if (ev.owner != null) _buildOwnerBlock(ev.owner!),
        if (ev.owner != null) const SizedBox(height: AppSpacing.sm),

        Row(children: const [
          Icon(Icons.place_outlined, size: 18, color: Colors.black54),
          SizedBox(width: 6),
          Text('Адрес', style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 24, top: 4),
          child: addressWidgets,
        ),
        const SizedBox(height: AppSpacing.md),

        Row(children: const [
          Icon(Icons.schedule, size: 18, color: Colors.black54),
          SizedBox(width: 6),
          Text('Время', style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 24, top: 4),
          child: Text(scheduleText, style: const TextStyle(fontSize: 16, color: Colors.black87)),
        ),
        const SizedBox(height: AppSpacing.md),

        if (capacity != null)
          Row(
            children: const [
              Icon(Icons.groups_outlined, size: 18, color: Colors.black54),
              SizedBox(width: 6),
              Text('Места', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        if (capacity != null)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 4),
            child: Text(
              'Свободных мест: ${freeSlots ?? capacity} из $capacity',
              style: TextStyle(
                fontSize: 16,
                color: (freeSlots ?? capacity) == 0 ? Colors.red.shade600 : Colors.black87,
              ),
            ),
          ),
        if (capacity != null) const SizedBox(height: AppSpacing.md),

        const Text('Описание', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(ev.description),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ..._buildParticipationWidgets(ev, isOwner),
      ],
    );
  }

  Widget _buildOwnerBlock(EventOwner owner) {
    final name = owner.fullName.isNotEmpty ? owner.fullName : 'Организатор';
    return InkWell(
      onTap: () => context.push('/users/${owner.id}'),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFEFF2F7),
            backgroundImage:
                (owner.avatarUrl != null && owner.avatarUrl!.isNotEmpty) ? NetworkImage(owner.avatarUrl!) : null,
            child: (owner.avatarUrl == null || owner.avatarUrl!.isEmpty)
                ? Text(
                    name.characters.first.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Организатор', style: TextStyle(color: Colors.black54, fontSize: 12)),
              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue)),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildParticipationWidgets(Event ev, bool isOwner) {
    final auth = _auth;
    if (auth?.user == null) {
      return [
        const SizedBox(height: 24),
        ..._buildReviewsBlock(),
      ];
    }

    final widgets = <Widget>[];

    if (isOwner) {
      widgets.addAll(_buildOwnerParticipantsSection(ev));
    } else {
      widgets.add(const SizedBox(height: 20));
      widgets.add(_buildJoinSection(ev));
      if (_canLeaveReview(ev)) {
        widgets.add(const SizedBox(height: 12));
        widgets.add(_buildReviewSection(ev));
      }
    }

    widgets.add(const SizedBox(height: 24));
    widgets.addAll(_buildReviewsBlock());
    return widgets;
  }

  Widget _buildJoinSection(Event ev) {
    final status = _myParticipation?.status;
    final statusLabel = _statusLabel(status);
    final statusColor = _statusColor(status);
    final waiting = status == 'requested';
    final approved = status == 'approved';
    final cancelled = status == 'cancelled';
    final rejected = status == 'rejected';
    final ended = ev.endAt.isBefore(DateTime.now());
    final participantReview = _myParticipation?.participantReview;
    final capacity = ev.capacity;
    final freeSlots = _freeSlots(ev);
    final noSlots = freeSlots != null && freeSlots <= 0;
    final slotsLabel = capacity != null
        ? 'Свободных мест: ${freeSlots ?? capacity} из $capacity'
        : null;
    final canJoin = !ended && (status == null || rejected || cancelled);
    final canRequestAgain = canJoin && !noSlots;

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Участие',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
            if (slotsLabel != null)
              Text(
                slotsLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: noSlots ? Theme.of(context).colorScheme.error : null,
                      fontWeight: FontWeight.w600,
                    ),
              ),
          if (slotsLabel != null) const SizedBox(height: AppSpacing.xs),
            if (statusLabel != null)
              Text(statusLabel,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: statusColor, fontWeight: FontWeight.w600)),
            if (ended)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: Text('Событие уже завершилось'),
              ),
            if (approved)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: Text('Вы уже в списке участников'),
              ),
            if (participantReview != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    _buildStars(participantReview.rating.toDouble(), size: 18),
                    const SizedBox(width: 6),
                    Text('${participantReview.rating}/5', style: const TextStyle(color: Colors.black54)),
                    if (participantReview.text != null && participantReview.text!.isNotEmpty)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text('Отзыв организатора: ${participantReview.text!}', style: const TextStyle(color: Colors.black54)),
                        ),
                      ),
                  ],
                ),
              ),
            if (waiting)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: Text('Организатор должен подтвердить участие'),
              ),
            if (rejected)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: Text('Организатор отклонил заявку'),
              ),
            if (!approved && !waiting && slotsLabel != null && noSlots)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: Text('Свободных мест нет'),
              ),
            if (cancelled)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: Text('Вы отменили участие'),
              ),
            if (!ended && canRequestAgain)
              AppButton.primary(
                onPressed: _joinBusy ? null : _joinEvent,
                label: 'Участвовать',
                busy: _joinBusy,
              ),
            if (!ended && !canRequestAgain && (approved || waiting))
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: AppButton.secondary(
                  onPressed: _joinBusy ? null : _cancelParticipation,
                  label: 'Отменить участие',
                  busy: _joinBusy,
                ),
              ),
            if (!canRequestAgain && !approved && !waiting)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Вы можете подать заявку повторно позже',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.orange.shade700),
                ),
              ),
        ],
      ),
    );
  }

  int? _freeSlots(Event ev) {
    final capacity = ev.capacity;
    if (capacity == null) return null;
    final available = ev.availableSpots;
    if (available == null) return capacity;
    if (available < 0) return 0;
    if (available > capacity) return capacity;
    return available;
  }

  List<Widget> _buildOwnerParticipantsSection(Event ev) {
    final theme = Theme.of(context);
    final widgets = <Widget>[
      const SizedBox(height: AppSpacing.lg),
      Text('Участники', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.sm),
    ];

    if (ev.capacity != null) {
      final freeSlots = _freeSlots(ev) ?? ev.capacity!;
      widgets.add(Text(
        'Свободных мест: $freeSlots из ${ev.capacity}',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: freeSlots == 0 ? theme.colorScheme.error : null,
          fontWeight: FontWeight.w600,
        ),
      ));
      widgets.add(const SizedBox(height: AppSpacing.sm));
    }

    if (_participantsLoading) {
      widgets.add(const Center(child: Padding(padding: EdgeInsets.only(top: AppSpacing.md), child: CircularProgressIndicator())));
      return widgets;
    }

    if (_participantsError != null) {
      widgets.add(Text(
        'Ошибка загрузки участников: $_participantsError',
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
      ));
      return widgets;
    }

    if (_participants.isEmpty) {
      widgets.add(Text('Пока никто не записался', style: theme.textTheme.bodyMedium));
      return widgets;
    }

    widgets.addAll(_participants.map((p) => _buildParticipantTile(ev, p)));
    return widgets;
  }

  Widget _buildParticipantTile(Event ev, Participation p) {
    final user = p.user;
    final isPending = p.status == 'requested';
    final busy = _participantActionBusy.contains(p.id);
    final ended = ev.endAt.isBefore(DateTime.now());
    final review = p.participantReview;
    final canRate = ended && p.status == 'approved';
    final initialsSource = (user?.fullName ?? 'У').trim();
    final displayChar = initialsSource.isEmpty
        ? 'У'
        : initialsSource.characters.first.toUpperCase();

    final theme = Theme.of(context);
    return AppSurface(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: user != null ? () => context.push('/users/${user.id}') : null,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEFF2F7),
          backgroundImage: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
              ? NetworkImage(user.avatarUrl!)
              : null,
          child: (user?.avatarUrl == null || user!.avatarUrl!.isEmpty)
              ? Text(displayChar)
              : null,
        ),
        title: Text(
          user?.fullName ?? 'Участник',
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _statusLabel(p.status) ?? p.status,
              style: theme.textTheme.bodySmall?.copyWith(color: _statusColor(p.status) ?? theme.colorScheme.onSurfaceVariant),
            ),
            if (review != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    _buildStars(review.rating.toDouble(), size: 14),
                    const SizedBox(width: 6),
                    Text('${review.rating}/5', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
        trailing: isPending
            ? Wrap(
                spacing: 8,
                children: [
                  AppButton.secondary(
                    fullWidth: false,
                    onPressed: busy ? null : () => _updateParticipantStatus(p, 'rejected'),
                    label: 'Отклонить',
                  ),
                  AppButton.primary(
                    fullWidth: false,
                    onPressed: busy ? null : () => _updateParticipantStatus(p, 'approved'),
                    label: 'Подтвердить',
                    busy: busy,
                  ),
                ],
              )
            : canRate
                ? IconButton(
                    tooltip: review == null ? 'Оценить участника' : 'Изменить оценку',
                    onPressed: () => _openParticipantRating(ev, p),
                    icon: const Icon(Icons.star_rate, color: Colors.amber),
                  )
                : null,
      ),
    );
  }

  Widget _buildReviewSection(Event ev) {
    final review = _myReview;
    final ended = ev.endAt.isBefore(DateTime.now());
    final currentUserId = _auth?.user?.id;
    Review? currentReview = review;
    if (currentReview == null && currentUserId != null) {
      try {
        currentReview = _reviews.firstWhere((r) => r.author.id == currentUserId);
      } catch (_) {
        currentReview = null;
      }
    }

    final theme = Theme.of(context);

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentReview != null ? 'Ваш отзыв' : 'Оставить отзыв',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!ended)
            Text(
              'Оценить событие можно после его завершения',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else if (currentReview != null) ...[
            Row(
              children: [
                _buildStars(currentReview!.rating.toDouble(), size: 22),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text('${currentReview!.rating}/5', style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
            if (currentReview!.text != null && currentReview!.text!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(currentReview!.text!, style: theme.textTheme.bodyMedium),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text('Вы уже оценили событие', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ] else ...[
            _buildStars(0),
            const SizedBox(height: AppSpacing.sm),
            AppButton.primary(
              onPressed: _openReviewSheet,
              label: 'Оценить событие',
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildReviewsBlock() {
    final theme = Theme.of(context);
    final widgets = <Widget>[
      Text('Отзывы', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.sm),
    ];

    if (_reviewsLoading && _reviews.isEmpty) {
      widgets.add(const Center(child: CircularProgressIndicator()));
      return widgets;
    }

    if (_reviewsError != null) {
      widgets.add(Text(
        'Ошибка загрузки отзывов: $_reviewsError',
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
      ));
      return widgets;
    }

    if (_reviews.isEmpty) {
      widgets.add(Text('Отзывов пока нет', style: theme.textTheme.bodyMedium));
      return widgets;
    }

    final avg = _averageRating;
    widgets.add(Row(
      children: [
        _buildStars(avg),
        const SizedBox(width: AppSpacing.xs),
        Text(avg.toStringAsFixed(1), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        Text('  •  ${_reviews.length} отзывов',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    ));
    widgets.add(const SizedBox(height: AppSpacing.sm));

    widgets.addAll(_reviews.map(_buildReviewTile));
    if (_reviewsLoading) {
      widgets.add(const Padding(
        padding: EdgeInsets.only(top: AppSpacing.sm),
        child: Center(child: CircularProgressIndicator()),
      ));
    }
    return widgets;
  }

  Widget _buildReviewTile(Review review) {
    final theme = Theme.of(context);
    final borderRadius = Theme.of(context).extension<AppThemeExtension>()?.panelRadius ?? BorderRadius.circular(24);
    return AppSurface(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => context.push('/users/${review.author.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    backgroundImage: (review.author.avatarUrl != null && review.author.avatarUrl!.isNotEmpty)
                        ? NetworkImage(review.author.avatarUrl!)
                        : null,
                    child: (review.author.avatarUrl == null || review.author.avatarUrl!.isEmpty)
                        ? Text(
                            review.author.initials,
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(review.author.fullName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _buildStars(review.rating.toDouble(), size: 14),
                            const SizedBox(width: 6),
                            Text('${review.rating}/5',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormat('dd.MM.yyyy').format(review.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              if (review.text != null && review.text!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(review.text!.trim(), style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStars(double value, {double size = 18}) {
    final full = value.floor();
    final hasHalf = value - full >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < full) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        }
        if (index == full && hasHalf) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        }
        return Icon(Icons.star_border, color: Colors.grey, size: size);
      }),
    );
  }

  double get _averageRating {
    if (_reviews.isEmpty) return 0;
    final total = _reviews.fold<int>(0, (sum, r) => sum + r.rating);
    return total / _reviews.length;
  }

  String? _statusLabel(String? status) {
    switch (status) {
      case 'approved':
        return 'Вы участвуете';
      case 'requested':
        return 'Ожидает подтверждения';
      case 'rejected':
        return 'Заявка отклонена';
      case 'cancelled':
        return 'Заявка отменена';
      default:
        return null;
    }
  }

  Color? _statusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green.shade700;
      case 'requested':
        return Colors.orange.shade700;
      case 'rejected':
        return Colors.red.shade600;
      case 'cancelled':
        return Colors.grey.shade600;
      default:
        return null;
    }
  }

  Widget _buildAddress(Event ev) {
    if (ev.address == null || ev.address!.trim().isEmpty) {
      if (ev.isAddressHidden) {
        return const Text('Адрес появится после одобрения заявки');
      }
      return const Text('Адрес не указан');
    }

    final parts = ev.address!
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final houseNumber = parts.firstWhere(
      (p) => RegExp(r'^\d+[\w\-\/]*$', unicode: true).hasMatch(p),
      orElse: () => '',
    );
    final street = parts.firstWhere(
      (p) {
        final lower = p.toLowerCase();
        return lower.contains('улиц') ||
            lower.contains('просп') ||
            lower.contains('бульвар') ||
            lower.contains('шоссе') ||
            lower.contains('пер.') ||
            lower.contains('lane') ||
            lower.contains('street') ||
            lower.contains('road') ||
            lower.contains('avenue');
      },
      orElse: () => parts.isNotEmpty ? parts.first : '',
    );

    final primaryLine = street.isEmpty
        ? ev.address!.trim()
        : houseNumber.isNotEmpty
            ? '$street, $houseNumber'
            : street;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ev.city.isNotEmpty)
          Text(
            ev.city,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            primaryLine,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  String _formatSchedule(DateTime start, DateTime end) {
    final localStart = start.toLocal();
    final localEnd = end.toLocal();
    final sameDay = localStart.year == localEnd.year &&
        localStart.month == localEnd.month &&
        localStart.day == localEnd.day;

    if (sameDay) {
      return '${_dateFmt.format(localStart)} — ${DateFormat('HH:mm').format(localEnd)}';
    }
    return '${_dateFmt.format(localStart)} — ${_dateFmt.format(localEnd)}';
  }
}
