enum ArchitectureLayer { presentation, application, data }

class ArchitectureComponent {
  final String name;
  final ArchitectureLayer layer;
  final List<String> responsibilities;

  const ArchitectureComponent({
    required this.name,
    required this.layer,
    required this.responsibilities,
  });
}

class PartTimeNowArchitecture {
  static const presentation = ArchitectureComponent(
    name: 'Flutter Presentation Layer',
    layer: ArchitectureLayer.presentation,
    responsibilities: [
      'Login and registration screens',
      'Job search and job details',
      'Applications and status tracking',
      'Employer and administrator dashboards',
    ],
  );

  static const application = ArchitectureComponent(
    name: 'Dart Application Layer',
    layer: ArchitectureLayer.application,
    responsibilities: [
      'Authentication and role access',
      'Job and applicant management',
      'Application status workflow',
      'Validation and ownership rules',
    ],
  );

  static const data = ArchitectureComponent(
    name: 'Local Data Layer',
    layer: ArchitectureLayer.data,
    responsibilities: [
      'SharedPreferences persistence',
      'JSON model serialization',
      'User, Job, Application, and SavedJob records',
      'Future API and SQLite integration boundary',
    ],
  );

  static const components = [presentation, application, data];
}
