import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';
import '../services/auth_store.dart';
import '../services/participation_service.dart';
import '../services/review_prompt_storage.dart';
import 'auth_scope.dart';

class ReviewPromptManager extends StatefulWidget {
  const ReviewPromptManager({super.key, required this.child});

  final Widget child;

  @override
  State<ReviewPromptManager> createState() => _ReviewPromptManagerState();
}

class _ReviewPromptManagerState extends State<ReviewPromptManager>
    with WidgetsBindingObserver {
  final ParticipationService _participations = ParticipationService();
  Event? _pending;
  bool _fetching = false;
  bool _submitting = false;
  int _rating = 5;
  TextEditingController? _commentCtrl;
  DateTime? _lastCheck;
  AuthStore? _auth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth?.removeListener(_handleAuthChange);
    _commentCtrl?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = AuthScope.of(context);
    if (!identical(auth, _auth)) {
      _auth?.removeListener(_handleAuthChange);
      _auth = auth;
      _auth?.addListener(_handleAuthChange);
      _handleAuthChange();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleCheck();
    }
  }

  void _handleAuthChange() {
    final auth = _auth;
    if (auth == null) return;
    if (!auth.isLoggedIn) {
      _clearPrompt();
      _lastCheck = null;
      return;
    }
    if (!auth.isReady) return;
    _lastCheck = null;
    _scheduleCheck(force: true);
  }

  void _scheduleCheck({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeFetchPending(force: force);
    });
  }

  Future<void> _maybeFetchPending({bool force = false}) async {
    if (!mounted) return;
    if (_submitting || _fetching) return;
    if (_pending != null && !force) return;
    final auth = _auth;
    if (auth == null || !auth.isLoggedIn || !auth.isReady) return;
    final userId = auth.user?.id;
    if (userId == null) {
      _clearPrompt();
      return;
    }

    final now = DateTime.now();
    if (!force && _lastCheck != null && now.difference(_lastCheck!) < const Duration(minutes: 5)) {
      return;
    }
    _lastCheck = now;

    setState(() => _fetching = true);

    try {
      final events = await _participations.participatingEvents();
      events.sort((a, b) => a.endAt.compareTo(b.endAt));
      for (final event in events) {
        final status = event.participationStatus;
        final isParticipant = status == 'approved' || status == 'attended';
        final ended = !event.endAt.isAfter(now);
        final alreadyReviewedServer = event.reviewed;
        if (!isParticipant || !ended || alreadyReviewedServer) {
          continue;
        }
        if (await ReviewPromptStorage.isReviewed(userId, event.id)) {
          continue;
        }
        if (await ReviewPromptStorage.isDismissed(userId, event.id)) {
          continue;
        }
        _showPrompt(event);
        return;
      }
      _clearPrompt();
    } catch (err) {
      debugPrint('ReviewPromptManager: failed to fetch pending reviews: $err');
    } finally {
      if (mounted) {
        setState(() => _fetching = false);
      }
    }
  }

  void _showPrompt(Event event) {
    _commentCtrl?.dispose();
    setState(() {
      _pending = event;
      _rating = 5;
      _commentCtrl = TextEditingController();
    });
  }

  void _clearPrompt() {
    _commentCtrl?.dispose();
    _commentCtrl = null;
    if (mounted) {
      setState(() {
        _pending = null;
      });
    }
  }

  Future<void> _dismissTemporarily() async {
    final event = _pending;
    final userId = _auth?.user?.id;
    if (event == null || userId == null) return;
    await ReviewPromptStorage.markDismissed(userId, event.id);
    _clearPrompt();
  }

  Future<void> _submitReview() async {
    final event = _pending;
    final userId = _auth?.user?.id;
    if (event == null || _submitting || userId == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      final text = _commentCtrl?.text.trim();
      await _participations.submitReview(
        event.id,
        rating: _rating,
        text: text != null && text.isNotEmpty ? text : null,
      );
      await ReviewPromptStorage.markReviewed(userId, event.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Спасибо за отзыв!')),
      );
      _clearPrompt();
      _scheduleCheck(force: true);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить отзыв: $err')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlay = _pending == null ? const SizedBox.shrink() : _buildOverlay(context, _pending!);
    return Stack(
      children: [
        widget.child,
        overlay,
      ],
    );
  }

  Widget _buildOverlay(BuildContext context, Event event) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('d MMMM, HH:mm', 'ru_RU');
    final endedAt = dateFmt.format(event.endAt);
    final controller = _commentCtrl ?? TextEditingController();
    _commentCtrl ??= controller;

    return Positioned.fill(
      child: Stack(
        children: [
          const ModalBarrier(dismissible: false, color: Colors.black54),
          Align(
            alignment: Alignment.center,
            child: FractionallySizedBox(
              widthFactor: 0.9,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Card(
                  color: Colors.white.withOpacity(0.98),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Как прошло событие?', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          event.title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Событие завершилось $endedAt',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        Text('Ваша оценка', style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(5, (index) {
                            final star = index + 1;
                            final filled = star <= _rating;
                            return IconButton(
                              onPressed: () => setState(() => _rating = star),
                              iconSize: 32,
                              splashRadius: 24,
                              color: filled ? Colors.amber : Colors.grey.shade400,
                              icon: Icon(filled ? Icons.star : Icons.star_border),
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: controller,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Комментарий (необязательно)',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _submitting ? null : _dismissTemporarily,
                                child: const Text('Позже'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _submitting ? null : _submitReview,
                                child: _submitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Оценить'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
