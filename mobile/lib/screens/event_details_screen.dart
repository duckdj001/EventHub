// lib/screens/event_details_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:characters/characters.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/event.dart';
import '../models/event_story.dart';
import '../models/event_photo.dart';
import '../models/participation.dart';
import '../models/review.dart';
import '../services/api_client.dart';
import '../services/event_stories_service.dart';
import '../services/event_photos_service.dart';
import '../services/participation_service.dart';
import '../services/auth_store.dart';
import '../services/upload_service.dart';
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
  final api = ApiClient('http://192.168.0.3:3000');
  final ParticipationService participations = ParticipationService();
  final EventStoriesService _storiesService = EventStoriesService();
  final UploadService _uploader = UploadService();
  final EventPhotosService _photosService = EventPhotosService();

  late final DateFormat _dateFmt = DateFormat('d MMMM yyyy, HH:mm', 'ru_RU');
  late final DateFormat _storyDateFmt = DateFormat('dd.MM HH:mm', 'ru_RU');

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
  List<EventStory> _stories = [];
  List<EventPhoto> _photos = [];
  bool _storiesLoading = false;
  String? _storiesError;
  bool _photosLoading = false;
  String? _photosError;
  bool _isUploading = false;
  _UploadKind? _uploadKind;
  double? _uploadProgress;
  String _uploadingLabel = 'историю';
  Future<void>? _activeUpload;
  IconData? _uploadingIcon;
  String? _uploadPreviewPath;
  bool _uploadPreviewIsVideo = false;
  final Set<String> _seenStoryIds = {};
  SharedPreferences? _prefs;
  bool _mediaPickerBusy = false;

  String get _seenStoriesStorageKey => 'event_seen_stories_${widget.id}';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs?.getStringList(_seenStoriesStorageKey) ?? const [];
    if (stored.isNotEmpty) {
      _seenStoryIds.addAll(stored);
    }
    if (!mounted) return;
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
      await Future.wait([
        _loadParticipation(event),
        _loadStories(event),
        _loadPhotos(event),
      ]);
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

  Future<void> _loadStories([Event? event]) async {
    final ev = event ?? e;
    if (ev == null) return;

    setState(() {
      _storiesLoading = true;
      _storiesError = null;
    });
    try {
      final list = await _storiesService.list(ev.id);
      if (!mounted) return;
      setState(() {
        _stories = list;
        _pruneSeenStoryIds(list);
      });
      _persistSeenStoryIds();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _storiesError = err.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _storiesLoading = false;
        });
      }
    }
  }

  Future<bool> _deleteStory(String storyId) async {
    final ev = e;
    if (ev == null) return false;

    try {
      await _storiesService.delete(ev.id, storyId);
      await _loadStories(ev);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('История удалена')));
      }
      return true;
    } catch (err) {
      if (mounted) {
        _toast('Не удалось удалить историю: $err');
      }
      return false;
    }
  }

  Future<bool> _deletePhoto(String photoId) async {
    final ev = e;
    if (ev == null) return false;

    try {
      await _photosService.delete(ev.id, photoId);
      await _loadPhotos(ev);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Фото удалено')));
      }
      return true;
    } catch (err) {
      if (mounted) {
        _toast('Не удалось удалить фото: $err');
      }
      return false;
    }
  }

  Future<void> _loadPhotos([Event? event]) async {
    final ev = event ?? e;
    if (ev == null) return;

    setState(() {
      _photosLoading = true;
      _photosError = null;
    });
    try {
      final list = await _photosService.list(ev.id);
      if (!mounted) return;
      setState(() {
        _photos = list;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _photosError = err.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _photosLoading = false;
        });
      }
    }
  }

  Future<void> _startUploadTask({
    required _UploadKind kind,
    required String label,
    required File file,
    required String presignType,
    required Future<void> Function(String url) onSuccess,
    required String successToast,
    required String errorToastPrefix,
    IconData? icon,
    String? previewPath,
    bool isVideo = false,
  }) async {
    if (_activeUpload != null) return;

    setState(() {
      _isUploading = true;
      _uploadKind = kind;
      _uploadingLabel = label;
      _uploadProgress = 0.0;
      _uploadingIcon = icon;
      _uploadPreviewPath = previewPath;
      _uploadPreviewIsVideo = isVideo;
    });

    Future<void> runner() async {
      Object? error;
      StackTrace? errorStack;
      var completed = false;
      try {
        final url = await _uploader.uploadImage(
          file,
          type: presignType,
          onProgress: (value) {
            if (!mounted) return;
            final clamped = value.clamp(0.0, 1.0);
            setState(() => _uploadProgress = clamped.toDouble());
          },
        );

        await onSuccess(url);
        completed = true;
      } catch (err, stack) {
        error = err;
        errorStack = stack;
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadKind = null;
            _uploadProgress = null;
            _uploadingLabel = 'историю';
            _uploadingIcon = null;
            _uploadPreviewPath = null;
            _uploadPreviewIsVideo = false;
          });
          if (error != null) {
            _toast('$errorToastPrefix: $error');
          } else if (completed) {
            _toast(successToast);
          }
        } else if (error != null) {
          debugPrint(
            'Upload task failed after widget dispose: $error\n$errorStack',
          );
        }
        _activeUpload = null;
      }
    }

    _activeUpload = runner();
    await _activeUpload;
  }

  Future<void> _addStory() async {
    final ev = e;
    if (ev == null || _activeUpload != null) return;
    if (!ev.allowStories) {
      _toast('Организатор отключил истории для этого события');
      return;
    }

    final media = await _pickStoryMedia();
    if (media == null) return;

    final file = File(media.path);
    _startUploadTask(
      kind: _UploadKind.story,
      label: media.isVideo ? 'видео' : 'историю',
      file: file,
      presignType: 'event-stories',
      successToast: 'История добавлена',
      errorToastPrefix: 'Не удалось добавить историю',
      icon: media.isVideo ? Icons.videocam_outlined : Icons.photo_outlined,
      previewPath: media.isVideo ? null : file.path,
      isVideo: media.isVideo,
      onSuccess: (url) async {
        final story = await _storiesService.create(ev.id, url: url);
        if (!mounted) return;
        setState(() {
          _stories = [story, ..._stories];
        });
      },
    );
  }

  Future<void> _addPhoto() async {
    final ev = e;
    if (ev == null || _activeUpload != null) return;

    final now = DateTime.now();
    if (ev.endAt.isAfter(now)) {
      _toast('Фотоотчет доступен после завершения события');
      return;
    }

    final user = _auth?.user;
    if (user == null) return;
    final status = _myParticipation?.status;
    final allowed =
        user.id == ev.ownerId || status == 'approved' || status == 'attended';
    if (!allowed) {
      _toast('Добавлять фото могут только участники и организатор');
      return;
    }

    final photoFiles = await _pickReportPhotos();
    if (photoFiles.isEmpty) return;

    for (final file in photoFiles) {
      await _startUploadTask(
        kind: _UploadKind.photo,
        label: 'фото',
        file: file,
        presignType: 'event-photos',
        successToast: 'Фото добавлено в отчет',
        errorToastPrefix: 'Не удалось добавить фото',
        icon: Icons.photo_outlined,
        previewPath: file.path,
        onSuccess: (url) async {
          final photo = await _photosService.create(ev.id, url: url);
          if (!mounted) return;
          setState(() {
            _photos = [photo, ..._photos];
          });
        },
      );
    }
  }

  Future<_StoryMedia?> _pickStoryMedia() async {
    if (_mediaPickerBusy) return null;
    _mediaPickerBusy = true;
    try {
      final option = await showModalBottomSheet<_StoryMediaSource>(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Фото из галереи'),
                  onTap: () =>
                      Navigator.of(ctx).pop(_StoryMediaSource.galleryPhoto),
                ),
                ListTile(
                  leading: const Icon(Icons.video_library_outlined),
                  title: const Text('Видео из галереи'),
                  onTap: () =>
                      Navigator.of(ctx).pop(_StoryMediaSource.galleryVideo),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Сделать фото'),
                  onTap: () =>
                      Navigator.of(ctx).pop(_StoryMediaSource.cameraPhoto),
                ),
                ListTile(
                  leading: const Icon(Icons.videocam_outlined),
                  title: const Text('Снять видео'),
                  onTap: () =>
                      Navigator.of(ctx).pop(_StoryMediaSource.cameraVideo),
                ),
              ],
            ),
          );
        },
      );

      if (option == null) return null;

      final picker = ImagePicker();
      // Небольшая пауза помогает iOS избежать ошибки multiple_request,
      // если пользователь очень быстро выбирает пункт.
      await Future.delayed(const Duration(milliseconds: 150));
      XFile? picked;
      switch (option) {
        case _StoryMediaSource.galleryPhoto:
          picked = await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
          );
          break;
        case _StoryMediaSource.galleryVideo:
          picked = await picker.pickVideo(source: ImageSource.gallery);
          break;
        case _StoryMediaSource.cameraPhoto:
          picked = await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 85,
          );
          break;
        case _StoryMediaSource.cameraVideo:
          picked = await picker.pickVideo(
            source: ImageSource.camera,
            maxDuration: const Duration(seconds: 30),
          );
          break;
      }

      if (picked == null) return null;

      final isVideo = _isVideoUrl(picked.path);
      if (isVideo) {
        final ok = await _validateVideoDuration(picked.path);
        if (!ok) {
          return null;
        }
      }

      return _StoryMedia(path: picked.path, isVideo: isVideo);
    } finally {
      _mediaPickerBusy = false;
    }
  }

  Future<List<File>> _pickReportPhotos() async {
    if (_mediaPickerBusy) return const [];
    _mediaPickerBusy = true;
    try {
      final source = await showModalBottomSheet<ImageSource?>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Выбрать из галереи (можно несколько)'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Сделать фото'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source == null) return const [];
      await Future.delayed(const Duration(milliseconds: 150));
      final picker = ImagePicker();

      if (source == ImageSource.gallery) {
        final picked = await picker.pickMultiImage(imageQuality: 90);
        if (picked.isEmpty) return const [];
        return picked.map((item) => File(item.path)).toList();
      }

      final single = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (single == null) return const [];
      return [File(single.path)];
    } finally {
      _mediaPickerBusy = false;
    }
  }

  Future<bool> _validateVideoDuration(String path) async {
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      final duration = controller.value.duration;
      if (duration > const Duration(seconds: 30)) {
        _toast('Видео должно быть не длиннее 30 секунд');
        return false;
      }
    } catch (_) {
      return true;
    } finally {
      await controller?.dispose();
    }
    return true;
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
        final spots =
            result.availableSpots ?? result.participation.availableSpots;
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
                    text: controller.text.trim().isEmpty
                        ? null
                        : controller.text.trim(),
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
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
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

  Future<void> _openParticipantRating(
      Event ev, Participation participation) async {
    int rating = participation.participantReview?.rating ?? 5;
    final controller = TextEditingController(
        text: participation.participantReview?.text ?? '');
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
                    text: controller.text.trim().isEmpty
                        ? null
                        : controller.text.trim(),
                  );
                  if (!mounted) return;
                  setState(() {
                    _participants = _participants.map((p) {
                      if (p.id == participation.id) {
                        return p.copyWith(
                            participantReview: ParticipantReview(
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
                    participation.participantReview == null
                        ? 'Оценить участника'
                        : 'Изменить оценку',
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
                    decoration: const InputDecoration(
                        labelText: 'Комментарий (необязательно)'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
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
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Событие')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Событие')),
        body: Center(child: Text('Ошибка: $error')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Событие')),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
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
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
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
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (ev.isAdultOnly)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('18+',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w700)),
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
                child: Text(scheduleText,
                    style:
                        const TextStyle(fontSize: 16, color: Colors.black87)),
              ),
              const SizedBox(height: AppSpacing.md),
              if (capacity != null)
                Row(
                  children: const [
                    Icon(Icons.groups_outlined,
                        size: 18, color: Colors.black54),
                    SizedBox(width: 6),
                    Text('Места',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              if (capacity != null)
                Padding(
                  padding: const EdgeInsets.only(left: 24, top: 4),
                  child: Text(
                    'Свободных мест: ${freeSlots ?? capacity} из $capacity',
                    style: TextStyle(
                      fontSize: 16,
                      color: (freeSlots ?? capacity) == 0
                          ? Colors.red.shade600
                          : Colors.black87,
                    ),
                  ),
                ),
              if (capacity != null) const SizedBox(height: AppSpacing.md),
              const Text('Описание',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(ev.description),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_shouldShowStoriesSection(ev)) ...[
          _buildStoriesSection(ev),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_shouldShowPhotosSection(ev)) ...[
          _buildPhotoSection(ev),
          const SizedBox(height: AppSpacing.md),
        ],
        ..._buildParticipationWidgets(ev, isOwner),
      ],
    );
  }

  bool _shouldShowStoriesSection(Event ev) {
    return !ev.allowStories ||
        _canAddStory(ev) ||
        _stories.isNotEmpty ||
        _storiesLoading ||
        _storiesError != null ||
        (_isUploading && _uploadKind == _UploadKind.story);
  }

  bool _shouldShowPhotosSection(Event ev) {
    final now = DateTime.now();
    final ended = ev.endAt.isBefore(now);
    final userId = _auth?.user?.id;
    final canAdd = ended &&
        userId != null &&
        (userId == ev.ownerId ||
            _myParticipation?.status == 'approved' ||
            _myParticipation?.status == 'attended');
    return canAdd ||
        _photos.isNotEmpty ||
        _photosLoading ||
        _photosError != null ||
        (_isUploading && _uploadKind == _UploadKind.photo);
  }

  bool _canAddStory(Event ev) {
    final user = _auth?.user;
    if (user == null) return false;
    if (!ev.allowStories) return false;
    final now = DateTime.now();
    final started = !ev.startAt.isAfter(now);
    if (!started) return false;
    final ended = ev.endAt.isBefore(now);
    if (ended) return false;
    if (user.id == ev.ownerId) return true;
    final status = _myParticipation?.status;
    return status == 'approved' || status == 'attended';
  }

  Widget _buildStoriesSection(Event ev) {
    final theme = Theme.of(context);
    final canAdd = _canAddStory(ev);
    final groups = _storyGroups();
    final showUploadingStory = _isUploading && _uploadKind == _UploadKind.story;

    Widget? listStatus;
    if (_storiesLoading && !showUploadingStory) {
      listStatus = const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_storiesError != null) {
      listStatus = Text(
        'Не удалось загрузить истории: $_storiesError',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.error),
      );
    } else if (!showUploadingStory && groups.isEmpty && ev.allowStories) {
      listStatus = Text(
        canAdd ? 'Историй пока нет — добавьте первую!' : 'Историй пока нет.',
        style: theme.textTheme.bodyMedium,
      );
    }

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Истории события',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (canAdd)
                AppButton.secondary(
                  label: 'Добавить историю',
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  onPressed: _isUploading ? null : _addStory,
                  fullWidth: false,
                  busy: _isUploading && _uploadKind == _UploadKind.story,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!ev.allowStories)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'Истории отключены организатором',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          if (ev.endAt.isBefore(DateTime.now()))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'Событие завершилось — новые истории недоступны',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          if (listStatus != null) listStatus!,
          if (showUploadingStory)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'Загружаем $_uploadingLabel — можно продолжать пользоваться приложением.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          if (groups.isNotEmpty || showUploadingStory)
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: groups.length + (showUploadingStory ? 1 : 0),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  if (showUploadingStory) {
                    if (index == 0) {
                      return _UploadingStoryBubble(
                        progress: _uploadProgress,
                        icon: _uploadingIcon ?? Icons.cloud_upload_outlined,
                        label: _uploadingLabel,
                        previewPath: _uploadPreviewPath,
                        isVideo: _uploadPreviewIsVideo,
                      );
                    }
                    return _buildStoryBubble(groups[index - 1]);
                  }
                  return _buildStoryBubble(groups[index]);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(Event ev) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final ended = ev.endAt.isBefore(now);
    final userId = _auth?.user?.id;
    final canAdd = ended &&
        userId != null &&
        (userId == ev.ownerId ||
            _myParticipation?.status == 'approved' ||
            _myParticipation?.status == 'attended');

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Фотоотчет',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (canAdd)
                AppButton.secondary(
                  label: 'Добавить фото',
                  icon: const Icon(Icons.add_a_photo_outlined),
                  onPressed: _isUploading ? null : _addPhoto,
                  fullWidth: false,
                  busy: _isUploading && _uploadKind == _UploadKind.photo,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_isUploading && _uploadKind == _UploadKind.photo)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _uploadProgressRow(),
            )
          else if (_photosLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_photosError != null)
            Text(
              'Не удалось загрузить фото: $_photosError',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
            )
          else if (_photos.isEmpty)
            Text(
              canAdd
                  ? 'Пока нет фото — добавьте первое!'
                  : 'Фотоотчет пока пуст.',
              style: theme.textTheme.bodyMedium,
            )
          else
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
              ),
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                final photo = _photos[index];
                return GestureDetector(
                  onTap: () => _openPhotoViewer(index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      photo.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFEFF2F7),
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _uploadProgressRow() {
    final raw = _uploadProgress;
    final progress = raw != null ? (raw.clamp(0.0, 1.0) as double) : null;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: progress),
        const SizedBox(height: 4),
        Text(
          progress != null
              ? 'Загрузка $_uploadingLabel: ${(progress * 100).toStringAsFixed(0)}%'
              : 'Загружаем $_uploadingLabel...',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildStoryBubble(_StoryGroup group) {
    final theme = Theme.of(context);
    final name = group.title;
    final hasUnseen = group.stories.any((story) => !_seenStoryIds.contains(story.id));

    return InkWell(
      onTap: () => _openStoryViewer(group, 0),
      child: SizedBox(
        width: 82,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StoryAvatar(
              imageUrl: group.ownerAvatar ?? group.previewUrl,
              fallbackIcon:
                  group.hasVideo ? Icons.videocam_outlined : Icons.photo_outlined,
              highlight: hasUnseen,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight:
                    hasUnseen ? FontWeight.w600 : FontWeight.w500,
                color: hasUnseen
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              _storyDateFmt.format(group.updatedAt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: hasUnseen
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _storyGroupKey(EventStory story) {
    return story.author?.id ?? story.id;
  }

  void _pruneSeenStoryIds(Iterable<EventStory> stories) {
    final validIds = stories.map((s) => s.id).toSet();
    final before = _seenStoryIds.length;
    _seenStoryIds.removeWhere((id) => !validIds.contains(id));
    if (_seenStoryIds.length != before) {
      _persistSeenStoryIds();
    }
  }

  void _persistSeenStoryIds() {
    final prefs = _prefs;
    if (prefs == null) return;
    prefs.setStringList(
      _seenStoriesStorageKey,
      _seenStoryIds.toList(),
    );
  }

  List<_StoryGroup> _storyGroups() {
    final Map<String, List<EventStory>> grouped = {};
    final Map<String, String> titles = {};
    final Map<String, String?> authorIds = {};
    for (final story in _stories) {
      final authorId = story.author?.id;
      final key = _storyGroupKey(story);
      final title = story.author?.fullName ?? 'История';
      final list = grouped.putIfAbsent(key, () => []);
      list.add(story);
      titles[key] = title;
      authorIds[key] = authorId;
    }

    final groups = grouped.entries.map((entry) {
      final stories = List<EventStory>.from(entry.value)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final latest = stories.last;
      final hasVideo = stories.any((s) => _isVideoUrl(s.url));
      final previewStory = stories.lastWhere(
        (s) => !_isVideoUrl(s.url),
        orElse: () => stories.last,
      );
      final previewUrl =
          _isVideoUrl(previewStory.url) ? null : previewStory.url;
      String? ownerAvatar;
      for (final story in stories) {
        final avatar = story.author?.avatarUrl;
        if (avatar != null && avatar.isNotEmpty) {
          ownerAvatar = avatar;
          break;
        }
      }

      return _StoryGroup(
        id: entry.key,
        title: titles[entry.key]!,
        authorId: authorIds[entry.key],
        stories: stories,
        previewUrl: previewUrl,
        hasVideo: hasVideo,
        updatedAt: latest.createdAt,
        ownerAvatar: ownerAvatar,
      );
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return groups;
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm');
  }

  Future<void> _openStoryViewer(_StoryGroup group, int initialIndex) async {
    final stories = group.stories;
    if (stories.isEmpty) return;
    final userId = _auth?.user?.id;
    final isOwner = userId != null && userId == e?.ownerId;
    final isAuthor = userId != null && userId == group.authorId;
    final canDelete = isOwner || isAuthor;
    final firstUnseen = stories.indexWhere((s) => !_seenStoryIds.contains(s.id));
    final startIndex = firstUnseen >= 0 ? firstUnseen : initialIndex;
    await Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withOpacity(0.9),
      pageBuilder: (_, __, ___) => StoryViewer(
        stories: stories,
        initialIndex: startIndex,
        canDelete: canDelete,
        onDelete: canDelete ? _deleteStory : null,
        onViewed: (ids) {
          if (!mounted || ids.isEmpty) return;
          setState(() {
            _seenStoryIds.addAll(ids);
          });
          _persistSeenStoryIds();
        },
      ),
    ));
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openPhotoViewer(int initialIndex) async {
    if (_photos.isEmpty) return;
    final userId = _auth?.user?.id;
    final ev = e;
    final isOwner = userId != null && ev != null && userId == ev.ownerId;

    await Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withOpacity(0.9),
      pageBuilder: (_, __, ___) => PhotoReportViewer(
        photos: List<EventPhoto>.from(_photos),
        initialIndex: initialIndex,
        canDeleteBuilder: (photo) {
          final authorId = photo.author?.id;
          return isOwner || (userId != null && authorId == userId);
        },
        onDelete: _deletePhoto,
      ),
    ));
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
                (owner.avatarUrl != null && owner.avatarUrl!.isNotEmpty)
                    ? NetworkImage(owner.avatarUrl!)
                    : null,
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
              const Text('Организатор',
                  style: TextStyle(color: Colors.black54, fontSize: 12)),
              Text(name,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue)),
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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: statusColor, fontWeight: FontWeight.w600)),
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
                  Text('${participantReview.rating}/5',
                      style: const TextStyle(color: Colors.black54)),
                  if (participantReview.text != null &&
                      participantReview.text!.isNotEmpty)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                            'Отзыв организатора: ${participantReview.text!}',
                            style: const TextStyle(color: Colors.black54)),
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
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.orange.shade700),
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
      Text('Участники',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
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
      widgets.add(const Center(
          child: Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: CircularProgressIndicator())));
      return widgets;
    }

    if (_participantsError != null) {
      widgets.add(Text(
        'Ошибка загрузки участников: $_participantsError',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.error),
      ));
      return widgets;
    }

    if (_participants.isEmpty) {
      widgets.add(
          Text('Пока никто не записался', style: theme.textTheme.bodyMedium));
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
          backgroundImage:
              (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                  ? NetworkImage(user.avatarUrl!)
                  : null,
          child: (user?.avatarUrl == null || user!.avatarUrl!.isEmpty)
              ? Text(displayChar)
              : null,
        ),
        title: Text(
          user?.fullName ?? 'Участник',
          style:
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _statusLabel(p.status) ?? p.status,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: _statusColor(p.status) ??
                      theme.colorScheme.onSurfaceVariant),
            ),
            if (review != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    _buildStars(review.rating.toDouble(), size: 14),
                    const SizedBox(width: 6),
                    Text('${review.rating}/5',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12)),
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
                    onPressed: busy
                        ? null
                        : () => _updateParticipantStatus(p, 'rejected'),
                    label: 'Отклонить',
                  ),
                  AppButton.primary(
                    fullWidth: false,
                    onPressed: busy
                        ? null
                        : () => _updateParticipantStatus(p, 'approved'),
                    label: 'Подтвердить',
                    busy: busy,
                  ),
                ],
              )
            : canRate
                ? IconButton(
                    tooltip: review == null
                        ? 'Оценить участника'
                        : 'Изменить оценку',
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
        currentReview =
            _reviews.firstWhere((r) => r.author.id == currentUserId);
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
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!ended)
            Text(
              'Оценить событие можно после его завершения',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else if (currentReview != null) ...[
            Row(
              children: [
                _buildStars(currentReview!.rating.toDouble(), size: 22),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text('${currentReview!.rating}/5',
                      style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
            if (currentReview!.text != null && currentReview!.text!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(currentReview!.text!,
                    style: theme.textTheme.bodyMedium),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text('Вы уже оценили событие',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
      Text('Отзывы',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.sm),
    ];

    if (_reviewsLoading && _reviews.isEmpty) {
      widgets.add(const Center(child: CircularProgressIndicator()));
      return widgets;
    }

    if (_reviewsError != null) {
      widgets.add(Text(
        'Ошибка загрузки отзывов: $_reviewsError',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.error),
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
        Text(avg.toStringAsFixed(1),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text('  •  ${_reviews.length} отзывов',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
    final borderRadius =
        Theme.of(context).extension<AppThemeExtension>()?.panelRadius ??
            BorderRadius.circular(24);
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
                    backgroundImage: (review.author.avatarUrl != null &&
                            review.author.avatarUrl!.isNotEmpty)
                        ? NetworkImage(review.author.avatarUrl!)
                        : null,
                    child: (review.author.avatarUrl == null ||
                            review.author.avatarUrl!.isEmpty)
                        ? Text(
                            review.author.initials,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(review.author.fullName,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _buildStars(review.rating.toDouble(), size: 14),
                            const SizedBox(width: 6),
                            Text('${review.rating}/5',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormat('dd.MM.yyyy').format(review.createdAt),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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

class _StoryGroup {
  final String id;
  final String title;
  final String? authorId;
  final List<EventStory> stories;
  final String? previewUrl;
  final bool hasVideo;
  final DateTime updatedAt;
  final String? ownerAvatar;

  const _StoryGroup({
    required this.id,
    required this.title,
    required this.authorId,
    required this.stories,
    required this.previewUrl,
    required this.hasVideo,
    required this.updatedAt,
    required this.ownerAvatar,
  });
}

class _UploadingStoryBubble extends StatelessWidget {
  const _UploadingStoryBubble({
    required this.progress,
    required this.icon,
    required this.label,
    this.previewPath,
    this.isVideo = false,
  });

  final double? progress;
  final IconData icon;
  final String label;
  final String? previewPath;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = (progress != null && progress! > 0)
        ? progress!.clamp(0.0, 1.0)
        : null;
    final statusText = value != null
        ? '${(value * 100).toStringAsFixed(0)}%'
        : 'отправляем...';
    final trimmedLabel = label.trim();
    final displayLabel = trimmedLabel.isEmpty
        ? ''
        : '${trimmedLabel[0].toUpperCase()}${trimmedLabel.substring(1)}';
    final labelLine =
        displayLabel.isEmpty ? statusText : '$displayLabel · $statusText';

    return SizedBox(
      width: 82,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFFEDA75),
                        Color(0xFFFA7E1E),
                        Color(0xFFD62976),
                        Color(0xFF962FBF),
                        Color(0xFF4F5BD5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: ClipOval(
                      child: _buildPreview(theme),
                    ),
                  ),
                ),
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                    backgroundColor:
                        theme.colorScheme.surface.withOpacity(0.2),
                  ),
                ),
                if (isVideo)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Загрузка',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            labelLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final effectivePath = previewPath;
    if (effectivePath != null && effectivePath.isNotEmpty && !isVideo) {
      return Image.file(
        File(effectivePath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackPreview(theme),
      );
    }
    return _fallbackPreview(theme);
  }

  Widget _fallbackPreview(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 24,
        ),
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({
    this.imageUrl,
    required this.fallbackIcon,
    required this.highlight,
  });

  final String? imageUrl;
  final IconData fallbackIcon;
  final bool highlight;

  static const _gradientColors = [
    Color(0xFFFEDA75),
    Color(0xFFFA7E1E),
    Color(0xFFD62976),
    Color(0xFF962FBF),
    Color(0xFF4F5BD5),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: highlight
            ? const LinearGradient(
                colors: _gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        border: highlight
            ? null
            : Border.all(color: Colors.grey.shade300, width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipOval(
          child: hasImage
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(theme),
                )
              : _placeholder(theme),
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      color: const Color(0xFFEFF2F7),
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        color: theme.colorScheme.primary,
        size: 28,
      ),
    );
  }
}

enum _StoryMediaSource {
  galleryPhoto,
  galleryVideo,
  cameraPhoto,
  cameraVideo,
}

class _StoryMedia {
  final String path;
  final bool isVideo;

  const _StoryMedia({required this.path, required this.isVideo});
}

enum _UploadKind { story, photo }

class StoryViewer extends StatefulWidget {
  const StoryViewer({
    super.key,
    required this.stories,
    required this.initialIndex,
    required this.canDelete,
    this.onDelete,
    this.onViewed,
  });

  final List<EventStory> stories;
  final int initialIndex;
  final bool canDelete;
  final Future<bool> Function(String storyId)? onDelete;
  final void Function(List<String> seenStoryIds)? onViewed;

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late List<EventStory> _stories;
  late int _currentIndex;
  AnimationController? _progressController;
  VideoPlayerController? _videoController;
  bool _loading = true;
  final Set<String> _viewedStoryIds = {};
  bool _didNotify = false;

  @override
  void initState() {
    super.initState();
    _stories = List<EventStory>.from(widget.stories);
    final safeInitial = _stories.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, _stories.length - 1).toInt();
    _pageController = PageController(initialPage: safeInitial);
    _currentIndex = safeInitial;
    if (_stories.isNotEmpty) {
      _viewedStoryIds.add(_stories[_currentIndex].id);
    }
    _prepareStory();
  }

  @override
  void dispose() {
    _notifyViewed();
    _progressController?.dispose();
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool get _hasStories => _stories.isNotEmpty;

  EventStory get _currentStory => _stories[_currentIndex];

  bool _isVideo(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm');
  }

  Future<void> _prepareStory() async {
    if (!_hasStories) return;

    _progressController?.removeStatusListener(_handleProgressStatus);
    _progressController?.dispose();
    _progressController = null;

    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;

    setState(() => _loading = true);

    final story = _currentStory;
    if (_isVideo(story.url)) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(story.url));
      _videoController = controller;
      try {
        await controller.initialize();
        if (!mounted || _videoController != controller) return;
        var duration = controller.value.duration;
        if (duration == Duration.zero) {
          duration = const Duration(seconds: 5);
        }
        if (duration > const Duration(seconds: 30)) {
          duration = const Duration(seconds: 30);
        }
        _progressController =
            AnimationController(vsync: this, duration: duration)
              ..addListener(() => setState(() {}))
              ..addStatusListener(_handleProgressStatus)
              ..forward();

        controller
          ..setLooping(false)
          ..play();

        setState(() => _loading = false);
      } catch (_) {
        if (!mounted) return;
        setState(() => _loading = false);
        _nextStory();
      }
    } else {
      _progressController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 5),
      )
        ..addListener(() => setState(() {}))
        ..addStatusListener(_handleProgressStatus)
        ..forward();

      setState(() => _loading = false);
    }
  }

  void _handleProgressStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _nextStory();
    }
  }

  void _pauseStory() {
    _progressController?.stop();
    _videoController?.pause();
  }

  void _resumeStory() {
    if ((_progressController?.isAnimating ?? false) == false) {
      _progressController?.forward();
    }
    if (_videoController != null && !(_videoController!.value.isPlaying)) {
      _videoController!.play();
    }
  }

  void _notifyViewed() {
    if (_didNotify) return;
    _didNotify = true;
    if (_viewedStoryIds.isNotEmpty) {
      widget.onViewed?.call(_viewedStoryIds.toList());
    }
  }

  void _closeViewer() {
    _notifyViewed();
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _deleteCurrentStory() async {
    if (!(widget.canDelete && widget.onDelete != null)) return;
    if (_stories.isEmpty) return;

    final storyId = _stories[_currentIndex].id;
    final success = await widget.onDelete!(storyId);
    if (!success || !mounted) {
      _resumeStory();
      return;
    }

    _progressController?.stop();
    _videoController?.pause();

    setState(() {
      _stories.removeAt(_currentIndex);
      if (_currentIndex >= _stories.length) {
        _currentIndex = _stories.length - 1;
      }
      if (_stories.isNotEmpty && _currentIndex >= 0) {
        _viewedStoryIds.add(_stories[_currentIndex].id);
      }
    });

    if (_stories.isEmpty) {
      _closeViewer();
      return;
    }

    await Future.delayed(Duration.zero);
    _pageController.jumpToPage(_currentIndex);
    await _prepareStory();
  }

  void _nextStory() {
    _progressController?.stop();
    _videoController?.pause();
    if (_currentIndex >= _stories.length - 1) {
      _closeViewer();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
    );
  }

  void _prevStory() {
    _progressController?.stop();
    _videoController?.pause();
    if (_currentIndex == 0) {
      _closeViewer();
      return;
    }
    _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasStories) return const SizedBox.shrink();

    final story = _currentStory;
    final isVideo = _isVideo(story.url);
    final videoReady = _videoController?.value.isInitialized ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.localPosition.dx < width * 0.33) {
            _prevStory();
          } else if (details.localPosition.dx > width * 0.66) {
            _nextStory();
          } else {
            if (isVideo) {
              if (_videoController?.value.isPlaying == true) {
                _pauseStory();
              } else {
                _resumeStory();
              }
            }
          }
        },
        onLongPress: _pauseStory,
        onLongPressEnd: (_) => _resumeStory(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _stories.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                if (_stories.isNotEmpty && index < _stories.length) {
                  _viewedStoryIds.add(_stories[index].id);
                }
                _prepareStory();
              },
              itemBuilder: (_, index) {
                final item = _stories[index];
                final itemIsVideo = _isVideo(item.url);
                final isCurrent = index == _currentIndex;

                if (itemIsVideo && isCurrent) {
                  if (videoReady) {
                    return Center(
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio == 0
                            ? 9 / 16
                            : _videoController!.value.aspectRatio,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: VideoPlayer(_videoController!),
                        ),
                      ),
                    );
                  }
                  return const Center(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                return Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        item.url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.black54,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined,
                              color: Colors.white70, size: 48),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_loading)
              Positioned(
                bottom: widget.canDelete && widget.onDelete != null ? 90 : 40,
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(color: Colors.white70),
                ),
              ),
            Positioned(
              top: 48,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressBarRow(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          story.author?.fullName ?? 'История',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimeAgo(story.createdAt),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 40,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: _closeViewer,
              ),
            ),
            if (widget.canDelete && widget.onDelete != null)
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: FilledButton.tonal(
                    onPressed: _loading ? null : _deleteCurrentStory,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.18),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                    child: const Text('Удалить историю'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBarRow() {
    final total = _stories.length;
    final currentValue = _progressController?.value ?? 0;

    return Row(
      children: List.generate(total, (index) {
        double value;
        if (index < _currentIndex) {
          value = 1;
        } else if (index == _currentIndex) {
          value = currentValue.clamp(0, 1);
        } else {
          value = 0;
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white24,
                color: Colors.white,
                minHeight: 3,
              ),
            ),
          ),
        );
      }),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) {
      return 'только что';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} мин назад';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} ч назад';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} дн назад';
    }
    return DateFormat('dd.MM HH:mm').format(time);
  }
}

class PhotoReportViewer extends StatefulWidget {
  const PhotoReportViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.canDeleteBuilder,
    required this.onDelete,
  });

  final List<EventPhoto> photos;
  final int initialIndex;
  final bool Function(EventPhoto photo) canDeleteBuilder;
  final Future<bool> Function(String photoId) onDelete;

  @override
  State<PhotoReportViewer> createState() => _PhotoReportViewerState();
}

class _PhotoReportViewerState extends State<PhotoReportViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  EventPhoto get _currentPhoto => widget.photos[_currentIndex];

  Future<void> _deleteCurrent() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final success = await widget.onDelete(_currentPhoto.id);
      if (!success || !mounted) return;
      if (widget.photos.length == 1) {
        Navigator.of(context).maybePop();
        return;
      }
      setState(() {
        widget.photos.removeAt(_currentIndex);
        final newIndex = _currentIndex.clamp(0, widget.photos.length - 1);
        _currentIndex = newIndex;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pageController.jumpToPage(_currentIndex);
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return const SizedBox.shrink();
    }

    final canDelete = widget.canDeleteBuilder(_currentPhoto);

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.95),
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (_, index) {
                final photo = widget.photos[index];
                return Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        photo.url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.black54,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined,
                              size: 56, color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 16,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Positioned(
              top: 48,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _currentPhoto.author?.fullName ?? 'Фотография',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        DateFormat('dd.MM HH:mm')
                            .format(_currentPhoto.createdAt),
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (canDelete)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: FilledButton.tonal(
                    onPressed: _busy ? null : _deleteCurrent,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.18),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Удалить фото'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
