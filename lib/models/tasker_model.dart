import 'package:cloud_firestore/cloud_firestore.dart';

/// Extended profile for users with role == "tasker".
/// Stored in the `taskers` collection, keyed by the same uid as `users`.
/// Always read alongside [UserModel] for the full tasker picture.
class TaskerModel {
  final String uid;

  /// List of skill tags e.g. ["plumbing", "cleaning", "tv_mounting"]
  final List<String> skills;

  /// True once admin has verified the tasker's ID document
  final bool idVerified;

  /// Firebase Storage URL for the uploaded ID document
  final String? idDocumentUrl;

  /// True once admin approves the tasker to start receiving jobs
  final bool isApproved;

  /// Average rating computed from all reviews (0.0 – 5.0)
  final double rating;

  final int totalJobsCompleted;

  /// Cumulative earnings in GHS
  final double earnings;

  /// Tasker can toggle this off when unavailable
  final bool availability;

  TaskerModel({
    required this.uid,
    required this.skills,
    required this.idVerified,
    this.idDocumentUrl,
    required this.isApproved,
    required this.rating,
    required this.totalJobsCompleted,
    required this.earnings,
    required this.availability,
  });

  // ---------------------------------------------------------------------------
  // Factory: from DocumentSnapshot
  // ---------------------------------------------------------------------------
  factory TaskerModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TaskerModel(
      uid: doc.id,
      skills: List<String>.from(data['skills'] ?? []),
      idVerified: data['idVerified'] as bool? ?? false,
      idDocumentUrl: data['idDocumentUrl'] as String?,
      isApproved: data['isApproved'] as bool? ?? false,
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      totalJobsCompleted: data['totalJobsCompleted'] as int? ?? 0,
      earnings: (data['earnings'] as num?)?.toDouble() ?? 0.0,
      availability: data['availability'] as bool? ?? true,
    );
  }

  // ---------------------------------------------------------------------------
  // Factory: from plain Map
  // ---------------------------------------------------------------------------
  factory TaskerModel.fromMap(String uid, Map<String, dynamic> data) {
    return TaskerModel(
      uid: uid,
      skills: List<String>.from(data['skills'] ?? []),
      idVerified: data['idVerified'] as bool? ?? false,
      idDocumentUrl: data['idDocumentUrl'] as String?,
      isApproved: data['isApproved'] as bool? ?? false,
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      totalJobsCompleted: data['totalJobsCompleted'] as int? ?? 0,
      earnings: (data['earnings'] as num?)?.toDouble() ?? 0.0,
      availability: data['availability'] as bool? ?? true,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialize for Firestore writes
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'skills': skills,
      'idVerified': idVerified,
      'idDocumentUrl': idDocumentUrl,
      'isApproved': isApproved,
      'rating': rating,
      'totalJobsCompleted': totalJobsCompleted,
      'earnings': earnings,
      'availability': availability,
    };
  }

  // ---------------------------------------------------------------------------
  // CopyWith
  // ---------------------------------------------------------------------------
  TaskerModel copyWith({
    List<String>? skills,
    bool? idVerified,
    String? idDocumentUrl,
    bool? isApproved,
    double? rating,
    int? totalJobsCompleted,
    double? earnings,
    bool? availability,
  }) {
    return TaskerModel(
      uid: uid,
      skills: skills ?? this.skills,
      idVerified: idVerified ?? this.idVerified,
      idDocumentUrl: idDocumentUrl ?? this.idDocumentUrl,
      isApproved: isApproved ?? this.isApproved,
      rating: rating ?? this.rating,
      totalJobsCompleted: totalJobsCompleted ?? this.totalJobsCompleted,
      earnings: earnings ?? this.earnings,
      availability: availability ?? this.availability,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// A tasker can receive jobs only when approved, ID-verified, and available
  bool get canReceiveJobs => isApproved && idVerified && availability;

  /// Formatted rating string e.g. "4.7"
  String get formattedRating => rating.toStringAsFixed(1);

  /// Formatted earnings string e.g. "GHS 1,200.00"
  String get formattedEarnings =>
      'GHS ${earnings.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

  @override
  String toString() =>
      'TaskerModel(uid: $uid, skills: $skills, isApproved: $isApproved, rating: $rating)';
}
