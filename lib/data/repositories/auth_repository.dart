import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/theme_controller.dart';
import '../../models/admin_models.dart';
import 'firebase_admin_service.dart';

const defaultAdminName = 'Kirren Michael Fraginal';
const defaultAdminEmail = 'admin@palengkego.gov.ph';
const defaultAdminPassword = 'Admin123!';

class AdminProfile {
  const AdminProfile({
    required this.name,
    required this.email,
    required this.password,
    this.avatarBytes,
  });

  final String name;
  final String email;
  final String password;
  final Uint8List? avatarBytes;

  AdminProfile copyWith({
    String? name,
    String? password,
    Uint8List? avatarBytes,
  }) =>
      AdminProfile(
        name: name ?? this.name,
        email: email,
        password: password ?? this.password,
        avatarBytes: avatarBytes ?? this.avatarBytes,
      );
}

Uint8List? _readAdminAvatar(SharedPreferences preferences) {
  final encoded = preferences.getString('admin_avatar');
  if (encoded == null || encoded.isEmpty) return null;
  try {
    return base64Decode(encoded);
  } on FormatException {
    return null;
  }
}

final adminProfileProvider =
    StateNotifierProvider<AdminProfileController, AdminProfile>((ref) {
  return AdminProfileController(ref.watch(sharedPreferencesProvider));
});

class AdminProfileController extends StateNotifier<AdminProfile> {
  AdminProfileController(this._preferences)
      : super(
          AdminProfile(
            name: _preferences.getString('admin_name') ?? defaultAdminName,
            email: defaultAdminEmail,
            password: _preferences.getString('admin_password') ??
                defaultAdminPassword,
            avatarBytes: _readAdminAvatar(_preferences),
          ),
        );

  final SharedPreferences _preferences;

  Future<void> updateProfile({
    required String name,
    String? password,
    Uint8List? avatarBytes,
    bool removeAvatar = false,
  }) async {
    final nextPassword = password == null || password.trim().isEmpty
        ? state.password
        : password.trim();
    final nextAvatar = removeAvatar ? null : avatarBytes ?? state.avatarBytes;
    state = AdminProfile(
      name: name.trim(),
      email: state.email,
      password: nextPassword,
      avatarBytes: nextAvatar,
    );
    await _preferences.setString('admin_name', state.name);
    await _preferences.setString('admin_password', state.password);
    if (nextAvatar == null) {
      await _preferences.remove('admin_avatar');
    } else {
      await _preferences.setString('admin_avatar', base64Encode(nextAvatar));
    }
  }
}

final authProvider = StateNotifierProvider<AuthController, bool>((ref) {
  return AuthController(ref.watch(sharedPreferencesProvider))
    .._attachFirebase(ref);
});

class AuthController extends StateNotifier<bool> {
  AuthController(this._preferences)
      : super(_preferences.getBool('isLoggedIn') ?? false);

  final SharedPreferences _preferences;
  bool _firebase = false;

  /// In Firebase mode the Auth SDK owns the session; mirror it into this
  /// notifier so the existing router redirect keeps working unchanged.
  void _attachFirebase(Ref ref) {
    _firebase = ref.read(firebaseEnabledProvider);
    if (!_firebase) return;
    FirebaseAdminService.instance.authState.listen((signedIn) {
      state = signedIn;
    });
  }

  Future<String?> login(
    String email,
    String password,
    bool keepSignedIn,
  ) async {
    if (_firebase) {
      final error =
          await FirebaseAdminService.instance.signIn(email, password);
      if (error == null) state = true;
      return error;
    }
    await Future<void>.delayed(const Duration(milliseconds: 550));
    final savedPassword =
        _preferences.getString('admin_password') ?? defaultAdminPassword;
    if (email.trim().toLowerCase() != defaultAdminEmail ||
        password != savedPassword) {
      return 'The email or password is incorrect.';
    }
    state = true;
    await _preferences.setBool('isLoggedIn', keepSignedIn);
    await _appendAuthAudit(_preferences, AuditAction.login);
    return null;
  }

  Future<void> logout() async {
    if (_firebase) {
      await FirebaseAdminService.instance.signOut();
      state = false; // also arrives via the authState listener
      return;
    }
    await _appendAuthAudit(_preferences, AuditAction.logout);
    state = false;
    await _preferences.remove('isLoggedIn');
  }
}

Future<void> _appendAuthAudit(
  SharedPreferences preferences,
  AuditAction action,
) async {
  final now = DateTime.now();
  final audit = AuditLog(
    id: 'AUD-${now.microsecondsSinceEpoch}',
    administratorId: 'ADM-001',
    administratorName: preferences.getString('admin_name') ?? defaultAdminName,
    action: action,
    targetEntityType: 'Authentication',
    targetEntityId: 'admin-session',
    targetUserName: defaultAdminEmail,
    previousValue: action == AuditAction.login ? 'Signed out' : 'Signed in',
    newValue: action == AuditAction.login ? 'Signed in' : 'Signed out',
    reason: '',
    metadata: const {},
    timestamp: now,
  );
  final existing = preferences.getStringList('admin_audit_logs') ?? <String>[];
  await preferences.setStringList(
    'admin_audit_logs',
    [
      jsonEncode({
        'id': audit.id,
        'administratorId': audit.administratorId,
        'administratorName': audit.administratorName,
        'action': audit.action.name,
        'targetEntityType': audit.targetEntityType,
        'targetEntityId': audit.targetEntityId,
        'targetUserName': audit.targetUserName,
        'previousValue': audit.previousValue,
        'newValue': audit.newValue,
        'reason': audit.reason,
        'metadata': audit.metadata,
        'timestamp': audit.timestamp.toIso8601String(),
      }),
      ...existing,
    ],
  );
}
