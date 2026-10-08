class FavoriteJob {
  final String id;
  final String jobSeekerId;
  final String jobId;
  final DateTime savedDate;

  FavoriteJob({
    required this.id,
    required this.jobSeekerId,
    required this.jobId,
    required this.savedDate,
  });

  String get userId => jobSeekerId;
  DateTime get savedAt => savedDate;

  factory FavoriteJob.fromJson(Map<String, dynamic> json) {
    return FavoriteJob(
      id: json['id'],
      jobSeekerId: json['jobSeekerId'],
      jobId: json['jobId'],
      savedDate: DateTime.parse(json['savedDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'jobSeekerId': jobSeekerId,
      'jobId': jobId,
      'savedDate': savedDate.toIso8601String(),
    };
  }
}

/// UML-compatible name retained alongside the existing application API.
typedef SavedJob = FavoriteJob;
