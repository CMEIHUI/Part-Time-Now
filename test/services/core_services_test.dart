import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/data/database_schema.dart';
import 'package:flutter_application_1/data/system_architecture.dart';
import 'package:flutter_application_1/models/application_model.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/services/application_service.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/favorite_service.dart';
import 'package:flutter_application_1/services/job_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final auth = AuthService();
  final jobs = JobService();
  final applications = ApplicationService();
  final favorites = FavoriteService();

  setUp(() => auth.logout());

  test(
    'system architecture defines presentation, application, and data layers',
    () {
      expect(PartTimeNowArchitecture.components.length, 3);
      expect(
        PartTimeNowArchitecture.presentation.layer,
        ArchitectureLayer.presentation,
      );
      expect(
        PartTimeNowArchitecture.application.layer,
        ArchitectureLayer.application,
      );
      expect(PartTimeNowArchitecture.data.layer, ArchitectureLayer.data);
      expect(
        PartTimeNowArchitecture.data.responsibilities,
        contains('SharedPreferences persistence'),
      );
    },
  );

  test('database schema defines the documented entities and foreign keys', () {
    expect(
      PartTimeNowSchema.tables.map((table) => table.name),
      containsAll(['User', 'Job', 'Application', 'SavedJob']),
    );
    expect(
      PartTimeNowSchema.job.columns
          .firstWhere((column) => column.name == 'employer_id')
          .references,
      'User.id',
    );
    expect(
      PartTimeNowSchema.application.columns
          .firstWhere((column) => column.name == 'user_id')
          .references,
      'User.id',
    );
    expect(
      PartTimeNowSchema.application.columns
          .firstWhere((column) => column.name == 'job_id')
          .references,
      'Job.id',
    );
    expect(
      PartTimeNowSchema.savedJob.columns
          .where((column) => column.references != null)
          .length,
      2,
    );
    expect(
      PartTimeNowSchema.application.uniqueConstraints,
      contains(equals(['user_id', 'job_id'])),
    );
    expect(
      PartTimeNowSchema.savedJob.uniqueConstraints,
      contains(equals(['user_id', 'job_id'])),
    );
    expect(PartTimeNowSchema.job.columns.first.type, 'UUID');
  });

  String unique(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}@test.local';

  Future<User> registerUser(UserType type) async {
    final email = unique(type.name);
    await auth.register(
      name: type == UserType.employer ? 'Test Employer' : 'Test Seeker',
      email: email,
      password: 'Secure123!',
      userType: type,
    );
    return auth.currentUser!;
  }

  test(
    'registration normalizes credentials and never stores plaintext password',
    () async {
      await auth.register(
        name: '  Test Seeker  ',
        email: '  TEST-${DateTime.now().microsecondsSinceEpoch}@EXAMPLE.COM ',
        password: 'Secure123!',
        userType: UserType.jobSeeker,
      );

      final user = auth.currentUser!;
      expect(user.name, 'Test Seeker');
      expect(user.username, user.name);
      expect(user.role, UserType.jobSeeker.name);
      expect(user.email, startsWith('test-'));
      expect(user.passwordHash, isNot('Secure123!'));
    },
  );

  test('public registration rejects administrator accounts', () async {
    expect(
      () => auth.register(
        name: 'Impostor',
        email: unique('administrator'),
        password: 'Secure123!',
        userType: UserType.administrator,
      ),
      throwsException,
    );
  });

  test('administrator can monitor total applications', () async {
    await auth.login(email: 'admin@parttimenow.local', password: 'Admin123!');
    expect(await applications.getTotalApplications(), greaterThanOrEqualTo(0));

    auth.logout();
    final seeker = await registerUser(UserType.jobSeeker);
    expect(() => applications.getTotalApplications(), throwsException);
    expect(seeker.userType, UserType.jobSeeker);
  });

  test('employer can look up an applicant without admin user access', () async {
    final employer = await registerUser(UserType.employer);
    auth.logout();
    final seeker = await registerUser(UserType.jobSeeker);
    auth.logout();
    await auth.login(email: employer.email, password: 'Secure123!');
    expect(auth.getUserById(seeker.id)?.email, seeker.email);

    auth.logout();
    expect(() => auth.getUserById(seeker.id), throwsException);
  });

  test('removing an employer cleans up related recruitment records', () async {
    final employer = await registerUser(UserType.employer);
    final job = await jobs.createJob(
      employerId: employer.id,
      jobTitle: 'Cleanup Listing ${employer.id}',
      description: 'A listing used to verify account cleanup.',
      location: 'Cleanup City',
      salary: 'RM 20/hour',
      requirements: const [],
      deadline: DateTime.now().add(const Duration(days: 14)),
      jobType: 'Part-time',
    );

    auth.logout();
    final seeker = await registerUser(UserType.jobSeeker);
    await applications.applyForJob(
      jobSeekerId: seeker.id,
      jobId: job.id,
      coverLetter: 'Please consider my application.',
    );

    auth.logout();
    await auth.login(email: 'admin@parttimenow.local', password: 'Admin123!');
    await auth.removeUser(employer.id);

    expect(await jobs.getJobById(job.id), isNull);
    auth.logout();
    await auth.login(email: seeker.email, password: 'Secure123!');
    expect(await applications.getApplicationsByJobSeeker(seeker.id), isEmpty);
  });

  test('removing a seeker cleans up applications and saved jobs', () async {
    final employer = await registerUser(UserType.employer);
    final job = await jobs.createJob(
      employerId: employer.id,
      jobTitle: 'Seeker Cleanup Listing ${employer.id}',
      description: 'A listing used to verify seeker cleanup.',
      location: 'Cleanup City',
      salary: 'RM 20/hour',
      requirements: const [],
      deadline: DateTime.now().add(const Duration(days: 14)),
      jobType: 'Part-time',
    );

    auth.logout();
    final seeker = await registerUser(UserType.jobSeeker);
    await favorites.addToFavorites(jobSeekerId: seeker.id, jobId: job.id);
    await applications.applyForJob(
      jobSeekerId: seeker.id,
      jobId: job.id,
      coverLetter: 'Please consider my application.',
    );

    auth.logout();
    await auth.login(email: 'admin@parttimenow.local', password: 'Admin123!');
    await auth.removeUser(seeker.id);

    expect((await jobs.getJobById(job.id))?.applicantCount, 0);
    auth.logout();
    await auth.login(email: employer.email, password: 'Secure123!');
    expect(await applications.getApplicationsByEmployer([job.id]), isEmpty);
  });

  test(
    'job search and application sequence records a pending application',
    () async {
      final employer = await registerUser(UserType.employer);
      final job = await jobs.createJob(
        employerId: employer.id,
        jobTitle: 'Sequence Test Role ${employer.id}',
        description: 'A role used to verify the search sequence.',
        location: 'Sequence City',
        salary: 'RM 20/hour',
        requirements: const ['Availability'],
        deadline: DateTime.now().add(const Duration(days: 14)),
        jobType: 'Part-time',
      );

      auth.logout();
      final seeker = await registerUser(UserType.jobSeeker);
      expect(
        (await auth.login(email: seeker.email, password: 'Secure123!')),
        isTrue,
      );

      final results = await jobs.searchJobs(query: 'Sequence Test Role');
      expect(results.map((item) => item.id), contains(job.id));
      expect(
        (await jobs.searchJobs(
          query: '',
          location: 'Sequence City',
        )).map((item) => item.id),
        contains(job.id),
      );
      expect((await jobs.getJobById(job.id))?.jobTitle, job.jobTitle);

      final application = await applications.applyForJob(
        jobSeekerId: seeker.id,
        jobId: job.id,
        coverLetter: 'I am available and interested in this opportunity.',
      );
      expect(application.status, ApplicationStatus.pending);
      expect(
        (await applications.getApplicationsByJobSeeker(
          seeker.id,
        )).map((item) => item.id),
        contains(application.id),
      );
    },
  );

  test(
    'job listings preserve requirements and reject past deadlines',
    () async {
      final employer = await registerUser(UserType.employer);
      final deadline = DateTime.now().add(const Duration(days: 21));
      final job = await jobs.createJob(
        employerId: employer.id,
        jobTitle: 'Detailed Listing ${employer.id}',
        description: 'A listing with complete employer-provided details.',
        location: 'Detail City',
        salary: 'RM 25/hour',
        requirements: const ['Communication', 'Weekend availability'],
        deadline: deadline,
        jobType: 'Contract',
      );

      final saved = await jobs.getJobById(job.id);
      expect(saved?.requirements, ['Communication', 'Weekend availability']);
      expect(saved?.jobType, 'Contract');
      expect(saved?.deadline, deadline);

      expect(
        () => jobs.updateJob(
          jobId: job.id,
          deadline: DateTime.now().subtract(const Duration(days: 1)),
        ),
        throwsException,
      );

      expect(
        () => jobs.createJob(
          employerId: employer.id,
          jobTitle: 'Expired Listing',
          description: 'This listing should be rejected.',
          location: 'Detail City',
          salary: 'RM 25/hour',
          requirements: const [],
          deadline: DateTime.now().subtract(const Duration(days: 1)),
          jobType: 'Part-time',
        ),
        throwsException,
      );
    },
  );

  test(
    'application status tracking returns current status to its seeker',
    () async {
      final employer = await registerUser(UserType.employer);
      final job = await jobs.createJob(
        employerId: employer.id,
        jobTitle: 'Status Tracking Role ${employer.id}',
        description: 'A role used to verify status tracking.',
        location: 'Status City',
        salary: 'RM 20/hour',
        requirements: const [],
        deadline: DateTime.now().add(const Duration(days: 14)),
        jobType: 'Part-time',
      );

      auth.logout();
      final seeker = await registerUser(UserType.jobSeeker);
      final application = await applications.applyForJob(
        jobSeekerId: seeker.id,
        jobId: job.id,
        coverLetter: 'Please consider my application.',
      );

      final myApplications = await applications.getApplicationsByJobSeeker(
        seeker.id,
      );
      expect(myApplications.map((item) => item.id), contains(application.id));
      final current = await applications.getApplicationById(application.id);
      expect(current?.status, ApplicationStatus.pending);

      auth.logout();
      final otherSeeker = await registerUser(UserType.jobSeeker);
      expect(
        () => applications.getApplicationById(application.id),
        throwsException,
      );
      expect(otherSeeker.id, isNot(seeker.id));
    },
  );

  test(
    'overall workflow completes through accepted and rejected decisions',
    () async {
      final employer = await registerUser(UserType.employer);
      final job = await jobs.createJob(
        employerId: employer.id,
        jobTitle: 'Overall Workflow Role ${employer.id}',
        description: 'A role used to verify recruitment completion.',
        location: 'Workflow City',
        salary: 'RM 20/hour',
        requirements: const [],
        deadline: DateTime.now().add(const Duration(days: 14)),
        jobType: 'Part-time',
      );

      auth.logout();
      final acceptedSeeker = await registerUser(UserType.jobSeeker);
      final acceptedApplication = await applications.applyForJob(
        jobSeekerId: acceptedSeeker.id,
        jobId: job.id,
        coverLetter: 'I am ready to support this team.',
      );

      auth.logout();
      final rejectedSeeker = await registerUser(UserType.jobSeeker);
      final rejectedApplication = await applications.applyForJob(
        jobSeekerId: rejectedSeeker.id,
        jobId: job.id,
        coverLetter: 'Thank you for considering my application.',
      );

      auth.logout();
      await auth.login(email: employer.email, password: 'Secure123!');
      await applications.updateApplicationStatus(
        applicationId: acceptedApplication.id,
        status: ApplicationStatus.reviewing,
      );
      await applications.updateApplicationStatus(
        applicationId: acceptedApplication.id,
        status: ApplicationStatus.accepted,
        reviewerNotes: 'Welcome to the team.',
      );
      await applications.updateApplicationStatus(
        applicationId: rejectedApplication.id,
        status: ApplicationStatus.reviewing,
      );
      await applications.updateApplicationStatus(
        applicationId: rejectedApplication.id,
        status: ApplicationStatus.rejected,
        reviewerNotes: 'The position has been filled.',
      );

      auth.logout();
      await auth.login(email: acceptedSeeker.email, password: 'Secure123!');
      expect(
        (await applications.getApplicationById(acceptedApplication.id))?.status,
        ApplicationStatus.accepted,
      );
      expect(
        (await applications.getApplicationById(
          acceptedApplication.id,
        ))?.reviewerNotes,
        'Welcome to the team.',
      );

      auth.logout();
      await auth.login(email: rejectedSeeker.email, password: 'Secure123!');
      expect(
        (await applications.getApplicationById(rejectedApplication.id))?.status,
        ApplicationStatus.rejected,
      );
      expect(
        (await applications.getApplicationById(
          rejectedApplication.id,
        ))?.reviewerNotes,
        'The position has been filled.',
      );
    },
  );

  test(
    'job ownership prevents another employer from reading a listing',
    () async {
      final owner = await registerUser(UserType.employer);
      final job = await jobs.createJob(
        employerId: owner.id,
        jobTitle: 'Unique Weekend Role ${owner.id}',
        description: 'A role for service coverage.',
        location: 'Local town',
        salary: 'RM 20/hour',
        requirements: const ['Reliability'],
        deadline: DateTime.now().add(const Duration(days: 14)),
        jobType: 'Part-time',
      );
      expect(
        (await SharedPreferences.getInstance()).getString('jobs.records'),
        contains(job.id),
      );

      auth.logout();
      final otherEmployer = await registerUser(UserType.employer);
      expect(() => jobs.getJobsByEmployer(owner.id), throwsException);
      expect(otherEmployer.id, isNot(owner.id));
      expect(job.isActive, isTrue);
    },
  );

  test('a seeker cannot submit a duplicate application', () async {
    final employer = await registerUser(UserType.employer);
    final job = await jobs.createJob(
      employerId: employer.id,
      jobTitle: 'Application Test Role ${employer.id}',
      description: 'A role for application testing.',
      location: 'Nearby',
      salary: 'RM 18/hour',
      requirements: const [],
      deadline: DateTime.now().add(const Duration(days: 14)),
      jobType: 'Part-time',
    );

    auth.logout();
    final seeker = await registerUser(UserType.jobSeeker);
    final application = await applications.applyForJob(
      jobSeekerId: seeker.id,
      jobId: job.id,
      coverLetter: 'I would be a reliable addition to the team.',
    );
    expect(
      (await SharedPreferences.getInstance()).getString('applications.records'),
      contains(application.id),
    );

    expect(application.status, ApplicationStatus.pending);
    expect((await jobs.getJobById(job.id))?.applicantCount, 1);
    expect(application.userId, seeker.id);
    expect(application.appliedAt, application.appliedDate);
    expect(
      () => applications.applyForJob(
        jobSeekerId: seeker.id,
        jobId: job.id,
        coverLetter: 'A second application should be rejected.',
      ),
      throwsException,
    );

    auth.logout();
    await auth.login(email: employer.email, password: 'Secure123!');
    final reviewed = await applications.updateApplicationStatus(
      applicationId: application.id,
      status: ApplicationStatus.reviewing,
      reviewerNotes: 'Under review.',
    );
    expect(reviewed.status, ApplicationStatus.reviewing);
    expect(reviewed.reviewerNotes, 'Under review.');

    final accepted = await applications.updateApplicationStatus(
      applicationId: application.id,
      status: ApplicationStatus.accepted,
    );
    expect(accepted.status, ApplicationStatus.accepted);
    expect(
      () => applications.updateApplicationStatus(
        applicationId: application.id,
        status: ApplicationStatus.rejected,
      ),
      throwsException,
    );
  });

  test('a seeker can save, inspect, and remove a favourite job', () async {
    final seeker = await registerUser(UserType.jobSeeker);
    final job = (await jobs.getAllJobs()).first;

    await favorites.addToFavorites(jobSeekerId: seeker.id, jobId: job.id);
    expect(
      (await SharedPreferences.getInstance()).getString('favorites.records'),
      contains(job.id),
    );
    expect(
      await favorites.isFavorited(jobSeekerId: seeker.id, jobId: job.id),
      isTrue,
    );
    expect(
      (await favorites.getFavoritesByJobSeeker(
        seeker.id,
      )).map((item) => item.jobId),
      contains(job.id),
    );

    await favorites.removeFromFavorites(jobSeekerId: seeker.id, jobId: job.id);
    expect(
      await favorites.isFavorited(jobSeekerId: seeker.id, jobId: job.id),
      isFalse,
    );
  });

  test('a seeker cannot save a missing job', () async {
    final seeker = await registerUser(UserType.jobSeeker);

    expect(
      () => favorites.addToFavorites(
        jobSeekerId: seeker.id,
        jobId: 'missing-job-id',
      ),
      throwsException,
    );
  });

  test(
    'users, jobs, and applications preserve one-to-many relationships',
    () async {
      final employer = await registerUser(UserType.employer);
      final job = await jobs.createJob(
        employerId: employer.id,
        jobTitle: 'Relationship Test Role ${employer.id}',
        description: 'A role used to verify relationships.',
        location: 'Relationship City',
        salary: 'RM 20/hour',
        requirements: const [],
        deadline: DateTime.now().add(const Duration(days: 14)),
        jobType: 'Part-time',
      );

      auth.logout();
      final firstSeeker = await registerUser(UserType.jobSeeker);
      final firstApplication = await applications.applyForJob(
        jobSeekerId: firstSeeker.id,
        jobId: job.id,
        coverLetter: 'First application.',
      );

      auth.logout();
      final secondSeeker = await registerUser(UserType.jobSeeker);
      final secondApplication = await applications.applyForJob(
        jobSeekerId: secondSeeker.id,
        jobId: job.id,
        coverLetter: 'Second application.',
      );

      auth.logout();
      await auth.login(email: employer.email, password: 'Secure123!');
      expect(
        (await applications.getApplicationsByJob(
          job.id,
        )).map((item) => item.id),
        containsAll([firstApplication.id, secondApplication.id]),
      );
      expect((await jobs.getJobById(job.id))?.applicantCount, 2);
    },
  );
}
