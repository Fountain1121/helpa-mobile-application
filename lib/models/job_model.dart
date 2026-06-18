import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single service request on the Helpa platform.
/// Stored in the `jobs` Firestore collection.
class JobModel {
  final String jobId;
  final String customerId;

  /// Null until a tasker accepts the job
  final String? taskerId;

  /// Top-level category: "home_service" | "cleaning" | "errand" | "delivery"
  final String serviceType;

  /// Specific sub-type e.g. "plumbing", "tv_mounting", "home_cleaning"
  final String serviceSubtype;

  final String description;

  /// Firebase Storage URLs for photos attached to the request
  final List<String> photos;

  /// { "address": "East Legon, Accra", "lat": 5.636, "lng": -0.162 }
  final Map<String, dynamic> location;

  final DateTime preferredTime;

  /// Customer's stated budget in GHS
  final double budget;

  /// Price agreed between customer and tasker (set after quote acceptance)
  final double? agreedPrice;

  /// Job lifecycle:
  /// pending → assigned → on_the_way → in_progress → completed | cancelled
  final String status;

  /// Payment lifecycle: unpaid → paid → released
  final String paymentStatus;

  /// Helpa's commission cut in GHS (e.g. 40 on a GHS 120 job)
  final double? commission;

  /// Amount the tasker receives after commission (e.g. 80 on a GHS 120 job)
  final double? taskerPayout;

  final DateTime createdAt;
  final DateTime? completedAt;

  JobModel({
    required this.jobId,
    required this.customerId,
    this.taskerId,
    required this.serviceType,
    required this.serviceSubtype,
    required this.description,
    required this.photos,
    required this.location,
    required this.preferredTime,
    required this.budget,
    this.agreedPrice,
    required this.status,
    required this.paymentStatus,
    this.commission,
    this.taskerPayout,
    required this.createdAt,
    this.completedAt,
  });

  // ---------------------------------------------------------------------------
  // Factory: from DocumentSnapshot
  // ---------------------------------------------------------------------------
  factory JobModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobModel(
      jobId: doc.id,
      customerId: data['customerId'] as String? ?? '',
      taskerId: data['taskerId'] as String?,
      serviceType: data['serviceType'] as String? ?? '',
      serviceSubtype: data['serviceSubtype'] as String? ?? '',
      description: data['description'] as String? ?? '',
      photos: List<String>.from(data['photos'] ?? []),
      location: Map<String, dynamic>.from(data['location'] ?? {}),
      preferredTime: data['preferredTime'] != null
          ? (data['preferredTime'] as Timestamp).toDate()
          : DateTime.now(),
      budget: (data['budget'] as num?)?.toDouble() ?? 0.0,
      agreedPrice: data['agreedPrice'] != null
          ? (data['agreedPrice'] as num).toDouble()
          : null,
      status: data['status'] as String? ?? 'pending',
      paymentStatus: data['paymentStatus'] as String? ?? 'unpaid',
      commission: data['commission'] != null
          ? (data['commission'] as num).toDouble()
          : null,
      taskerPayout: data['taskerPayout'] != null
          ? (data['taskerPayout'] as num).toDouble()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Factory: from plain Map
  // ---------------------------------------------------------------------------
  factory JobModel.fromMap(String jobId, Map<String, dynamic> data) {
    return JobModel(
      jobId: jobId,
      customerId: data['customerId'] as String? ?? '',
      taskerId: data['taskerId'] as String?,
      serviceType: data['serviceType'] as String? ?? '',
      serviceSubtype: data['serviceSubtype'] as String? ?? '',
      description: data['description'] as String? ?? '',
      photos: List<String>.from(data['photos'] ?? []),
      location: Map<String, dynamic>.from(data['location'] ?? {}),
      preferredTime: data['preferredTime'] != null
          ? (data['preferredTime'] as Timestamp).toDate()
          : DateTime.now(),
      budget: (data['budget'] as num?)?.toDouble() ?? 0.0,
      agreedPrice: data['agreedPrice'] != null
          ? (data['agreedPrice'] as num).toDouble()
          : null,
      status: data['status'] as String? ?? 'pending',
      paymentStatus: data['paymentStatus'] as String? ?? 'unpaid',
      commission: data['commission'] != null
          ? (data['commission'] as num).toDouble()
          : null,
      taskerPayout: data['taskerPayout'] != null
          ? (data['taskerPayout'] as num).toDouble()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialize for Firestore writes
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'taskerId': taskerId,
      'serviceType': serviceType,
      'serviceSubtype': serviceSubtype,
      'description': description,
      'photos': photos,
      'location': location,
      'preferredTime': Timestamp.fromDate(preferredTime),
      'budget': budget,
      'agreedPrice': agreedPrice,
      'status': status,
      'paymentStatus': paymentStatus,
      'commission': commission,
      'taskerPayout': taskerPayout,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  // ---------------------------------------------------------------------------
  // CopyWith
  // ---------------------------------------------------------------------------
  JobModel copyWith({
    String? taskerId,
    String? status,
    String? paymentStatus,
    double? agreedPrice,
    double? commission,
    double? taskerPayout,
    DateTime? completedAt,
  }) {
    return JobModel(
      jobId: jobId,
      customerId: customerId,
      taskerId: taskerId ?? this.taskerId,
      serviceType: serviceType,
      serviceSubtype: serviceSubtype,
      description: description,
      photos: photos,
      location: location,
      preferredTime: preferredTime,
      budget: budget,
      agreedPrice: agreedPrice ?? this.agreedPrice,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      commission: commission ?? this.commission,
      taskerPayout: taskerPayout ?? this.taskerPayout,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Computed helpers
  // ---------------------------------------------------------------------------
  bool get isPending => status == 'pending';
  bool get isAssigned => status == 'assigned';
  bool get isInProgress => status == 'in_progress' || status == 'on_the_way';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isPaid => paymentStatus == 'paid' || paymentStatus == 'released';

  /// Human-readable status label for UI display
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'on_the_way':
        return 'On The Way';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  /// Calculates Helpa's commission based on a percentage (default 33%)
  /// Call this when setting agreedPrice to populate commission + taskerPayout.
  static Map<String, double> calculateSplit(
    double agreedPrice, {
    double commissionRate = 0.33,
  }) {
    final commission = agreedPrice * commissionRate;
    final taskerPayout = agreedPrice - commission;
    return {
      'commission': double.parse(commission.toStringAsFixed(2)),
      'taskerPayout': double.parse(taskerPayout.toStringAsFixed(2)),
    };
  }

  @override
  String toString() =>
      'JobModel(jobId: $jobId, serviceType: $serviceType, status: $status)';
}
