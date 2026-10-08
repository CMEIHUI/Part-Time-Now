import 'package:flutter/material.dart';
import 'package:flutter_application_1/constants/theme.dart';
import 'package:flutter_application_1/models/application_model.dart';
import 'package:flutter_application_1/models/favorite_job_model.dart';
import 'package:flutter_application_1/models/job_model.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/screens/auth/auth_screens.dart';
import 'package:flutter_application_1/services/application_service.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/favorite_service.dart';
import 'package:flutter_application_1/services/job_service.dart';
import 'package:flutter_application_1/widgets/common_widgets.dart';

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime _parseDeadline(String value) {
  final parsed = DateTime.tryParse(value.trim());
  if (parsed == null) {
    throw Exception('Enter a valid deadline as YYYY-MM-DD');
  }
  return parsed;
}

List<String> _parseRequirements(String value) => value
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    AuthService().initialize(),
    ApplicationService().initialize(),
    FavoriteService().initialize(),
    JobService().initialize(),
  ]);
  runApp(const PartTimeNowApp());
}

class PartTimeNowApp extends StatefulWidget {
  const PartTimeNowApp({super.key});

  @override
  State<PartTimeNowApp> createState() => _PartTimeNowAppState();
}

class _PartTimeNowAppState extends State<PartTimeNowApp> {
  UserType? _userType;

  void _signedIn(UserType type) => setState(() => _userType = type);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PartTimeNow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
        scaffoldBackgroundColor: background,
        useMaterial3: true,
      ),
      home: _userType == null
          ? LoginScreen(onLoginSuccess: _signedIn)
          : Dashboard(
              userType: _userType!,
              onLogout: () {
                AuthService().logout();
                setState(() => _userType = null);
              },
            ),
    );
  }
}

class Dashboard extends StatefulWidget {
  final UserType userType;
  final VoidCallback onLogout;

  const Dashboard({super.key, required this.userType, required this.onLogout});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isEmployer = widget.userType == UserType.employer;
    final isAdministrator = widget.userType == UserType.administrator;
    if (isAdministrator) {
      return AdminDashboard(onLogout: widget.onLogout);
    }
    final pages = isEmployer
        ? [EmployerJobs(onLogout: widget.onLogout), const EmployerApplicants()]
        : [
            JobSearch(onLogout: widget.onLogout),
            const ApplicationsPage(),
            const FavoritesPage(),
          ];
    final labels = isEmployer
        ? ['My jobs', 'Applicants']
        : ['Find jobs', 'Applications', 'Saved'];
    final icons = isEmployer
        ? [Icons.work_outline, Icons.people_outline]
        : [Icons.search, Icons.description_outlined, Icons.bookmark_outline];

    return Scaffold(
      appBar: AppBar(
        title: Text(isEmployer ? 'Employer workspace' : 'Find your next shift'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: [
          for (var i = 0; i < labels.length; i++)
            NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ],
      ),
    );
  }
}

class JobSearch extends StatefulWidget {
  final VoidCallback onLogout;
  const JobSearch({super.key, required this.onLogout});

  @override
  State<JobSearch> createState() => _JobSearchState();
}

class AdminDashboard extends StatefulWidget {
  final VoidCallback onLogout;

  const AdminDashboard({super.key, required this.onLogout});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _auth = AuthService();
  final _jobs = JobService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration area'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(spacingM),
        children: [
          const Text('System monitor', style: headingMedium),
          const SizedBox(height: spacingS),
          Text(
            'Review platform data and keep listings healthy.',
            style: bodyMedium.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: spacingL),
          FutureBuilder<List<Job>>(
            future: _jobs.getAllJobs(),
            builder: (context, jobSnapshot) {
              final jobs = jobSnapshot.data ?? [];
              return FutureBuilder<List<User>>(
                future: Future.value(_auth.users),
                builder: (context, userSnapshot) {
                  final users = userSnapshot.data ?? [];
                  final seekers = users
                      .where((user) => user.userType == UserType.jobSeeker)
                      .length;
                  final employers = users
                      .where((user) => user.userType == UserType.employer)
                      .length;
                  return Row(
                    children: [
                      Expanded(
                        child: _AdminMetric(
                          label: 'Users',
                          value: '${users.length}',
                          icon: Icons.people_outline,
                        ),
                      ),
                      const SizedBox(width: spacingS),
                      Expanded(
                        child: _AdminMetric(
                          label: 'Seekers',
                          value: '$seekers',
                          icon: Icons.person_search_outlined,
                        ),
                      ),
                      const SizedBox(width: spacingS),
                      Expanded(
                        child: _AdminMetric(
                          label: 'Employers',
                          value: '$employers',
                          icon: Icons.storefront_outlined,
                        ),
                      ),
                      const SizedBox(width: spacingS),
                      Expanded(
                        child: _AdminMetric(
                          label: 'Live jobs',
                          value: '${jobs.length}',
                          icon: Icons.work_outline,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: spacingL),
          FutureBuilder<int>(
            future: ApplicationService().getTotalApplications(),
            builder: (context, snapshot) => Card(
              child: ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: const Text('System data'),
                subtitle: Text(
                  snapshot.hasError
                      ? 'Application data unavailable'
                      : '${snapshot.data ?? 0} total applications recorded',
                ),
              ),
            ),
          ),
          const SizedBox(height: spacingL),
          const Text('User accounts', style: headingSmall),
          FutureBuilder<List<User>>(
            future: Future.value(_auth.users),
            builder: (context, snapshot) {
              final users = snapshot.data ?? [];
              return Column(
                children: users
                    .map(
                      (user) => Card(
                        child: ListTile(
                          leading: Icon(
                            user.userType == UserType.employer
                                ? Icons.storefront_outlined
                                : Icons.person_outline,
                          ),
                          title: Text(user.name),
                          subtitle: Text(
                            '${user.email}  |  ${user.userType.name}',
                          ),
                          trailing: user.userType == UserType.administrator
                              ? null
                              : IconButton(
                                  tooltip: 'Remove user',
                                  icon: const Icon(
                                    Icons.person_remove_outlined,
                                  ),
                                  onPressed: () => _removeUser(user),
                                ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: spacingL),
          const Text('Active job listings', style: headingSmall),
          FutureBuilder<List<Job>>(
            future: _jobs.getAllJobs(),
            builder: (context, snapshot) {
              final jobs = snapshot.data ?? [];
              return Column(
                children: jobs
                    .map(
                      (job) => Card(
                        child: ListTile(
                          title: Text(job.jobTitle),
                          subtitle: Text('${job.location}  |  ${job.jobType}'),
                          trailing: IconButton(
                            tooltip: 'Remove listing',
                            icon: const Icon(Icons.visibility_off_outlined),
                            onPressed: () => _removeJob(job),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _removeUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove user account?'),
        content: Text('Remove ${user.name} from the system?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _auth.removeUser(user.id);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _removeJob(Job job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive job listing?'),
        content: Text('Archive ${job.jobTitle} from active listings?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _jobs.deleteJob(job.id);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _AdminMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _AdminMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(spacingS),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusM),
      ),
      child: Column(
        children: [
          Icon(icon, color: primaryColor),
          const SizedBox(height: spacingXS),
          Text(value, style: headingSmall),
          Text(label, style: labelLarge, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _JobSearchState extends State<JobSearch> {
  final _jobs = JobService();
  final _favorites = FavoriteService();
  final _searchController = TextEditingController();
  final _locationController = TextEditingController();
  List<Job> _results = [];
  final Set<String> _saved = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    final jobs = await _jobs.getAllJobs();
    final user = AuthService().currentUser;
    final saved = user == null
        ? <FavoriteJob>[]
        : await _favorites.getFavoritesByJobSeeker(user.id);
    if (mounted) {
      setState(() {
        _results = jobs;
        _saved.addAll(saved.map((favorite) => favorite.jobId));
        _loading = false;
      });
    }
  }

  Future<void> _search(String value) async {
    setState(() => _loading = true);
    final query = value.trim();
    final location = _locationController.text.trim();
    final jobs = query.isEmpty && location.isEmpty
        ? await _jobs.getAllJobs()
        : await _jobs.searchJobs(query: query, location: location);
    if (mounted) {
      setState(() {
        _results = jobs;
        _loading = false;
      });
    }
  }

  Future<void> _toggleSaved(Job job) async {
    final user = AuthService().currentUser;
    if (user == null) return;
    try {
      if (_saved.contains(job.id)) {
        await _favorites.removeFromFavorites(
          jobSeekerId: user.id,
          jobId: job.id,
        );
        setState(() => _saved.remove(job.id));
      } else {
        await _favorites.addToFavorites(jobSeekerId: user.id, jobId: job.id);
        setState(() => _saved.add(job.id));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadJobs,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          spacingM,
          spacingM,
          spacingM,
          spacingXL,
        ),
        children: [
          Text(
            'Good morning, ${AuthService().currentUser?.name ?? 'there'}',
            style: headingMedium,
          ),
          const SizedBox(height: spacingS),
          Text(
            'Opportunities that fit your schedule.',
            style: bodyMedium.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: spacingM),
          const _BenefitBanner(
            icon: Icons.near_me_outlined,
            title: 'Find work closer to home',
            message:
                'Search by city or neighbourhood to spend less time commuting.',
          ),
          const SizedBox(height: spacingL),
          TextField(
            controller: _searchController,
            onChanged: _search,
            decoration: InputDecoration(
              hintText: 'Search title, skill, or city',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radiusL),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: spacingS),
          TextField(
            controller: _locationController,
            onChanged: (_) => _search(_searchController.text),
            decoration: InputDecoration(
              hintText: 'Filter by location',
              prefixIcon: const Icon(Icons.location_on_outlined),
              filled: true,
              fillColor: surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radiusL),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: spacingL),
          Text('${_results.length} opportunities', style: headingSmall),
          const SizedBox(height: spacingS),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(spacingXL),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_results.isEmpty)
            const Padding(
              padding: EdgeInsets.all(spacingXL),
              child: Center(child: Text('No jobs match your search.')),
            )
          else
            for (final job in _results)
              JobCard(
                jobTitle: job.jobTitle,
                companyName: 'Hiring partner',
                location: job.location,
                salary: job.salary,
                jobType: job.jobType,
                isFavorited: _saved.contains(job.id),
                onFavoriteTap: () => _toggleSaved(job),
                onTap: () => _showJob(context, job),
              ),
        ],
      ),
    );
  }

  void _showJob(BuildContext context, Job job) {
    final cover = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          spacingL,
          spacingL,
          spacingL,
          MediaQuery.of(sheetContext).viewInsets.bottom + spacingL,
        ),
        child: Wrap(
          children: [
            Text(job.jobTitle, style: headingMedium),
            const SizedBox(height: spacingS),
            Text('${job.location}  |  ${job.salary}  |  ${job.jobType}'),
            const SizedBox(height: spacingS),
            Text('Apply by ${_formatDate(job.deadline)}'),
            const SizedBox(height: spacingM),
            Text(job.description),
            const SizedBox(height: spacingM),
            const Text('Requirements', style: headingSmall),
            ...job.requirements.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(item),
              ),
            ),
            CustomTextField(
              label: 'Cover letter',
              hint: 'Tell the employer why you are a good fit',
              controller: cover,
              maxLines: 4,
            ),
            const SizedBox(height: spacingM),
            PrimaryButton(
              label: 'Apply now',
              onPressed: () async {
                final user = AuthService().currentUser;
                if (user == null) return;
                if (cover.text.trim().isEmpty) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text('Write a cover letter before submitting.'),
                    ),
                  );
                  return;
                }
                try {
                  await ApplicationService().applyForJob(
                    jobSeekerId: user.id,
                    jobId: job.id,
                    coverLetter: cover.text.trim(),
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Application submitted')),
                    );
                  }
                } catch (error) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(
                      sheetContext,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                }
              },
            ),
          ],
        ),
      ),
    ).whenComplete(cover.dispose);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}

class ApplicationsPage extends StatelessWidget {
  const ApplicationsPage({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<JobApplication>>(
    future: ApplicationService().getApplicationsByJobSeeker(
      AuthService().currentUser?.id ?? '',
    ),
    builder: (context, snapshot) {
      final applications = snapshot.data ?? [];
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (applications.isEmpty) {
        return const Center(child: Text('Your applications will appear here.'));
      }
      return ListView.builder(
        itemCount: applications.length,
        itemBuilder: (context, index) {
          final application = applications[index];
          return FutureBuilder<Job?>(
            future: JobService().getJobById(application.jobId),
            builder: (context, jobSnapshot) {
              final job = jobSnapshot.data;
              return Card(
                margin: const EdgeInsets.all(spacingM),
                child: ListTile(
                  title: Text(job?.jobTitle ?? 'Job application'),
                  subtitle: Text(
                    '${job?.location ?? 'Unknown location'}\nApplied ${application.appliedDate.toLocal().toString().split(' ').first}',
                  ),
                  isThreeLine: true,
                  trailing: ApplicationStatusBadge(
                    status: application.status.name,
                  ),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) => Padding(
                      padding: const EdgeInsets.all(spacingL),
                      child: Wrap(
                        children: [
                          Text(
                            job?.jobTitle ?? 'Application progress',
                            style: headingSmall,
                          ),
                          const SizedBox(height: spacingM),
                          _ApplicationTimeline(status: application.status),
                          if (application.reviewerNotes?.isNotEmpty ??
                              false) ...[
                            const SizedBox(height: spacingM),
                            const Text('Employer note', style: headingSmall),
                            const SizedBox(height: spacingS),
                            Text(application.reviewerNotes!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  void _showSavedJob(BuildContext context, Job job) {
    final cover = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          spacingL,
          spacingL,
          spacingL,
          MediaQuery.of(sheetContext).viewInsets.bottom + spacingL,
        ),
        child: Wrap(
          children: [
            Text(job.jobTitle, style: headingMedium),
            const SizedBox(height: spacingS),
            Text('${job.location}  |  ${job.salary}  |  ${job.jobType}'),
            const SizedBox(height: spacingS),
            Text('Apply by ${_formatDate(job.deadline)}'),
            const SizedBox(height: spacingM),
            Text(job.description),
            const SizedBox(height: spacingM),
            const Text('Requirements', style: headingSmall),
            ...job.requirements.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(item),
              ),
            ),
            CustomTextField(
              label: 'Cover letter',
              hint: 'Tell the employer why you are a good fit',
              controller: cover,
              maxLines: 4,
            ),
            const SizedBox(height: spacingM),
            PrimaryButton(
              label: 'Apply now',
              onPressed: () async {
                if (cover.text.trim().isEmpty) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text('Write a cover letter before submitting.'),
                    ),
                  );
                  return;
                }
                final user = AuthService().currentUser;
                if (user == null) return;
                try {
                  await ApplicationService().applyForJob(
                    jobSeekerId: user.id,
                    jobId: job.id,
                    coverLetter: cover.text.trim(),
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Application submitted')),
                    );
                  }
                } catch (error) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(
                      sheetContext,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                }
              },
            ),
          ],
        ),
      ),
    ).whenComplete(cover.dispose);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: FavoriteService().getFavoritesByJobSeeker(
      AuthService().currentUser?.id ?? '',
    ),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final favorites = snapshot.data ?? [];
      if (favorites.isEmpty) {
        return const Center(child: Text('Save jobs to review them later.'));
      }
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(spacingM),
            child: Text('${favorites.length} saved jobs', style: headingSmall),
          ),
          ...favorites.map(
            (favorite) => FutureBuilder<Job?>(
              future: JobService().getJobById(favorite.jobId),
              builder: (context, jobSnapshot) {
                final job = jobSnapshot.data;
                if (job == null) return const SizedBox.shrink();
                return JobCard(
                  jobTitle: job.jobTitle,
                  companyName: 'Hiring partner',
                  location: job.location,
                  salary: job.salary,
                  jobType: job.jobType,
                  onTap: () => _showSavedJob(context, job),
                  isFavorited: true,
                  onFavoriteTap: () async {
                    await FavoriteService().removeFromFavorites(
                      jobSeekerId: AuthService().currentUser!.id,
                      jobId: job.id,
                    );
                    setState(() {});
                  },
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

class EmployerJobs extends StatefulWidget {
  final VoidCallback onLogout;
  const EmployerJobs({super.key, required this.onLogout});
  @override
  State<EmployerJobs> createState() => _EmployerJobsState();
}

class _EmployerJobsState extends State<EmployerJobs> {
  Future<List<Job>> _load() =>
      JobService().getJobsByEmployer(AuthService().currentUser?.id ?? '');
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Job>>(
    future: _load(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final jobs = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.all(spacingM),
        children: [
          const _BenefitBanner(
            icon: Icons.groups_2_outlined,
            title: 'Keep hiring moving',
            message:
                'Review applicants in one place and fill peak-hour shifts faster.',
          ),
          const SizedBox(height: spacingL),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your postings', style: headingMedium),
              IconButton(
                tooltip: 'Create job',
                onPressed: () => _createJob(context),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: spacingM),
          if (jobs.isEmpty)
            const Text('Create your first part-time opportunity.')
          else
            ...jobs.map(
              (job) => Card(
                child: ListTile(
                  title: Text(job.jobTitle),
                  subtitle: Text(
                    '${job.location}  |  ${job.applicantCount} applicants',
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Edit job',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editJob(context, job),
                      ),
                      IconButton(
                        tooltip: 'Archive job',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await JobService().deleteJob(job.id);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  void _createJob(BuildContext context) {
    final title = TextEditingController(),
        description = TextEditingController(),
        location = TextEditingController(),
        salary = TextEditingController(),
        requirements = TextEditingController(),
        deadline = TextEditingController(
          text: _formatDate(DateTime.now().add(const Duration(days: 30))),
        ),
        jobType = TextEditingController(text: 'Part-time');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New job posting'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              CustomTextField(label: 'Title', controller: title),
              const SizedBox(height: spacingM),
              CustomTextField(
                label: 'Description',
                controller: description,
                maxLines: 3,
              ),
              const SizedBox(height: spacingM),
              CustomTextField(label: 'Location', controller: location),
              const SizedBox(height: spacingM),
              CustomTextField(label: 'Salary', controller: salary),
              const SizedBox(height: spacingM),
              CustomTextField(
                label: 'Requirements',
                hint: 'Separate requirements with commas',
                controller: requirements,
                maxLines: 2,
              ),
              const SizedBox(height: spacingM),
              CustomTextField(label: 'Job type', controller: jobType),
              const SizedBox(height: spacingM),
              CustomTextField(
                label: 'Application deadline (YYYY-MM-DD)',
                controller: deadline,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await JobService().createJob(
                  employerId: AuthService().currentUser?.id ?? '',
                  jobTitle: title.text,
                  description: description.text,
                  location: location.text,
                  salary: salary.text,
                  requirements: _parseRequirements(requirements.text),
                  deadline: _parseDeadline(deadline.text),
                  jobType: jobType.text,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                setState(() {});
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              }
            },
            child: const Text('Publish'),
          ),
        ],
      ),
    ).whenComplete(() {
      title.dispose();
      description.dispose();
      location.dispose();
      salary.dispose();
      requirements.dispose();
      deadline.dispose();
      jobType.dispose();
    });
  }

  void _editJob(BuildContext context, Job job) {
    final title = TextEditingController(text: job.jobTitle);
    final description = TextEditingController(text: job.description);
    final location = TextEditingController(text: job.location);
    final salary = TextEditingController(text: job.salary);
    final requirements = TextEditingController(
      text: job.requirements.join(', '),
    );
    final deadline = TextEditingController(text: _formatDate(job.deadline));
    final jobType = TextEditingController(text: job.jobType);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit job posting'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              CustomTextField(label: 'Title', controller: title),
              const SizedBox(height: spacingM),
              CustomTextField(
                label: 'Description',
                controller: description,
                maxLines: 3,
              ),
              const SizedBox(height: spacingM),
              CustomTextField(label: 'Location', controller: location),
              const SizedBox(height: spacingM),
              CustomTextField(label: 'Salary', controller: salary),
              const SizedBox(height: spacingM),
              CustomTextField(
                label: 'Requirements',
                hint: 'Separate requirements with commas',
                controller: requirements,
                maxLines: 2,
              ),
              const SizedBox(height: spacingM),
              CustomTextField(label: 'Job type', controller: jobType),
              const SizedBox(height: spacingM),
              CustomTextField(
                label: 'Application deadline (YYYY-MM-DD)',
                controller: deadline,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await JobService().updateJob(
                  jobId: job.id,
                  jobTitle: title.text,
                  description: description.text,
                  location: location.text,
                  salary: salary.text,
                  requirements: _parseRequirements(requirements.text),
                  deadline: _parseDeadline(deadline.text),
                  jobType: jobType.text,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                setState(() {});
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(() {
      title.dispose();
      description.dispose();
      location.dispose();
      salary.dispose();
      requirements.dispose();
      deadline.dispose();
      jobType.dispose();
    });
  }
}

class EmployerApplicants extends StatefulWidget {
  const EmployerApplicants({super.key});

  @override
  State<EmployerApplicants> createState() => _EmployerApplicantsState();
}

class _EmployerApplicantsState extends State<EmployerApplicants> {
  Future<List<JobApplication>> _loadApplications() async {
    final jobs = await JobService().getJobsByEmployer(
      AuthService().currentUser?.id ?? '',
    );
    return ApplicationService().getApplicationsByEmployer(
      jobs.map((job) => job.id).toList(),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<JobApplication>>(
    future: _loadApplications(),
    builder: (context, applicationSnapshot) {
      if (applicationSnapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final applications = applicationSnapshot.data ?? [];
      if (applications.isEmpty) {
        return const Center(
          child: Text('Applicants will appear here as they apply.'),
        );
      }
      return RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          children: applications.map((application) {
            final applicant = AuthService().getUserById(
              application.jobSeekerId,
            );
            return Card(
              margin: const EdgeInsets.all(spacingM),
              child: ListTile(
                title: Text(applicant?.name ?? 'Applicant'),
                subtitle: Text(
                  applicant?.email ?? application.coverLetter,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _reviewApplication(context, application),
                trailing: ApplicationStatusBadge(
                  status: application.status.name,
                ),
              ),
            );
          }).toList(),
        ),
      );
    },
  );

  Future<void> _reviewApplication(
    BuildContext context,
    JobApplication application,
  ) async {
    final applicant = AuthService().getUserById(application.jobSeekerId);
    final notes = TextEditingController(text: application.reviewerNotes ?? '');
    var status = application.status;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Review application'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(applicant?.name ?? 'Applicant'),
                if (applicant != null) ...[
                  const SizedBox(height: spacingS),
                  Text(applicant.email),
                  if (applicant.phone?.isNotEmpty ?? false)
                    Text(applicant.phone!),
                ],
                const SizedBox(height: spacingM),
                const Text('Cover letter', style: headingSmall),
                const SizedBox(height: spacingS),
                Text(application.coverLetter),
                const SizedBox(height: spacingM),
                DropdownButtonFormField<ApplicationStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Application status',
                  ),
                  items: _nextStatuses(status)
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? status),
                ),
                const SizedBox(height: spacingM),
                CustomTextField(
                  label: 'Reviewer notes',
                  controller: notes,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await ApplicationService().updateApplicationStatus(
                    applicationId: application.id,
                    status: status,
                    reviewerNotes: notes.text.trim(),
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) setState(() {});
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                }
              },
              child: const Text('Save review'),
            ),
          ],
        ),
      ),
    );
    notes.dispose();
  }

  List<ApplicationStatus> _nextStatuses(ApplicationStatus status) {
    switch (status) {
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
        return [status];
    }
  }
}

class _BenefitBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _BenefitBanner({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(spacingM),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radiusM),
        border: Border.all(color: primaryColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const SizedBox(width: spacingS),
          Icon(icon, color: primaryColor),
          const SizedBox(width: spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: spacingXS),
                Text(message, style: bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationTimeline extends StatelessWidget {
  final ApplicationStatus status;

  const _ApplicationTimeline({required this.status});

  @override
  Widget build(BuildContext context) {
    final current = ApplicationStatus.values.indexOf(status);
    return Column(
      children: [
        for (var index = 0; index < ApplicationStatus.values.length; index++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              index <= current
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: index <= current ? success : Colors.grey,
            ),
            title: Text(ApplicationStatus.values[index].name),
            subtitle: index == current ? const Text('Current stage') : null,
          ),
      ],
    );
  }
}
