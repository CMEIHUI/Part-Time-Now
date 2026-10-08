import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/services/application_service.dart';
import 'package:flutter_application_1/services/favorite_service.dart';
import 'package:flutter_application_1/services/job_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal() {
    final administrator = User(
      id: 'system-administrator',
      name: 'System Administrator',
      email: 'admin@parttimenow.local',
      passwordHash: _hashPassword('Admin123!'),
      userType: UserType.administrator,
      createdAt: DateTime.now(),
    );
    _users[administrator.id] = administrator;
  }

  User? _currentUser;
  final Map<String, User> _users = {};
  late final Future<SharedPreferences> _preferences =
      SharedPreferences.getInstance();
  late final Future<void> _initialization = _loadPersistedState();
  Future<void> _writeQueue = Future<void>.value();

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<void> initialize() => _initialization;

  List<User> get users {
    _requireAdministrator();
    return List.unmodifiable(_users.values);
  }

  User? getUserById(String userId) {
    final role = _currentUser?.userType;
    if (role != UserType.employer && role != UserType.administrator) {
      throw Exception('Employer or administrator access required');
    }
    return _users[userId];
  }

  // Register new user
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required UserType userType,
    String? phone,
  }) async {
    await initialize();
    if (isLoggedIn) {
      throw Exception('Log out before creating another account');
    }
    if (userType == UserType.administrator) {
      throw Exception('Administrator accounts cannot be registered publicly');
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (name.trim().length < 2 ||
        normalizedEmail.isEmpty ||
        password.length < 8) {
      throw Exception('Enter a name and email with an 8-character password');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizedEmail)) {
      throw Exception('Invalid email address');
    }
    if (phone != null &&
        phone.trim().isNotEmpty &&
        !RegExp(r'^[0-9+()\-\s]{7,20}$').hasMatch(phone.trim())) {
      throw Exception('Invalid phone number');
    }
    if (_users.values.any((user) => user.email == normalizedEmail)) {
      throw Exception('Email already registered');
    }

    final user = User(
      id: const Uuid().v4(),
      name: name.trim(),
      email: normalizedEmail,
      passwordHash: _hashPassword(password),
      userType: userType,
      phone: phone?.trim(),
      createdAt: DateTime.now(),
    );

    _users[user.id] = user;
    _currentUser = user;
    await _persistState();
    return true;
  }

  // Login user
  Future<bool> login({required String email, required String password}) async {
    await initialize();
    final normalizedEmail = email.trim().toLowerCase();
    final user = _users.values.firstWhere(
      (user) =>
          user.email == normalizedEmail &&
          user.passwordHash == _hashPassword(password),
      orElse: () => throw Exception('Invalid email or password'),
    );
    _currentUser = user;
    await _enqueueWrite(
      () async => (await _preferences).setString('auth.currentUserId', user.id),
    );
    return true;
  }

  // Logout user
  void logout() {
    _currentUser = null;
    _enqueueWrite(
      () async => (await _preferences).remove('auth.currentUserId'),
    );
  }

  void _requireAdministrator() {
    if (_currentUser?.userType != UserType.administrator) {
      throw Exception('Administrator access required');
    }
  }

  String _hashPassword(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  // Update user profile
  Future<bool> updateProfile({
    required String name,
    String? phone,
    String? profileImage,
  }) async {
    await initialize();
    if (_currentUser == null) {
      throw Exception('No user logged in');
    }

    if (name.trim().length < 2) throw Exception('Name is required');
    _currentUser = _currentUser!.copyWith(
      name: name.trim(),
      phone: phone?.trim(),
      profileImage: profileImage,
    );
    _users[_currentUser!.id] = _currentUser!;
    await _persistState();
    return true;
  }

  Future<bool> removeUser(String userId) async {
    await initialize();
    _requireAdministrator();
    if (userId == _currentUser!.id) {
      throw Exception('The administrator account cannot be removed');
    }
    final user = _users[userId];
    if (user == null) throw Exception('User not found');
    final jobIds = user.userType == UserType.employer
        ? await JobService().removeJobsForEmployer(userId)
        : <String>[];
    final affectedJobIds = await ApplicationService().removeForUser(
      userId,
      jobIds.toSet(),
    );
    if (user.userType == UserType.jobSeeker) {
      await JobService().removeApplicantCounts(affectedJobIds);
    }
    await FavoriteService().removeForUser(userId, jobIds.toSet());
    _users.remove(userId);
    await _persistUsers();
    return true;
  }

  Future<void> _loadPersistedState() async {
    final preferences = await _preferences;
    final encodedUsers = preferences.getString('auth.users');
    if (encodedUsers != null) {
      try {
        final decoded = jsonDecode(encodedUsers) as List<dynamic>;
        for (final item in decoded) {
          final user = User.fromJson(item as Map<String, dynamic>);
          _users[user.id] = user;
        }
      } catch (_) {
        await preferences.remove('auth.users');
      }
    }
    final sessionId = preferences.getString('auth.currentUserId');
    _currentUser = sessionId == null ? null : _users[sessionId];
    if (sessionId != null && _currentUser == null) {
      await preferences.remove('auth.currentUserId');
    }
  }

  Future<void> _persistState() async {
    await _persistUsers();
    await _enqueueWrite(
      () async => (await _preferences).setString(
        'auth.currentUserId',
        _currentUser!.id,
      ),
    );
  }

  Future<void> _persistUsers() => _enqueueWrite(
    () async => (await _preferences).setString(
      'auth.users',
      jsonEncode(_users.values.map((user) => user.toJson()).toList()),
    ),
  );

  Future<void> _enqueueWrite(Future<void> Function() action) {
    _writeQueue = _writeQueue.then((_) => action());
    return _writeQueue;
  }
}
