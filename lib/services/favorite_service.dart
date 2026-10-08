import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_application_1/models/favorite_job_model.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/job_service.dart';

class FavoriteService {
  static final FavoriteService _instance = FavoriteService._internal();

  factory FavoriteService() {
    return _instance;
  }

  FavoriteService._internal();

  final Map<String, FavoriteJob> _favorites = {};
  late final Future<SharedPreferences> _preferences =
      SharedPreferences.getInstance();
  late final Future<void> _initialization = _loadPersistedState();
  Future<void> _writeQueue = Future<void>.value();

  Future<void> initialize() => _initialization;

  // Add to favorites
  Future<FavoriteJob> addToFavorites({
    required String jobSeekerId,
    required String jobId,
  }) async {
    await initialize();
    _requireSeeker(jobSeekerId);
    final job = await JobService().getJobById(jobId);
    if (job == null || !job.isActive) {
      throw Exception('Only active jobs can be saved');
    }

    // Check if already favorited
    if (_favorites.values.any(
      (fav) => fav.jobSeekerId == jobSeekerId && fav.jobId == jobId,
    )) {
      throw Exception('Job already in favorites');
    }

    final favorite = FavoriteJob(
      id: const Uuid().v4(),
      jobSeekerId: jobSeekerId,
      jobId: jobId,
      savedDate: DateTime.now(),
    );

    _favorites[favorite.id] = favorite;
    await _persistFavorites();
    return favorite;
  }

  // Remove from favorites
  Future<bool> removeFromFavorites({
    required String jobSeekerId,
    required String jobId,
  }) async {
    await initialize();
    _requireSeeker(jobSeekerId);

    final favorite = _favorites.values.firstWhere(
      (fav) => fav.jobSeekerId == jobSeekerId && fav.jobId == jobId,
      orElse: () => throw Exception('Favorite not found'),
    );

    _favorites.remove(favorite.id);
    await _persistFavorites();
    return true;
  }

  // Get favorites by job seeker
  Future<List<FavoriteJob>> getFavoritesByJobSeeker(String jobSeekerId) async {
    await initialize();
    _requireSeeker(jobSeekerId);
    return _favorites.values
        .where((fav) => fav.jobSeekerId == jobSeekerId)
        .toList();
  }

  // Check if job is favorited
  Future<bool> isFavorited({
    required String jobSeekerId,
    required String jobId,
  }) async {
    await initialize();
    _requireSeeker(jobSeekerId);
    return _favorites.values.any(
      (fav) => fav.jobSeekerId == jobSeekerId && fav.jobId == jobId,
    );
  }

  Future<void> removeForUser(String userId, Set<String> jobIds) async {
    await initialize();
    if (AuthService().currentUser?.userType != UserType.administrator) {
      throw Exception('Administrator access required');
    }
    _favorites.removeWhere(
      (_, favorite) =>
          favorite.jobSeekerId == userId || jobIds.contains(favorite.jobId),
    );
    await _persistFavorites();
  }

  void _requireSeeker(String jobSeekerId) {
    final user = AuthService().currentUser;
    if (user == null ||
        user.userType != UserType.jobSeeker ||
        user.id != jobSeekerId) {
      throw Exception('Only the signed-in job seeker can manage saved jobs');
    }
  }

  Future<void> _loadPersistedState() async {
    final preferences = await _preferences;
    final encoded = preferences.getString('favorites.records');
    if (encoded == null) return;
    try {
      final records = jsonDecode(encoded) as List<dynamic>;
      for (final record in records) {
        final favorite = FavoriteJob.fromJson(record as Map<String, dynamic>);
        _favorites[favorite.id] = favorite;
      }
    } catch (_) {
      await preferences.remove('favorites.records');
    }
  }

  Future<void> _persistFavorites() => _enqueueWrite(
    () async => (await _preferences).setString(
      'favorites.records',
      jsonEncode(_favorites.values.map((item) => item.toJson()).toList()),
    ),
  );

  Future<void> _enqueueWrite(Future<void> Function() action) {
    _writeQueue = _writeQueue.then((_) => action());
    return _writeQueue;
  }
}
