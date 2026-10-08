import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_application_1/models/application_model.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/job_service.dart';

class ApplicationService {
  static final ApplicationService _instance = ApplicationService._internal();

  factory ApplicationService() {
    return _instance;
  }

  ApplicationService._internal();

  final Map<String, JobApplication> _applications = {};
  late final Future<SharedPreferences> _preferences =
      SharedPreferences.getInstance();
  late final Future<void> _initialization = _loadPersistedState();
  Future<void> _writeQueue = Future<void>.value();

  Future<void> initialize() => _initialization;

  // Apply for job
  Future<JobApplication> applyForJob({
    required String jobSeekerId,
    required String jobId,
    required String coverLetter,
  }) async {
    await initialize();
    final user = AuthService().currentUser;
    if (user == null ||
        user.userType != UserType.jobSeeker ||
        user.id != jobSeekerId) {
      throw Exception('Only the signed-in job seeker can apply');
    }
    final job = await JobService().getJobById(jobId);
    if (job == null || !job.isActive || job.deadline.isBefore(DateTime.now())) {
      throw Exception('This job is no longer accepting applications');
    }
    if (coverLetter.trim().isEmpty) {
      throw Exception('A cover letter is required');
    }

    // Check if already applied
    if (_applications.values.any(
      (app) => app.jobSeekerId == jobSeekerId && app.jobId == jobId,
    )) {
      throw Exception('You have already applied for this job');
    }

    final application = JobApplication(
      id: const Uuid().v4(),
      jobSeekerId: jobSeekerId,
      jobId: jobId,
      coverLetter: coverLetter,
      status: ApplicationStatus.pending,
      appliedDate: DateTime.now(),
    );

    _applications[application.id] = application;
    await JobService().recordApplication(job.id);
    await _persistApplications();
    return application;
  }

  // Get applications by job seeker
  Future<List<JobApplication>> getApplicationsByJobSeeker(
    String jobSeekerId,
  ) async {
    await initialize();
    final user = AuthService().currentUser;
    if (user == null ||
        user.userType != UserType.jobSeeker ||
        user.id != jobSeekerId) {
      throw Exception(
        'Only the signed-in job seeker can view these applications',
      );
    }
    return _applications.values
        .where((app) => app.jobSeekerId == jobSeekerId)
        .toList();
  }

  // Get applications by job
  Future<List<JobApplication>> getApplicationsByJob(String jobId) async {
    await initialize();
    final user = AuthService().currentUser;
    final job = await JobService().getJobById(jobId);
    if (user == null ||
        user.userType != UserType.employer ||
        job?.employerId != user.id) {
      throw Exception('Only the owning employer can view these applications');
    }
    return _applications.values.where((app) => app.jobId == jobId).toList();
  }

  // Get applications by employer for all their jobs
  Future<List<JobApplication>> getApplicationsByEmployer(
    List<String> jobIds,
  ) async {
    await initialize();
    final user = AuthService().currentUser;
    if (user == null || user.userType != UserType.employer) {
      throw Exception('Only employers can view applicants');
    }
    final ownedJobs = await Future.wait(
      jobIds.map((jobId) => JobService().getJobById(jobId)),
    );
    if (ownedJobs.any((job) => job == null || job.employerId != user.id)) {
      throw Exception('Applicants can only be viewed for your own jobs');
    }
    return _applications.values
        .where((app) => jobIds.contains(app.jobId))
        .toList();
  }

  Future<int> getTotalApplications() async {
    await initialize();
    if (AuthService().currentUser?.userType != UserType.administrator) {
      throw Exception('Administrator access required');
    }
    return _applications.length;
  }

  Future<Set<String>> removeForUser(String userId, Set<String> jobIds) async {
    await initialize();
    if (AuthService().currentUser?.userType != UserType.administrator) {
      throw Exception('Administrator access required');
    }
    final affectedJobIds = _applications.values
        .where(
          (application) =>
              application.jobSeekerId == userId ||
              jobIds.contains(application.jobId),
        )
        .map((application) => application.jobId)
        .toSet();
    _applications.removeWhere(
      (_, application) =>
          application.jobSeekerId == userId ||
          jobIds.contains(application.jobId),
    );
    await _persistApplications();
    return affectedJobIds;
  }

  // Update application status
  Future<JobApplication> updateApplicationStatus({
    required String applicationId,
    required ApplicationStatus status,
    String? reviewerNotes,
  }) async {
    await initialize();
    final application = _applications[applicationId];
    if (application == null) {
      throw Exception('Application not found');
    }
    final user = AuthService().currentUser;
    final job = await JobService().getJobById(application.jobId);
    if (user == null ||
        user.userType != UserType.employer ||
        job?.employerId != user.id) {
      throw Exception('Only the owning employer can update this application');
    }
    if (!_allowedTransitions(application.status).contains(status)) {
      throw Exception(
        'Application status cannot move from ${application.status.name} to ${status.name}',
      );
    }

    final updatedApplication = application.copyWith(
      status: status,
      reviewedDate: DateTime.now(),
      reviewerNotes: reviewerNotes,
    );

    _applications[applicationId] = updatedApplication;
    await _persistApplications();
    return updatedApplication;
  }

  List<ApplicationStatus> _allowedTransitions(ApplicationStatus current) {
    switch (current) {
      case ApplicationStatus.pending:
        return [ApplicationStatus.pending, ApplicationStatus.reviewing];
      case ApplicationStatus.reviewing:
        return [
          ApplicationStatus.reviewing,
          ApplicationStatus.accepted,
          ApplicationStatus.rejected,
        ];
      case ApplicationStatus.accepted:
      case ApplicationStatus.rejected:
        return [current];
    }
  }

  // Get application by ID
  Future<JobApplication?> getApplicationById(String applicationId) async {
    await initialize();
    final application = _applications[applicationId];
    if (application == null) return null;

    final user = AuthService().currentUser;
    final job = await JobService().getJobById(application.jobId);
    final canView =
        user?.userType == UserType.jobSeeker &&
            user?.id == application.jobSeekerId ||
        user?.userType == UserType.employer && user?.id == job?.employerId;
    if (!canView) {
      throw Exception('You are not authorized to view this application');
    }
    return application;
  }

  Future<void> _loadPersistedState() async {
    final preferences = await _preferences;
    final encoded = preferences.getString('applications.records');
    if (encoded == null) return;
    try {
      final records = jsonDecode(encoded) as List<dynamic>;
      for (final record in records) {
        final application = JobApplication.fromJson(
          record as Map<String, dynamic>,
        );
        _applications[application.id] = application;
      }
    } catch (_) {
      await preferences.remove('applications.records');
    }
  }

  Future<void> _persistApplications() => _enqueueWrite(
    () async => (await _preferences).setString(
      'applications.records',
      jsonEncode(_applications.values.map((item) => item.toJson()).toList()),
    ),
  );

  Future<void> _enqueueWrite(Future<void> Function() action) {
    _writeQueue = _writeQueue.then((_) => action());
    return _writeQueue;
  }
}
