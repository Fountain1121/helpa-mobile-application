import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/job_model.dart';

/// The mode determines which actions are shown at the bottom.
enum JobDetailMode { available, active, past }

/// Job detail screen used by taskers.
///
/// - available  → shows Accept / Decline buttons
/// - active     → shows status progression buttons (On The Way → In Progress → Complete)
/// - past       → read-only summary
class JobDetailScreen extends StatefulWidget {
  final String jobId;
  final JobDetailMode mode;

  const JobDetailScreen({super.key, required this.jobId, required this.mode});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _actionLoading = false;

  Future<void> _acceptJob(JobModel job) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _actionLoading = true);
    try {
      final split = JobModel.calculateSplit(job.budget);
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(job.jobId)
          .update({
        'taskerId': uid,
        'status': 'assigned',
        'agreedPrice': job.budget,
        'commission': split['commission'],
        'taskerPayout': split['taskerPayout'],
      });
      if (mounted) {
        _showSnack('Job accepted! Head to My Jobs to manage it.');
        Navigator.of(context).pop();
      }
    } catch (_) {
      _showSnack('Failed to accept. Please try again.');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _declineJob() async {
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _advanceStatus(JobModel job) async {
    final next = _nextStatus(job.status);
    if (next == null) return;
    setState(() => _actionLoading = true);
    try {
      final updates = <String, dynamic>{'status': next};
      if (next == 'completed') {
        updates['completedAt'] = FieldValue.serverTimestamp();
        updates['paymentStatus'] = 'paid';
        // Increment tasker's totalJobsCompleted
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance
              .collection('taskers')
              .doc(uid)
              .update({
            'totalJobsCompleted': FieldValue.increment(1),
            'earnings': FieldValue.increment(job.taskerPayout ?? 0),
          });
        }
      }
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(job.jobId)
          .update(updates);
      if (mounted) _showSnack('Status updated to ${_statusLabel(next)}');
    } catch (_) {
      _showSnack('Failed to update status.');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  String? _nextStatus(String current) {
    switch (current) {
      case 'assigned':
        return 'on_the_way';
      case 'on_the_way':
        return 'in_progress';
      case 'in_progress':
        return 'completed';
      default:
        return null;
    }
  }

  String _nextActionLabel(String current) {
    switch (current) {
      case 'assigned':
        return 'I\'m On My Way';
      case 'on_the_way':
        return 'Start Job';
      case 'in_progress':
        return 'Mark as Complete';
      default:
        return '';
    }
  }

  String _statusLabel(String s) {
    switch (s) {
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
        return s;
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  static const _categoryColors = {
    'home_service': Color(0xFF0057FF),
    'cleaning': Color(0xFF00B274),
    'errand': Color(0xFFFF6B00),
    'delivery': Color(0xFF9B51E0),
  };
  static const _categoryIcons = {
    'home_service': Icons.handyman_outlined,
    'cleaning': Icons.cleaning_services_outlined,
    'errand': Icons.directions_run_rounded,
    'delivery': Icons.local_shipping_outlined,
  };
  static const _statusColors = {
    'pending': Color(0xFFF59E0B),
    'assigned': Color(0xFF0057FF),
    'on_the_way': Color(0xFF0057FF),
    'in_progress': Color(0xFF9B51E0),
    'completed': Color(0xFF00B274),
    'cancelled': Color(0xFFFF3B30),
  };
  static const _statusBg = {
    'pending': Color(0xFFFFF8E6),
    'assigned': Color(0xFFEEF3FF),
    'on_the_way': Color(0xFFEEF3FF),
    'in_progress': Color(0xFFF3EAFF),
    'completed': Color(0xFFE6F9F3),
    'cancelled': Color(0xFFFFF0F0),
  };

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final day = days[dt.weekday - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$day, ${dt.day} ${months[dt.month - 1]} · $hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF00B274), strokeWidth: 2));
          }

          final job = JobModel.fromDoc(snapshot.data!);
          final color =
              _categoryColors[job.serviceType] ?? const Color(0xFF0057FF);
          final icon =
              _categoryIcons[job.serviceType] ?? Icons.miscellaneous_services;
          final statusColor =
              _statusColors[job.status] ?? const Color(0xFF6B7280);
          final statusBg = _statusBg[job.status] ?? const Color(0xFFF3F4F6);

          final subtypeLabel = job.serviceSubtype
              .replaceAll('_', ' ')
              .split(' ')
              .map(
                  (w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
              .join(' ');

          return SafeArea(
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.arrow_back_ios_new,
                            size: 16, color: Color(0xFF0057FF)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('Job Details',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A0A0A),
                            letterSpacing: -0.4)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(job.statusLabel,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusColor)),
                    ),
                  ]),
                ),

                // Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hero card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                    color: color.withValues(alpha: 0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: Row(children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14)),
                                child: Icon(icon, color: color, size: 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(subtypeLabel,
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0A0A0A),
                                              letterSpacing: -0.4)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFE6F9F3),
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        child: Text(
                                          'GHS ${job.budget.toStringAsFixed(0)} budget',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF00B274)),
                                        ),
                                      ),
                                    ]),
                              ),
                            ]),
                          ),

                          const SizedBox(height: 20),

                          // Details card
                          _DetailCard(children: [
                            _DetailRow(
                                icon: Icons.notes_outlined,
                                label: 'Description',
                                value: job.description),
                            const _Divider(),
                            _DetailRow(
                                icon: Icons.location_on_outlined,
                                label: 'Location',
                                value: job.location['address'] ?? ''),
                            const _Divider(),
                            _DetailRow(
                                icon: Icons.access_time_outlined,
                                label: 'Preferred time',
                                value: _formatDateTime(job.preferredTime)),
                          ]),

                          const SizedBox(height: 16),

                          // Payout card (if accepted)
                          if (job.agreedPrice != null)
                            _DetailCard(children: [
                              _DetailRow(
                                  icon: Icons.payments_outlined,
                                  label: 'Agreed price',
                                  value:
                                      'GHS ${job.agreedPrice!.toStringAsFixed(2)}'),
                              const _Divider(),
                              _DetailRow(
                                  icon: Icons.account_balance_wallet_outlined,
                                  label: 'Your payout',
                                  value:
                                      'GHS ${job.taskerPayout?.toStringAsFixed(2) ?? '—'}',
                                  valueColor: const Color(0xFF00B274)),
                              const _Divider(),
                              _DetailRow(
                                  icon: Icons.info_outline,
                                  label: 'Helpa service fee',
                                  value:
                                      'GHS ${job.commission?.toStringAsFixed(2) ?? '—'}',
                                  valueColor: Colors.grey),
                            ]),

                          if (job.agreedPrice != null)
                            const SizedBox(height: 16),

                          // Status timeline (for active jobs)
                          if (widget.mode == JobDetailMode.active)
                            _StatusTimeline(currentStatus: job.status),

                          const SizedBox(height: 24),
                        ]),
                  ),
                ),

                // Bottom action bar
                _buildBottomBar(job),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar(JobModel job) {
    if (widget.mode == JobDetailMode.past ||
        job.status == 'completed' ||
        job.status == 'cancelled') {
      return _CompletedBar(job: job);
    }

    if (widget.mode == JobDetailMode.available && job.status == 'pending') {
      return _AvailableBar(
        isLoading: _actionLoading,
        onAccept: () => _acceptJob(job),
        onDecline: _declineJob,
      );
    }

    if (widget.mode == JobDetailMode.active) {
      final nextLabel = _nextActionLabel(job.status);
      if (nextLabel.isEmpty) return const SizedBox.shrink();
      return _ActiveBar(
        label: nextLabel,
        isLoading: _actionLoading,
        onTap: () => _advanceStatus(job),
        isComplete: job.status == 'in_progress',
      );
    }

    return const SizedBox.shrink();
  }
}

// =============================================================================
// Bottom bar variants
// =============================================================================

class _AvailableBar extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _AvailableBar(
      {required this.isLoading,
      required this.onAccept,
      required this.onDecline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            Border(top: BorderSide(color: Colors.grey.shade100, width: 1.5)),
      ),
      child: Row(children: [
        // Decline
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: isLoading ? null : onDecline,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5),
              ),
              child: const Center(
                child: Text('Decline',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF3B30))),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Accept
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: isLoading ? null : onAccept,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 54,
              decoration: BoxDecoration(
                color: isLoading
                    ? const Color(0xFF00B274).withValues(alpha: 0.7)
                    : const Color(0xFF00B274),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF00B274).withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text('Accept Job',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ActiveBar extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool isComplete;
  final VoidCallback onTap;

  const _ActiveBar({
    required this.label,
    required this.isLoading,
    required this.isComplete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isComplete ? const Color(0xFF00B274) : const Color(0xFF0057FF);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            Border(top: BorderSide(color: Colors.grey.shade100, width: 1.5)),
      ),
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: isLoading ? color.withValues(alpha: 0.7) : color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _CompletedBar extends StatelessWidget {
  final JobModel job;
  const _CompletedBar({required this.job});

  @override
  Widget build(BuildContext context) {
    final isCompleted = job.status == 'completed';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            Border(top: BorderSide(color: Colors.grey.shade100, width: 1.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.cancel,
            color:
                isCompleted ? const Color(0xFF00B274) : const Color(0xFFFF3B30),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isCompleted ? 'Job Completed' : 'Job Cancelled',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isCompleted
                  ? const Color(0xFF00B274)
                  : const Color(0xFFFF3B30),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Status timeline widget
// =============================================================================

class _StatusTimeline extends StatelessWidget {
  final String currentStatus;
  const _StatusTimeline({required this.currentStatus});

  static const _steps = [
    ('assigned', 'Assigned', Icons.assignment_outlined),
    ('on_the_way', 'On The Way', Icons.directions_run_rounded),
    ('in_progress', 'In Progress', Icons.build_outlined),
    ('completed', 'Completed', Icons.check_circle_outline),
  ];

  int _stepIndex(String status) {
    for (int i = 0; i < _steps.length; i++) {
      if (_steps[i].$1 == status) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final current = _stepIndex(currentStatus);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Progress',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A0A0A))),
          const SizedBox(height: 16),
          Row(
            children: List.generate(_steps.length, (i) {
              final done = i <= current;
              final active = i == current;
              final (_, label, icon) = _steps[i];
              return Expanded(
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: done
                          ? const Color(0xFF00B274)
                          : const Color(0xFFEEF1F7),
                      shape: BoxShape.circle,
                      boxShadow: active
                          ? [
                              BoxShadow(
                                  color:
                                      const Color(0xFF00B274).withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3))
                            ]
                          : [],
                    ),
                    child: Icon(icon,
                        size: 16,
                        color: done ? Colors.white : Colors.grey.shade400),
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w400,
                          color: done
                              ? const Color(0xFF00B274)
                              : Colors.grey.shade400)),
                  if (i < _steps.length - 1) const SizedBox.shrink(),
                ]),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Detail card helpers
// =============================================================================

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: const Color(0xFF0057FF)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? const Color(0xFF0A0A0A),
                  height: 1.4)),
        ]),
      ),
    ]);
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: Colors.grey.shade100, height: 1),
    );
  }
}
