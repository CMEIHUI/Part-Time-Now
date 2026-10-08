enum ApplicationStatus { pending, reviewing, accepted, rejected }

class JobApplication {
  final String id;
  final String jobSeekerId;
  final String jobId;
  final String coverLetter;
  final ApplicationStatus status;
  final DateTime appliedDate;
  final DateTime? reviewedDate;
  final String? reviewerNotes;

  JobApplication({
    required this.id,
    required this.jobSeekerId,
    required this.jobId,
    required this.coverLetter,
    required this.status,
    required this.appliedDate,
    this.reviewedDate,
    this.reviewerNotes,
  });

  String get userId => jobSeekerId;
  DateTime get appliedAt => appliedDate;

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    return JobApplication(
      id: json['id'],
      jobSeekerId: json['jobSeekerId'],
      jobId: json['jobId'],
      coverLetter: json['coverLetter'],
      status: ApplicationStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
      ),
      appliedDate: DateTime.parse(json['appliedDate']),
      reviewedDate: json['reviewedDate'] != null
          ? DateTime.parse(json['reviewedDate'])
          : null,
      reviewerNotes: json['reviewerNotes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'jobSeekerId': jobSeekerId,
      'jobId': jobId,
      'coverLetter': coverLetter,
      'status': status.toString().split('.').last,
      'appliedDate': appliedDate.toIso8601String(),
      'reviewedDate': reviewedDate?.toIso8601String(),
      'reviewerNotes': reviewerNotes,
    };
  }

  JobApplication copyWith({
    String? id,
    String? jobSeekerId,
    String? jobId,
    String? coverLetter,
    ApplicationStatus? status,
    DateTime? appliedDate,
    DateTime? reviewedDate,
    String? reviewerNotes,
  }) {
    return JobApplication(
      id: id ?? this.id,
      jobSeekerId: jobSeekerId ?? this.jobSeekerId,
      jobId: jobId ?? this.jobId,
      coverLetter: coverLetter ?? this.coverLetter,
      status: status ?? this.status,
      appliedDate: appliedDate ?? this.appliedDate,
      reviewedDate: reviewedDate ?? this.reviewedDate,
      reviewerNotes: reviewerNotes ?? this.reviewerNotes,
    );
  }
}

/// UML-compatible name retained alongside the existing application API.
typedef Application = JobApplication;
