import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/admin_notification.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/theme_controller.dart';
import 'supabase_admin_service.dart';

final notificationProvider =
    StateNotifierProvider<NotificationController, List<AdminNotification>>(
        (ref) {
  return NotificationController(
    ref.watch(sharedPreferencesProvider),
    supabase: ref.watch(supabaseAdminServiceProvider),
    syncEnabled: ref.watch(supabaseEnabledProvider),
  );
});

class NotificationController extends StateNotifier<List<AdminNotification>> {
  NotificationController(
    this._preferences, {
    SupabaseAdminService? supabase,
    bool syncEnabled = false,
  })  : _supabase = supabase,
        super(const []) {
    _restore();
    if (syncEnabled && _supabase != null) {
      unawaited(_syncNotifications());
      _syncTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _syncNotifications(),
      );
    }
  }

  final SharedPreferences _preferences;
  final SupabaseAdminService? _supabase;
  final Set<String> _dismissed = <String>{};
  Timer? _syncTimer;
  bool _syncing = false;

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  int get unreadCount => state.where((item) => !item.isRead).length;

  void addNotification({
    required String title,
    required String message,
    required NotificationType type,
    NotificationTarget? target,
    String? actionLabel,
  }) {
    final item = AdminNotification(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      type: type,
      createdAt: DateTime.now(),
      isRead: false,
      target: target,
      actionLabel: actionLabel,
    );
    state = [item, ...state];
  }

  Future<void> markRead(String id) async {
    state = [
      for (final item in state)
        item.id == id ? item.copyWith(isRead: true) : item,
    ];
    await _persistReadState();
  }

  Future<void> markAllRead() async {
    state = [for (final item in state) item.copyWith(isRead: true)];
    await _persistReadState();
  }

  Future<void> dismiss(String id) async {
    _dismissed.add(id);
    state = state.where((item) => item.id != id).toList();
    await _persistDismissedState();
  }

  Future<void> clearRead() async {
    state = state.where((item) => !item.isRead).toList();
    await _persistReadState();
    await _persistDismissedState();
  }

  Future<void> _restore() async {
    final read = _preferences.getStringList('admin_notification_read') ?? [];
    _dismissed.addAll(
      _preferences.getStringList('admin_notification_dismissed') ?? [],
    );
    final readIds = read.toSet();
    state = state
        .where((item) => !_dismissed.contains(item.id))
        .map((item) =>
            item.copyWith(isRead: item.isRead || readIds.contains(item.id)))
        .toList();
  }

  Future<void> _syncNotifications() async {
    if (_syncing || !mounted) return;
    _syncing = true;
    try {
      final remote = await _supabase!.fetchNotifications();
      if (!mounted) return;
      final remoteIds = remote.map((item) => item.id).toSet();
      final localOnly = state.where(
        (item) => item.id.startsWith('notif-') && !remoteIds.contains(item.id),
      );
      final readIds =
          (_preferences.getStringList('admin_notification_read') ?? []).toSet();
      state = [...remote, ...localOnly]
          .where((item) => !_dismissed.contains(item.id))
          .map((item) => item.copyWith(
                isRead: item.isRead || readIds.contains(item.id),
              ))
          .toList();
    } catch (error) {
      debugPrint('[admin] Notification sync failed: $error');
    } finally {
      _syncing = false;
    }
  }

  Future<void> _persistReadState() => _preferences.setStringList(
        'admin_notification_read',
        state.where((item) => item.isRead).map((item) => item.id).toList(),
      );

  Future<void> _persistDismissedState() => _preferences.setStringList(
        'admin_notification_dismissed',
        _dismissed.toList(),
      );
}
