import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_models.dart';
import 'mock_repository.dart';

export '../../models/app_models.dart' show Announcement;

/// Reactive provider for the list of market announcements.
final announcementsProvider = Provider<List<Announcement>>((ref) {
  return ref.watch(appDataProvider.select((state) => state.announcements));
});

/// Direct domain repository for announcement operations.
final announcementsRepositoryProvider = Provider<AnnouncementsRepository>((ref) {
  return AnnouncementsRepository(ref);
});

class AnnouncementsRepository {
  const AnnouncementsRepository(this._ref);

  final Ref _ref;

  AppDataController get _controller => _ref.read(appDataProvider.notifier);

  Future<void> addAnnouncement(Announcement announcement) =>
      _controller.addAnnouncement(announcement);

  Future<void> updateAnnouncement(Announcement updated) =>
      _controller.updateAnnouncement(updated);

  Future<void> deleteAnnouncement(String id) =>
      _controller.deleteAnnouncement(id);
}
