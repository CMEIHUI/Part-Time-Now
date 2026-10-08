import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_application_1/models/job_model.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/services/auth_service.dart';

class JobService {
  static final JobService _instance = JobService._internal();

  factory JobService() {
    return _instance;
  }

  JobService._internal();

  final Map<String, Job> _jobs = {};
  late final Future<SharedPreferences> _preferences =
      SharedPreferences.getInstance();
  late final Future<void> _initialization = _loadPersistedState();
  Future<void> _writeQueue = Future<void>.value();

  Future<void> initialize() => _initialization;

  void _initializeSampleData() {
    // Add sample jobs
    final sampleJobs = [
      Job(
        id: 'sample-flutter-developer',
        employerId: 'emp1',
        jobTitle: 'Flutter Developer',
        description:
            'We are looking for an experienced Flutter developer to join our team and build amazing mobile applications.',
        location: 'San Francisco, CA',
        salary: '\$50,000 - \$70,000',
        requirements: [
          '3+ years of Flutter experience',
          'Strong Dart knowledge',
          'Experience with REST APIs',
        ],
        postedDate: DateTime.now().subtract(const Duration(days: 5)),
        deadline: DateTime.now().add(const Duration(days: 25)),
        jobType: 'Part-time',
        applicantCount: 5,
      ),
      Job(
        id: 'sample-web-designer',
        employerId: 'emp2',
        jobTitle: 'Web Designer',
        description:
            'Join our creative team and design beautiful, user-friendly websites.',
        location: 'New York, NY',
        salary: '\$40,000 - \$60,000',
        requirements: [
          'Proficiency in UI/UX design',
          'Knowledge of Figma or Adobe XD',
          'Portfolio of previous work',
        ],
        postedDate: DateTime.now().subtract(const Duration(days: 3)),
        deadline: DateTime.now().add(const Duration(days: 27)),
        jobType: 'Part-time',
        applicantCount: 8,
      ),
      Job(
        id: 'sample-data-analyst',
        employerId: 'emp3',
        jobTitle: 'Data Analyst',
        description:
            'Analyze data and provide insights to help drive business decisions.',
        location: 'Chicago, IL',
        salary: '\$45,000 - \$65,000',
        requirements: [
          'SQL and Python proficiency',
          'Experience with Power BI or Tableau',
          'Statistical analysis knowledge',
        ],
        postedDate: DateTime.now().subtract(const Duration(days: 7)),
        deadline: DateTime.now().add(const Duration(days: 23)),
        jobType: 'Part-time',
        applicantCount: 3,
      ),
    ];

    for (var job in sampleJobs) {
      _jobs.putIfAbsent(job.id, () => job);
    }
  }

  Future<void> _loadPersistedState() async {
    final preferences = await _preferences;
    final encoded = preferences.getString('jobs.records');
    if (encoded != null) {
      try {
        final records = jsonDecode(encoded) as List<dynamic>;
        for (final record in records) {
          final job = Job.fromJson(record as Map<String, dynamic>);
          _jobs[job.id] = job;
        }
      } catch (_) {
        await preferences.remove('jobs.records');
      }
    }
    _initializeSampleData();
  }

  // Get all jobs
  Future<List<Job>> getAllJobs() async {
    await initialize();
    final now = DateTime.now();
    return _jobs.values
        .where((job) => job.isActive && job.deadline.isAfter(now))
        .toList();
  }

  // Search jobs
  Future<List<Job>> searchJobs({
    required String query,
    String? location,
  }) async {
    await initialize();
    final now = DateTime.now();
    final normalizedQuery = query.trim().toLowerCase();
    final normalizedLocation = location?.trim().toLowerCase() ?? '';
    return _jobs.values
        .where(
          (job) =>
              job.isActive &&
              job.deadline.isAfter(now) &&
              (normalizedQuery.isEmpty ||
                  job.jobTitle.toLowerCase().contains(normalizedQuery) ||
                  job.description.toLowerCase().contains(normalizedQuery) ||
                  job.location.toLowerCase().contains(normalizedQuery)) &&
              (normalizedLocation.isEmpty ||
                  job.location.toLowerCase().contains(normalizedLocation)),
        )
        .toList();
  }

  // Get jobs by employer
  Future<List<Job>> getJobsByEmployer(String employerId) async {
    await initialize();
    _requireEmployer(employerId);
    return _jobs.values.where((job) => job.employerId == employerId).toList();
  }

  // Get job by ID
  Future<Job?> getJobById(String jobId) async {
    await initialize();
    return _jobs[jobId];
  }

  Future<Job> recordApplication(String jobId) async {
    await initialize();
    final job = _jobs[jobId];
    final user = AuthService().currentUser;
    if (job == null) throw Exception('Job not found');
    if (user?.userType != UserType.jobSeeker) {
      throw Exception('Only job seekers can submit applications');
    }
    final updatedJob = job.copyWith(applicantCount: job.applicantCount + 1);
    _jobs[jobId] = updatedJob;
    await _persistJobs();
    return updatedJob;
  }

  // Create new job
  Future<Job> createJob({
    required String employerId,
    required String jobTitle,
    required String description,
    required String location,
    required String salary,
    required List<String> requirements,
    required DateTime deadline,
    required String jobType,
  }) async {
    await initialize();
    _requireEmployer(employerId);
    if (jobTitle.trim().isEmpty ||
        description.trim().isEmpty ||
        location.trim().isEmpty) {
      throw Exception('Title, description, and location are required');
    }
    if (deadline.isBefore(DateTime.now())) {
      throw Exception('Deadline must be in the future');
    }

    final job = Job(
      id: const Uuid().v4(),
      employerId: employerId,
      jobTitle: jobTitle,
      description: description,
      location: location,
      salary: salary,
      requirements: requirements,
      postedDate: DateTime.now(),
      deadline: deadline,
      jobType: jobType,
    );

    _jobs[job.id] = job;
    await _persistJobs();
    return job;
  }

  // Update job
  Future<Job> updateJob({
    required String jobId,
    String? jobTitle,
    String? description,
    String? location,
    String? salary,
    List<String>? requirements,
    DateTime? deadline,
    String? jobType,
  }) async {
    await initialize();
    final job = _jobs[jobId];
    if (job == null) {
      throw Exception('Job not found');
    }
    _requireJobManager(job.employerId);
    if (jobTitle != null && jobTitle.trim().isEmpty ||
        description != null && description.trim().isEmpty ||
        location != null && location.trim().isEmpty) {
      throw Exception('Title, description, and location cannot be empty');
    }
    if (deadline != null && deadline.isBefore(DateTime.now())) {
      throw Exception('Deadline must be in the future');
    }

    final updatedJob = job.copyWith(
      jobTitle: jobTitle,
      description: description,
      location: location,
      salary: salary,
      requirements: requirements,
      deadline: deadline,
      jobType: jobType,
    );

    _jobs[jobId] = updatedJob;
    await _persistJobs();
    return updatedJob;
  }

  // Delete job
  Future<bool> deleteJob(String jobId) async {
    await initialize();
    final job = _jobs[jobId];
    if (job == null) {
      throw Exception('Job not found');
    }
    final user = AuthService().currentUser;
    if (user?.userType != UserType.administrator) {
      _requireEmployer(job.employerId);
    }

    _jobs[jobId] = job.copyWith(isActive: false);
    await _persistJobs();
    return true;
  }

  Future<List<String>> removeJobsForEmployer(String employerId) async {
    await initialize();
    if (AuthService().currentUser?.userType != UserType.administrator) {
      throw Exception('Administrator access required');
    }
    final jobIds = _jobs.values
        .where((job) => job.employerId == employerId)
        .map((job) => job.id)
        .toList();
    _jobs.removeWhere((jobId, job) => job.employerId == employerId);
    if (jobIds.isNotEmpty) await _persistJobs();
    return jobIds;
  }

  Future<void> removeApplicantCounts(Set<String> jobIds) async {
    await initialize();
    if (AuthService().currentUser?.userType != UserType.administrator) {
      throw Exception('Administrator access required');
    }
    for (final jobId in jobIds) {
      final job = _jobs[jobId];
      if (job != null && job.applicantCount > 0) {
        _jobs[jobId] = job.copyWith(applicantCount: job.applicantCount - 1);
      }
    }
    if (jobIds.isNotEmpty) await _persistJobs();
  }

  Future<void> _persistJobs() => _enqueueWrite(
    () async => (await _preferences).setString(
      'jobs.records',
      jsonEncode(_jobs.values.map((job) => job.toJson()).toList()),
    ),
  );

  Future<void> _enqueueWrite(Future<void> Function() action) {
    _writeQueue = _writeQueue.then((_) => action());
    return _writeQueue;
  }

  void _requireEmployer(String employerId) {
    final user = AuthService().currentUser;
    if (user == null ||
        user.userType != UserType.employer ||
        user.id != employerId) {
      throw Exception('Only the owning employer can manage this job');
    }
  }

  void _requireJobManager(String employerId) {
    final user = AuthService().currentUser;
    if (user?.userType == UserType.administrator) return;
    _requireEmployer(employerId);
  }
}
