import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';
import '../models/review.dart';
import '../models/user_profile.dart';
import '../services/user_service.dart';
import '../widgets/event_card.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final UserService _userService = UserService();
  final DateFormat _dateFmt = DateFormat('dd.MM.yyyy HH:mm');

  UserProfile? _profile;
  bool _loadingProfile = true;
  String? _profileError;

  List<Event> _events = const [];
  bool _loadingEvents = true;
  String? _eventsError;
  String _eventsFilter = 'upcoming';

  List<Review> _reviews = const [];
  bool _loadingReviews = true;
  String? _reviewsError;
  int? _reviewsFilter;

  List<Review> _participantReviews = const [];
  bool _loadingParticipantReviews = true;
  String? _participantReviewsError;
  int? _participantReviewsFilter;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadProfile(),
      _loadEvents(),
      _loadReviews(),
      _loadParticipantReviews(),
    ]);
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      final profile = await _userService.publicProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _profileError = err.toString();
      });
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadEvents({String? filter}) async {
    final nextFilter = filter ?? _eventsFilter;
    setState(() {
      _eventsFilter = nextFilter;
      _loadingEvents = true;
      if (filter != null) _eventsError = null;
    });
    try {
      final events = await _userService.eventsCreated(widget.userId, filter: nextFilter);
      if (!mounted) return;
      setState(() {
        _events = events;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _eventsError = err.toString();
      });
    } finally {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  Future<void> _loadReviews({int? rating}) async {
    setState(() {
      _loadingReviews = true;
      _reviewsFilter = rating;
      if (rating != null) _reviewsError = null;
    });
    try {
      final reviews = await _userService.reviews(widget.userId, rating: rating, type: 'event');
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _reviewsError = err.toString();
      });
    } finally {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  Future<void> _loadParticipantReviews({int? rating}) async {
    setState(() {
      _loadingParticipantReviews = true;
      _participantReviewsFilter = rating;
      if (rating != null) _participantReviewsError = null;
    });
    try {
      final reviews = await _userService.reviews(widget.userId, rating: rating, type: 'participant');
      if (!mounted) return;
      setState(() {
        _participantReviews = reviews;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _participantReviewsError = err.toString();
      });
    } finally {
      if (mounted) setState(() => _loadingParticipantReviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final loading = _loadingProfile && profile == null;
    final error = _profileError;

    return Scaffold(
      appBar: AppBar(title: Text(profile?.fullName.isNotEmpty == true ? profile!.fullName : 'Профиль организатора')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text('Ошибка: $error'))
              : profile == null
                  ? const Center(child: Text('Профиль не найден'))
                  : RefreshIndicator(
                      onRefresh: _loadAll,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildHeader(profile),
                          const SizedBox(height: 24),
                          _buildStats(profile),
                          const SizedBox(height: 24),
                          _buildEventsSection(),
                          const SizedBox(height: 24),
                          _buildReviewsSection(),
                          const SizedBox(height: 24),
                          _buildParticipantReviewsSection(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildHeader(UserProfile profile) {
    final name = profile.fullName.isNotEmpty ? profile.fullName : profile.email;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: const Color(0xFFEFF2F7),
          backgroundImage: (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty)
              ? NetworkImage(profile.avatarUrl!)
              : null,
          child: (profile.avatarUrl == null || profile.avatarUrl!.isEmpty)
              ? Text(name.characters.first.toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700))
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(profile.email, style: const TextStyle(color: Colors.black54)),
              if (profile.bio != null && profile.bio!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(profile.bio!),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats(UserProfile profile) {
    final stats = profile.stats;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Рейтинг', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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

  Widget _buildEventsSection() {
    if (_loadingEvents && _events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_eventsError != null) {
      return Text('Не удалось загрузить события: $_eventsError', style: const TextStyle(color: Colors.redAccent));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('События организатора', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            DropdownButton<String>(
              value: _eventsFilter,
              items: const [
                DropdownMenuItem(value: 'upcoming', child: Text('Предстоящие')),
                DropdownMenuItem(value: 'past', child: Text('Прошедшие')),
                DropdownMenuItem(value: 'all', child: Text('Все')),
              ],
              onChanged: (value) {
                if (value != null) _loadEvents(filter: value);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_events.isEmpty)
          const Text('Событий пока нет')
        else
          ..._events.map((event) => EventCard(
                e: event,
                distanceKm: null,
                onTap: () => context.push('/events/${event.id}'),
                onOwnerTap: null,
              )),
        if (_loadingEvents)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    if (_loadingReviews && _reviews.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reviewsError != null) {
      return Text('Не удалось загрузить отзывы: $_reviewsError', style: const TextStyle(color: Colors.redAccent));
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
        else
          ..._reviews.map(_buildReviewTile),
        if (_loadingReviews)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  double get _participantReviewsAverage {
    if (_participantReviews.isEmpty) return 0;
    final total = _participantReviews.fold<int>(0, (sum, r) => sum + r.rating);
    return total / _participantReviews.length;
  }

  Widget _buildParticipantReviewsSection() {
    if (_loadingParticipantReviews && _participantReviews.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_participantReviewsError != null) {
      return Text('Не удалось загрузить отзывы об участнике: $_participantReviewsError',
          style: const TextStyle(color: Colors.redAccent));
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
          const Text('Таких отзывов пока нет')
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
          ..._participantReviews.map(_buildReviewTile),
        ],
        if (_loadingParticipantReviews)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildReviewTile(Review review) {
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
}
