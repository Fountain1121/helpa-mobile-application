import 'package:cloud_firestore/cloud_firestore.dart';

/// Notification types used across the Helpa platform.
/// Used to determine routing and icon when a notification is tapped.
enum NotificationType {
  jobAssigned,
  jobAccepted,
  jobOnTheWay,
  jobInProgress,
  jobCompleted,
  jobCancelled,
  payment,
  taskerApproved,
  newReview,
  general,
}

/// Represents a single in-app or push notification.
/// Stored in the `notifications` Firestore collection.
/// Each document belongs to one user (customer, tasker, or admin).
class NotificationModel {
  final String notifId;

  /// The user this notification is addressed to
  final String userId;

  final String title;
  final String body;

  final NotificationType type;

  /// Optional reference to the related job (for deep linking)
  final String? jobId;

  /// False until the user opens/reads the notification
  final bool isRead;

  final DateTime createdAt;

  NotificationModel({
    required this.notifId,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.jobId,
    required this.isRead,
    required this.createdAt,
  });

  // ---------------------------------------------------------------------------
  // Factory: from DocumentSnapshot
  // ---------------------------------------------------------------------------
  factory NotificationModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      notifId: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: _typeFromString(data['type'] as String? ?? 'general'),
      jobId: data['jobId'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Factory: from plain Map
  // ---------------------------------------------------------------------------
  factory NotificationModel.fromMap(String notifId, Map<String, dynamic> data) {
    return NotificationModel(
      notifId: notifId,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: _typeFromString(data['type'] as String? ?? 'general'),
      jobId: data['jobId'] as String?,
      isRead: data['isRead'] as bool? ?? false,
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
      'userId': userId,
      'title': title,
      'body': body,
      'type': _typeToString(type),
      'jobId': jobId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ---------------------------------------------------------------------------
  // CopyWith — mainly used to mark a notification as read
  // ---------------------------------------------------------------------------
  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      notifId: notifId,
      userId: userId,
      title: title,
      body: body,
      type: type,
      jobId: jobId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Type serialization helpers
  // ---------------------------------------------------------------------------
  static NotificationType _typeFromString(String value) {
    switch (value) {
      case 'job_assigned':
        return NotificationType.jobAssigned;
      case 'job_accepted':
        return NotificationType.jobAccepted;
      case 'job_on_the_way':
        return NotificationType.jobOnTheWay;
      case 'job_in_progress':
        return NotificationType.jobInProgress;
      case 'job_completed':
        return NotificationType.jobCompleted;
      case 'job_cancelled':
        return NotificationType.jobCancelled;
      case 'payment':
        return NotificationType.payment;
      case 'tasker_approved':
        return NotificationType.taskerApproved;
      case 'new_review':
        return NotificationType.newReview;
      default:
        return NotificationType.general;
    }
  }

  static String _typeToString(NotificationType type) {
    switch (type) {
      case NotificationType.jobAssigned:
        return 'job_assigned';
      case NotificationType.jobAccepted:
        return 'job_accepted';
      case NotificationType.jobOnTheWay:
        return 'job_on_the_way';
      case NotificationType.jobInProgress:
        return 'job_in_progress';
      case NotificationType.jobCompleted:
        return 'job_completed';
      case NotificationType.jobCancelled:
        return 'job_cancelled';
      case NotificationType.payment:
        return 'payment';
      case NotificationType.taskerApproved:
        return 'tasker_approved';
      case NotificationType.newReview:
        return 'new_review';
      case NotificationType.general:
        return 'general';
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns a relevant icon code point for display in the UI
  /// (uses Material Icons codepoints)
  int get iconCodePoint {
    switch (type) {
      case NotificationType.jobAssigned:
      case NotificationType.jobAccepted:
        return 0xe8b8; // assignment_turned_in
      case NotificationType.jobOnTheWay:
        return 0xe530; // directions_run
      case NotificationType.jobInProgress:
        return 0xe8d5; // build
      case NotificationType.jobCompleted:
        return 0xe876; // check_circle
      case NotificationType.jobCancelled:
        return 0xe888; // cancel
      case NotificationType.payment:
        return 0xe263; // payment
      case NotificationType.taskerApproved:
        return 0xe7fb; // verified_user
      case NotificationType.newReview:
        return 0xe838; // star
      case NotificationType.general:
      default:
        return 0xe7f4; // notifications
    }
  }

  @override
  String toString() =>
      'NotificationModel(notifId: $notifId, type: $type, isRead: $isRead)';
}
