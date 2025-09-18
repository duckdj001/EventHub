// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../models/event.dart';
import '../models/review.dart';
import '../services/auth_store.dart';
import '../services/participation_service.dart';
import '../services/user_service.dart';
import '../widgets/auth_scope.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ParticipationService? _participationService;
  final UserService _userService = UserService();
  AuthStore? _auth;

  bool _loadingParticipation = false;
  String? _participationError;
  List<Event> _participatingEvents = const [];
  bool _initialised = false;
  final DateFormat _dateFmt = DateFormat('dd.MM.yyyy HH:mm');

  bool _loadingCreatedEvents = false;
  String? _createdEventsError;
  List<Event> _createdEvents = const [];
  String _createdFilter = 'upcoming';

  bool _loadingReviews = false;
  String? _reviewsError;
  List<Review> _reviews = const [];
  int? _reviewsFilter;

  bool _loadingParticipantReviews = false;
  String? _participantReviewsError;
  List<Review> _participantReviews = const [];
  int? _participantReviewsFilter;

  ParticipationService get _service =>
      _participationService ??= ParticipationService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AuthScope.of(context);
    if (_auth != store) {
      _auth = store;
      if (!_initialised) {
        _initialised = true;
        _loadAll();
      }
    }
  }

  Future<void> _loadParticipation() async {
    final auth = _auth;
    if (auth?.user == null) {
      setState(() {
        _participatingEvents = const [];
        _participationError = null;
      });
      return;
    }

    setState(() {
      _loadingParticipation = true;
      _participationError = null;
    });
    try {
      final list = await _service.participatingEvents();
      if (!mounted) return;
      setState(() {
        _participatingEvents = list;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _participationError = err.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingParticipation = false;
        });
      }
    }
  }

  Future<void> _loadCreatedEvents({String? filter}) async {
    final auth = _auth;
    if (auth?.user == null) {
      setState(() {
        _createdEvents = const [];
        _createdEventsError = null;
      });
      return;
    }

    final store = auth!;
    final userId = store.user!.id;
    final targetFilter = filter ?? _createdFilter;
    setState(() {
      _createdFilter = targetFilter;
      _loadingCreatedEvents = true;
      if (filter != null) _createdEventsError = null;
    });
    try {
      final list = await _userService.eventsCreated(userId, filter: targetFilter);
      if (!mounted) return;
      setState(() {
        _createdEvents = list;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _createdEventsError = err.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCreatedEvents = false;
        });
      }
    }
  }

  Future<void> _loadReviews({int? rating}) async {
    final auth = _auth;
    if (auth?.user == null) {
      setState(() {
        _reviews = const [];
        _reviewsError = null;
      });
      return;
    }

    final store = auth!;
    final userId = store.user!.id;
    setState(() {
      _loadingReviews = true;
      _reviewsFilter = rating;
      if (rating != null) {
        _reviewsError = null;
      }
    });
    try {
      final list = await _userService.reviews(userId, rating: rating ?? _reviewsFilter, type: 'event');
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
          _loadingReviews = false;
        });
      }
    }
  }

  Future<void> _loadParticipantReviews({int? rating}) async {
    final auth = _auth;
    if (auth?.user == null) {
      setState(() {
        _participantReviews = const [];
        _participantReviewsError = null;
      });
      return;
    }

    final userId = auth!.user!.id;
    setState(() {
      _loadingParticipantReviews = true;
      _participantReviewsFilter = rating;
      if (rating != null) {
        _participantReviewsError = null;
      }
    });
    try {
      final list = await _userService.reviews(userId, rating: rating ?? _participantReviewsFilter, type: 'participant');
      if (!mounted) return;
      setState(() {
        _participantReviews = list;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _participantReviewsError = err.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loadingParticipantReviews = false);
      }
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadParticipation(),
      _loadCreatedEvents(),
      _loadReviews(),
      _loadParticipantReviews(),
    ]);
  }

  Future<void> _refresh() async {
    final auth = _auth;
    if (auth == null) return;
    try {
      await Future.wait([
        auth.refreshProfile(),
        _loadParticipation(),
        _loadCreatedEvents(),
        _loadReviews(),
        _loadParticipantReviews(),
      ]);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка обновления профиля: $err')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = _auth ?? AuthScope.of(context);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            onPressed: auth.isRefreshingProfile || _loadingParticipation
                ? null
                : () => _refresh(),
            icon: auth.isRefreshingProfile || _loadingParticipation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Профиль не найден'))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundImage:
                            (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                        child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                            ? const Icon(Icons.person_outline, size: 32)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName.isNotEmpty ? user.fullName : user.email,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(user.email, style: const TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(user.bio!, style: const TextStyle(fontSize: 16)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      await context.push('/profile/edit');
                      await _refresh();
                    },
                    child: const Text('Редактировать профиль'),
                  ),
                  const SizedBox(height: 24),
                  _buildStatsSection(),
                  const SizedBox(height: 24),
                  _buildCreatedEventsSection(),
                  const Divider(),
                  _buildParticipationSection(),
                  const Divider(),
                  _buildReviewsSection(),
                  const Divider(),
                  _buildParticipantReviewsSection(),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.event_note_outlined),
                    title: const Text('Управление событиями'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/my-events'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Выйти'),
                    onTap: () async {
                      await auth.logout();
                      if (!context.mounted) return;
                      context.go('/login');
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildParticipationSection() {
    if (_loadingParticipation && _participatingEvents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_participationError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('Не удалось загрузить участие: $_participationError',
            style: const TextStyle(color: Colors.redAccent)),
      );
    }

    if (_participatingEvents.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.event_available_outlined),
        title: Text('События, где вы участвуете'),
        subtitle: Text('Пока заявок нет'),
      );
    }

    final now = DateTime.now();
    final upcoming = _participatingEvents.where((e) => e.endAt.isAfter(now)).toList();
    final archived = _participatingEvents.where((e) => !e.endAt.isAfter(now)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('События, где вы участвуете',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (upcoming.isEmpty)
          const Text('Нет активных заявок')
        else
          ...upcoming
              .map((event) => _ParticipationEventTile(event: event, dateFormat: _dateFmt))
              .toList(),
        if (archived.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Архив участия', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...archived
              .map((event) => _ParticipationEventTile(event: event, dateFormat: _dateFmt, archived: true))
              .toList(),
        ],
        if (_loadingParticipation)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildStatsSection() {
    final stats = _auth?.user?.stats;
    if (stats == null) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Рейтинг организатора', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStars(stats.ratingAvg),
                const SizedBox(width: 8),
                Text(stats.ratingAvg.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('  •  ${stats.ratingCount} отзывов', style: const TextStyle(color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                Chip(
                  avatar: const Icon(Icons.event_available_outlined, size: 18),
                  label: Text('Предстоящие события: ${stats.eventsUpcoming}'),
                ),
                Chip(
                  avatar: const Icon(Icons.history, size: 18),
                  label: Text('Прошедшие события: ${stats.eventsPast}'),
                ),
                Chip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: Text('Рейтинг участника: ${stats.participantRatingAvg.toStringAsFixed(1)} (${stats.participantRatingCount})'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatedEventsSection() {
    if (_loadingCreatedEvents && _createdEvents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_createdEventsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('Не удалось загрузить события: $_createdEventsError',
            style: const TextStyle(color: Colors.redAccent)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Созданные события', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            DropdownButton<String>(
              value: _createdFilter,
              items: const [
                DropdownMenuItem(value: 'upcoming', child: Text('Предстоящие')),
                DropdownMenuItem(value: 'past', child: Text('Прошедшие')),
                DropdownMenuItem(value: 'all', child: Text('Все')),
              ],
              onChanged: (value) {
                if (value != null) _loadCreatedEvents(filter: value);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_createdEvents.isEmpty)
          const Text('Вы ещё не создали событий')
        else
          ..._createdEvents.map(_buildCreatedEventTile),
        if (_loadingCreatedEvents)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildCreatedEventTile(Event event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => context.push('/events/${event.id}'),
        leading: event.coverUrl != null && event.coverUrl!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(event.coverUrl!, width: 48, height: 48, fit: BoxFit.cover),
              )
            : const CircleAvatar(child: Icon(Icons.event_outlined)),
        title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(_dateFmt.format(event.startAt.toLocal())),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildReviewsSection() {
    if (_loadingReviews && _reviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_reviewsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('Не удалось загрузить отзывы: $_reviewsError',
            style: const TextStyle(color: Colors.redAccent)),
      );
    }

    final filters = [null, 5, 4, 3, 2, 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Отзывы', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: filters.map((value) {
            final selected = _reviewsFilter == value || (_reviewsFilter == null && value == null);
            final label = value == null ? 'Все' : '$value★';
            return ChoiceChip(
              label: Text(label),
              selected: selected,
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
              onSelected: (_) => _loadReviews(rating: value),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        if (_reviews.isEmpty)
          const Text('Отзывы пока отсутствуют')
        else ...[
          Row(
            children: [
              _buildStars(_profileReviewsAverage),
              const SizedBox(width: 8),
              Text(_profileReviewsAverage.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('  •  ${_reviews.length} шт.', style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 12),
          ..._reviews.map(_buildProfileReviewTile),
        ],
        if (_loadingReviews)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildParticipantReviewsSection() {
    if (_loadingParticipantReviews && _participantReviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_participantReviewsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('Не удалось загрузить отзывы об участнике: $_participantReviewsError',
            style: const TextStyle(color: Colors.redAccent)),
      );
    }

    final filters = [null, 5, 4, 3, 2, 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Отзывы об участнике', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: filters.map((value) {
            final selected = _participantReviewsFilter == value || (_participantReviewsFilter == null && value == null);
            final label = value == null ? 'Все' : '$value★';
            return ChoiceChip(
              label: Text(label),
              selected: selected,
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
              onSelected: (_) => _loadParticipantReviews(rating: value),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        if (_participantReviews.isEmpty)
          const Text('Отзывов об участнике пока нет')
        else ...[
          Row(
            children: [
              _buildStars(_participantReviewsAverage),
              const SizedBox(width: 8),
              Text(_participantReviewsAverage.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('  •  ${_participantReviews.length} шт.', style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 12),
          ..._participantReviews.map(_buildProfileReviewTile),
        ],
        if (_loadingParticipantReviews)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildProfileReviewTile(Review review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFEFF2F7),
                  backgroundImage: (review.author.avatarUrl != null && review.author.avatarUrl!.isNotEmpty)
                      ? NetworkImage(review.author.avatarUrl!)
                      : null,
                  child: (review.author.avatarUrl == null || review.author.avatarUrl!.isEmpty)
                      ? Text(review.author.initials)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review.author.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _buildStars(review.rating.toDouble(), size: 14),
                          const SizedBox(width: 6),
                          Text('${review.rating}/5', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(DateFormat('dd.MM.yyyy').format(review.createdAt), style: const TextStyle(color: Colors.black45, fontSize: 12)),
              ],
            ),
            if (review.event != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Событие: ${review.event!.title}', style: const TextStyle(color: Colors.black54)),
              ),
            if (review.text != null && review.text!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(review.text!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStars(double rating, {double size = 18}) {
    final full = rating.floor();
    final hasHalf = rating - full >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < full) return Icon(Icons.star, color: Colors.amber, size: size);
        if (index == full && hasHalf) return Icon(Icons.star_half, color: Colors.amber, size: size);
        return Icon(Icons.star_border, color: Colors.grey, size: size);
      }),
    );
  }

  double get _profileReviewsAverage {
    if (_reviews.isEmpty) return 0;
    final total = _reviews.fold<int>(0, (sum, r) => sum + r.rating);
    return total / _reviews.length;
  }

  double get _participantReviewsAverage {
    if (_participantReviews.isEmpty) return 0;
    final total = _participantReviews.fold<int>(0, (sum, r) => sum + r.rating);
    return total / _participantReviews.length;
  }
}

class _ParticipationEventTile extends StatelessWidget {
  const _ParticipationEventTile({required this.event, required this.dateFormat, this.archived = false});

  final Event event;
  final DateFormat dateFormat;
  final bool archived;

  String _statusLabel(String? status) {
    switch (status) {
      case 'approved':
        return 'Подтверждено';
      case 'requested':
        return 'Ожидает подтверждения';
      case 'cancelled':
        return 'Отменено';
      case 'rejected':
        return 'Отклонено';
      default:
        return 'Без статуса';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green.shade700;
      case 'requested':
        return Colors.orange.shade700;
      case 'cancelled':
        return Colors.grey.shade600;
      case 'rejected':
        return Colors.red.shade600;
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = event.participationStatus;
    final statusLabel = _statusLabel(status);
    final statusColor = _statusColor(status);
    final secondary = archived
        ? 'Завершено ${dateFormat.format(event.endAt.toLocal())}'
        : 'Начало ${dateFormat.format(event.startAt.toLocal())}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => context.push('/events/${event.id}'),
        title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (statusLabel != null)
              Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
            Text(secondary, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
