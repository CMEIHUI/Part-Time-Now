class Job {
  final String id;
  final String employerId;
  final String jobTitle;
  final String description;
  final String location;
  final String salary;
  final List<String> requirements;
  final DateTime postedDate;
  final DateTime deadline;
  final String jobType; // Full-time, Part-time, etc.
  final int applicantCount;
  final bool isActive;

  Job({
    required this.id,
    required this.employerId,
    required this.jobTitle,
    required this.description,
    required this.location,
    required this.salary,
    required this.requirements,
    required this.postedDate,
    required this.deadline,
    required this.jobType,
    this.applicantCount = 0,
    this.isActive = true,
  });

  String get title => jobTitle;
  DateTime get createdAt => postedDate;

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'],
      employerId: json['employerId'],
      jobTitle: json['jobTitle'],
      description: json['description'],
      location: json['location'],
      salary: json['salary'],
      requirements: List<String>.from(json['requirements']),
      postedDate: DateTime.parse(json['postedDate']),
      deadline: DateTime.parse(json['deadline']),
      jobType: json['jobType'],
      applicantCount: json['applicantCount'] ?? 0,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employerId': employerId,
      'jobTitle': jobTitle,
      'description': description,
      'location': location,
      'salary': salary,
      'requirements': requirements,
      'postedDate': postedDate.toIso8601String(),
      'deadline': deadline.toIso8601String(),
      'jobType': jobType,
      'applicantCount': applicantCount,
      'isActive': isActive,
    };
  }

  Job copyWith({
    String? id,
    String? employerId,
    String? jobTitle,
    String? description,
    String? location,
    String? salary,
    List<String>? requirements,
    DateTime? postedDate,
    DateTime? deadline,
    String? jobType,
    int? applicantCount,
    bool? isActive,
  }) {
    return Job(
      id: id ?? this.id,
      employerId: employerId ?? this.employerId,
      jobTitle: jobTitle ?? this.jobTitle,
      description: description ?? this.description,
      location: location ?? this.location,
      salary: salary ?? this.salary,
      requirements: requirements ?? this.requirements,
      postedDate: postedDate ?? this.postedDate,
      deadline: deadline ?? this.deadline,
      jobType: jobType ?? this.jobType,
      applicantCount: applicantCount ?? this.applicantCount,
      isActive: isActive ?? this.isActive,
    );
  }
}
