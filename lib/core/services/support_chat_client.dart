import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Firebase-authenticated admin/stallholder support; never uses local fake sends.
class SupportChatClient {
  SupportChatClient(
    this.backend,
    this.auth, {
    required String url,
    required String anonKey,
  }) {
    realtime = SupabaseClient(
      url,
      anonKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      accessToken: () async {
        final user = auth.currentUser;
        if (user == null) throw StateError('Sign in to use messaging.');
        final result = await user.getIdTokenResult();
        if (result.claims?['role'] != 'authenticated') {
          await backend.functions.invoke(
            'chat-auth',
            headers: {'Authorization': 'Bearer ${result.token}'},
          );
          return user.getIdToken(true);
        }
        return result.token;
      },
    );
  }
  final SupabaseClient backend;
  final FirebaseAuth auth;
  late final SupabaseClient realtime;
  final _local = StreamController<String>.broadcast();
  final Map<String, Map<String, dynamic>> _cursors = {};
  final Map<String, Map<String, Map<String, dynamic>>> _rows = {};
  final Map<String, Future<List<Map<String, dynamic>>>> _loading = {};
  bool _disposed = false;
  int _channelId = 0;

  Future<Map<String, dynamic>> request(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    final token = await auth.currentUser?.getIdToken();
    if (token == null) throw StateError('Sign in to use messaging.');
    try {
      final response = await backend.functions.invoke(
        'support-messaging',
        body: {'action': action, ...data},
        headers: {'Authorization': 'Bearer $token'},
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map && details['error'] is Map
          ? details['error']['message']
          : null;
      throw StateError(
        message?.toString() ?? 'Messaging is unavailable. Please retry.',
      );
    }
  }

  bool hasOlder(String key) => _cursors.containsKey(key);
  void refresh(String key) {
    if (!_disposed) _local.add(key);
  }

  Future<List<Map<String, dynamic>>> load(String key, {bool older = false}) {
    return _loading[key] ??= _load(key, older: older).whenComplete(() {
      _loading.remove(key);
    });
  }

  Future<List<Map<String, dynamic>>> _load(
    String key, {
    required bool older,
  }) async {
    final conversations = key == 'conversations';
    final previous = _rows[key]?.values.toList() ?? <Map<String, dynamic>>[];
    previous.sort((a, b) {
      final at = a['created_at'].toString().compareTo(
            b['created_at'].toString(),
          );
      return at == 0 ? a['id'].toString().compareTo(b['id'].toString()) : at;
    });
    final result =
        await request(conversations ? 'list-conversations' : 'messages', {
      if (!conversations) 'conversationId': key,
      if (older && _cursors[key] != null) 'before': _cursors[key],
    });
    final cache = _rows.putIfAbsent(key, () => {});
    final items = (result[conversations ? 'conversations' : 'messages'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    if (!conversations && !older && previous.isNotEmpty) {
      Map<String, dynamic>? after = {
        'at': previous.last['created_at'],
        'id': previous.last['id'],
      };
      while (after != null) {
        final newer = await request('messages', {
          'conversationId': key,
          'after': after,
        });
        for (final row in newer['messages'] as List) {
          cache[row['id'].toString()] = Map<String, dynamic>.from(row as Map);
        }
        final next = newer['nextCursor'];
        after = next is Map ? Map<String, dynamic>.from(next) : null;
      }
    }
    for (final row in items) {
      cache[row['id'].toString()] = row;
    }
    if (conversations || older || cache.length <= items.length) {
      final cursor = result['nextCursor'];
      if (cursor is Map) {
        _cursors[key] = Map<String, dynamic>.from(cursor);
      } else {
        _cursors.remove(key);
      }
    }
    final sorted = cache.values.toList()
      ..sort((a, b) {
        final field = conversations ? 'updated_at' : 'created_at';
        final cmp = a[field].toString().compareTo(b[field].toString());
        final order =
            cmp == 0 ? a['id'].toString().compareTo(b['id'].toString()) : cmp;
        return conversations ? -order : order;
      });
    return sorted;
  }

  Future<void> loadOlder(String key) async {
    if (!hasOlder(key)) return;
    await load(key, older: true);
    refresh(key);
  }

  Stream<List<Map<String, dynamic>>> watch(String key) async* {
    final events = StreamController<void>();
    Timer? debounce;
    bool queued = false;
    void notify() {
      if (events.isClosed || queued || debounce != null) return;
      debounce = Timer(const Duration(milliseconds: 150), () {
        debounce = null;
        if (!events.isClosed && !queued) {
          queued = true;
          events.add(null);
        }
      });
    }

    final localSub =
        _local.stream.where((event) => event == key).listen((_) => notify());
    final table =
        key == 'conversations' ? 'support_conversations' : 'support_messages';
    final channel = realtime.channel('support-$key-${_channelId++}');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      filter: key == 'conversations'
          ? null
          : PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: key,
            ),
      callback: (_) => notify(),
    );
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) notify();
      if (status == RealtimeSubscribeStatus.channelError && !events.isClosed) {
        events.addError(
          StateError('Live updates disconnected. Reopen messaging to retry.'),
        );
      }
    });
    try {
      yield await load(key);
      await for (final _ in events.stream) {
        queued = false;
        yield await load(key);
      }
    } finally {
      debounce?.cancel();
      await localSub.cancel();
      await realtime.removeChannel(channel);
      unawaited(events.close());
    }
  }

  Future<String> upload(String id, String dataUri) async {
    final match = RegExp(
      r'^data:(image/(?:jpeg|png|webp|gif));base64,(.+)$',
      dotAll: true,
    ).firstMatch(dataUri);
    if (match == null) {
      throw StateError('Choose a JPEG, PNG, WebP or GIF photo.');
    }
    final Uint8List bytes = base64Decode(match.group(2)!);
    if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
      throw StateError('Photos must be at most 2 MB.');
    }
    final signed = await request('upload-photo', {
      'conversationId': id,
      'mime': match.group(1),
    });
    await backend.storage.from('support-attachments').uploadBinaryToSignedUrl(
          signed['path'] as String,
          signed['token'] as String,
          bytes,
          FileOptions(contentType: match.group(1)),
        );
    return signed['path'] as String;
  }

  Future<Map<String, dynamic>> send(
    String id,
    String text, {
    String? image,
  }) async {
    final path = image == null ? null : await upload(id, image);
    final args = <String, dynamic>{'conversationId': id, 'message': text};
    if (path != null) args['attachmentPath'] = path;
    final response = await request('send-message', args);
    refresh(id);
    refresh('conversations');
    return Map<String, dynamic>.from(response['message'] as Map);
  }

  Future<void> markRead(String id) async {
    await request('mark-read', {'conversationId': id});
    for (final row in _rows[id]?.values ?? <Map<String, dynamic>>[]) {
      if (row['sender_user_id'] != auth.currentUser?.uid &&
          row['read_at'] == null) {
        row['read_at'] = DateTime.now().toUtc().toIso8601String();
      }
    }
    refresh(id);
    refresh('conversations');
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    unawaited(_local.close());
    unawaited(realtime.dispose());
  }
}
