import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a post-job review left by a customer.
/// Stored in the `reviews` Firestore collection.
/// A review is created only once a job reaches "completed" status.
class ReviewModel {
  final String reviewId;
  final String jobId;
  final String customerId;
  final String taskerId;

  /// Rating on a scale of 1 to 5
  final int rating;

  final String comment;
  final DateTime createdAt;

  ReviewModel({
    required this.reviewId,
    required this.jobId,
    required this.customerId,
    required this.taskerId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  }) : assert(rating >= 1 && rating <= 5, 'Rating must be between 1 and 5');

  // ---------------------------------------------------------------------------
  // Factory: from DocumentSnapshot
  // ---------------------------------------------------------------------------
  factory ReviewModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      reviewId: doc.id,
      jobId: data['jobId'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      taskerId: data['taskerId'] as String? ?? '',
      rating: data['rating'] as int? ?? 5,
      comment: data['comment'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Factory: from plain Map
  // ---------------------------------------------------------------------------
  factory ReviewModel.fromMap(String reviewId, Map<String, dynamic> data) {
    return ReviewModel(
      reviewId: reviewId,
      jobId: data['jobId'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      taskerId: data['taskerId'] as String? ?? '',
      rating: data['rating'] as int? ?? 5,
      comment: data['comment'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Serialize for Firestore writes
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'customerId': customerId,
      'taskerId': taskerId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns star emoji string for display e.g. "★★★★☆" for rating 4
  String get starDisplay {
    final filled = '★' * rating;
    final empty = '☆' * (5 - rating);
    return '$filled$empty';
  }

  /// True if the review is positive (4 stars or above)
  bool get isPositive => rating >= 4;

  @override
  String toString() =>
      'ReviewModel(reviewId: $reviewId, jobId: $jobId, rating: $rating)';
}
