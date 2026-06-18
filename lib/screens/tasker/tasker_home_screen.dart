import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/tasker_model.dart';
import '../../models/job_model.dart';
import '../../services/auth_service.dart';
import 'job_detail_screen.dart';
import 'id_upload_screen.dart';

/// The main home screen for taskers.
///
/// Handles three states:
///   1. Pending approval — tasker signed up but admin hasn't approved yet
///   2. Approved + available — live feed of open jobs matching tasker skills
///   3. Active job — tasker has an accepted job currently in progress
class TaskerHomeScreen extends StatefulWidget {
  const TaskerHomeScreen({super.key});

  @override
  State<TaskerHomeScreen> createState() => _TaskerHomeScreenState();
}

class _TaskerHomeScreenState extends State<TaskerHomeScreen>
    with SingleTickerProviderStateMixin {
  UserModel? _user;
  TaskerModel? _tasker;
  bool _loading = true;

  late TabController _tabController;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final results = await Future.wait([
      FirebaseFirestore.instance.collection('users').doc(uid).get(),
      FirebaseFirestore.instance.collection('taskers').doc(uid).get(),
    ]);

    if (mounted) {
      setState(() {
        if (results[0].exists) _user = UserModel.fromDoc(results[0]);
        if (results[1].exists) _tasker = TaskerModel.fromDoc(results[1]);
        _loading = false;
      });
    }
  }

  Future<void> _toggleAvailability() async {
    if (_tasker == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final newValue = !_tasker!.availability;
    await FirebaseFirestore.instance
        .collection('taskers')
        .doc(uid)
        .update({'availability': newValue});

    setState(() => _tasker = _tasker!.copyWith(availability: newValue));
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: const Text('You will be returned to the login screen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out',
                  style: TextStyle(color: Color(0xFFFF3B30)))),
        ],
      ),
    );
    if (confirmed == true) await _authService.signOut();
  }

  String get _firstName =>
      _user == null ? '' : _user!.fullName.split(' ').first;

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F9FC),
        body: Center(
          child: CircularProgressIndicator(
              color: Color(0xFF00B274), strokeWidth: 2),
        ),
      );
    }

    // Not yet approved
    if (_tasker == null || !_tasker!.isApproved) {
      return _PendingApprovalScreen(
        user: _user,
        tasker: _tasker,
        onSignOut: _confirmSignOut,
        onIdUploaded: _loadProfile,
      );
    }

    // Approved — full tasker experience
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildStatsRow(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _AvailableJobsTab(tasker: _tasker!),
                  _MyJobsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // App bar
  // ---------------------------------------------------------------------------
  Widget _buildAppBar() {
    final available = _tasker?.availability ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF00B274).withValues(alpha: 0.15),
            child: Text(
              _firstName.isNotEmpty ? _firstName[0] : '?',
              style: const TextStyle(
                  color: Color(0xFF00B274),
                  fontWeight: FontWeight.w800,
                  fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),

          // Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hey, $_firstName 👋',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A0A0A),
                      letterSpacing: -0.4),
                ),
                Text(
                  available ? 'You\'re online' : 'You\'re offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: available
                        ? const Color(0xFF00B274)
                        : Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Availability toggle
          GestureDetector(
            onTap: _toggleAvailability,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:
                    available ? const Color(0xFF00B274) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: available ? Colors.white : Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  available ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: available ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 8),

          // Sign out menu
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'signout') _confirmSignOut();
            },
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: const Icon(Icons.more_vert, color: Color(0xFF0A0A0A)),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'signout',
                child: Row(children: [
                  Icon(Icons.logout, size: 18, color: Color(0xFFFF3B30)),
                  SizedBox(width: 10),
                  Text('Sign out', style: TextStyle(color: Color(0xFFFF3B30))),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats row
  // ---------------------------------------------------------------------------
  Widget _buildStatsRow() {
    final t = _tasker!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _StatCard(
            label: 'Jobs Done',
            value: '${t.totalJobsCompleted}',
            icon: Icons.check_circle_outline,
            color: const Color(0xFF00B274),
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'Rating',
            value: t.totalJobsCompleted == 0 ? '—' : t.formattedRating,
            icon: Icons.star_outline_rounded,
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'Earnings',
            value: t.earnings == 0
                ? 'GHS 0'
                : 'GHS ${t.earnings.toStringAsFixed(0)}',
            icon: Icons.payments_outlined,
            color: const Color(0xFF0057FF),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab bar
  // ---------------------------------------------------------------------------
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF1F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          labelColor: const Color(0xFF0A0A0A),
          unselectedLabelColor: Colors.grey.shade500,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          padding: const EdgeInsets.all(4),
          tabs: const [
            Tab(text: 'Available Jobs'),
            Tab(text: 'My Jobs'),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Tab 1 — Available Jobs
// =============================================================================

class _AvailableJobsTab extends StatelessWidget {
  final TaskerModel tasker;
  const _AvailableJobsTab({required this.tasker});

  @override
  Widget build(BuildContext context) {
    if (!tasker.availability) {
      return _OfflineState();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: Color(0xFF00B274), strokeWidth: 2),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _NoJobsState();
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final job = JobModel.fromDoc(docs[i]);
            return _AvailableJobCard(
              job: job,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JobDetailScreen(
                    jobId: job.jobId,
                    mode: JobDetailMode.available,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// Tab 2 — My Jobs (accepted/in-progress/completed)
// =============================================================================

class _MyJobsTab extends StatelessWidget {
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  _MyJobsTab();

  @override
  Widget build(BuildContext context) {
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('taskerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: Color(0xFF00B274), strokeWidth: 2),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _NoMyJobsState();
        }

        // Group into active and past
        final active = docs
            .map((d) => JobModel.fromDoc(d))
            .where((j) =>
                j.status == 'assigned' ||
                j.status == 'on_the_way' ||
                j.status == 'in_progress')
            .toList();

        final past = docs
            .map((d) => JobModel.fromDoc(d))
            .where((j) => j.status == 'completed' || j.status == 'cancelled')
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (active.isNotEmpty) ...[
              _SectionHeader(label: 'Active', count: active.length),
              const SizedBox(height: 10),
              ...active.map((job) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MyJobCard(
                      job: job,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => JobDetailScreen(
                            jobId: job.jobId,
                            mode: JobDetailMode.active,
                          ),
                        ),
                      ),
                    ),
                  )),
            ],
            if (past.isNotEmpty) ...[
              _SectionHeader(label: 'Past Jobs', count: past.length),
              const SizedBox(height: 10),
              ...past.map((job) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MyJobCard(
                      job: job,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => JobDetailScreen(
                            jobId: job.jobId,
                            mode: JobDetailMode.past,
                          ),
                        ),
                      ),
                    ),
                  )),
            ],
          ],
        );
      },
    );
  }
}

// =============================================================================
// Pending Approval Screen
// =============================================================================

class _PendingApprovalScreen extends StatelessWidget {
  final UserModel? user;
  final TaskerModel? tasker;
  final VoidCallback onSignOut;
  final VoidCallback onIdUploaded;

  const _PendingApprovalScreen({
    this.user,
    this.tasker,
    required this.onSignOut,
    required this.onIdUploaded,
  });

  @override
  Widget build(BuildContext context) {
    final idUploaded = tasker?.idDocumentUrl != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Top row
              Row(
                children: [
                  Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                          color: const Color(0xFF00B274),
                          borderRadius: BorderRadius.circular(9)),
                      child: const Center(
                        child: Text('H',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('helpa',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0A0A0A),
                            letterSpacing: -0.8)),
                  ]),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout,
                        size: 16, color: Color(0xFFFF3B30)),
                    label: const Text('Sign out',
                        style:
                            TextStyle(color: Color(0xFFFF3B30), fontSize: 13)),
                  ),
                ],
              ),

              const Spacer(),

              // Illustration
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F9F3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_outlined,
                    color: Color(0xFF00B274), size: 48),
              ),
              const SizedBox(height: 28),

              Text(
                'Welcome, ${user?.fullName.split(' ').first ?? 'there'}!',
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A0A0A),
                    letterSpacing: -0.6),
              ),
              const SizedBox(height: 10),
              Text(
                'Your profile is under review.\nOur team will verify your details and approve your account shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey.shade500, height: 1.6),
              ),

              const SizedBox(height: 32),

              // Steps checklist
              const _ApprovalStep(
                number: '1',
                title: 'Account created',
                subtitle: 'Profile and contact details saved',
                done: true,
              ),
              const SizedBox(height: 12),
              _ApprovalStep(
                number: '2',
                title: 'ID verification',
                subtitle: idUploaded
                    ? 'Your ID has been submitted'
                    : 'You\'ll need to upload a valid Ghana ID',
                done: idUploaded,
                action: idUploaded
                    ? null
                    : _UploadIdButton(
                        uid: user?.uid ?? '',
                        onUploaded: onIdUploaded,
                      ),
              ),
              const SizedBox(height: 12),
              const _ApprovalStep(
                number: '3',
                title: 'Admin approval',
                subtitle: 'Usually within 24 hours',
                done: false,
                pending: true,
              ),

              const Spacer(),

              // Info note
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notifications_outlined,
                          size: 18, color: Color(0xFF0057FF)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'We\'ll notify you by email and push notification once your account is approved.',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.5),
                        ),
                      ),
                    ]),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Available Job Card
// =============================================================================

class _AvailableJobCard extends StatelessWidget {
  final JobModel job;
  final VoidCallback onTap;

  const _AvailableJobCard({required this.job, required this.onTap});

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

  String _formatBudget(double v) => 'GHS ${v.toStringAsFixed(0)}';

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColors[job.serviceType] ?? const Color(0xFF0057FF);
    final icon =
        _categoryIcons[job.serviceType] ?? Icons.miscellaneous_services;

    final subtypeLabel = job.serviceSubtype
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
        .join(' ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 4)),
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subtypeLabel,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0A0A0A),
                              letterSpacing: -0.3)),
                      const SizedBox(height: 2),
                      Text(_timeAgo(job.createdAt),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade400)),
                    ]),
              ),
              // Budget badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFE6F9F3),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _formatBudget(job.budget),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF00B274)),
                ),
              ),
            ]),

            const SizedBox(height: 12),

            // Description preview
            Text(
              job.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600, height: 1.5),
            ),

            const SizedBox(height: 12),

            // Location + CTA row
            Row(children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  job.location['address'] ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(20)),
                child: const Text('View Job',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// My Job Card
// =============================================================================

class _MyJobCard extends StatelessWidget {
  final JobModel job;
  final VoidCallback onTap;

  const _MyJobCard({required this.job, required this.onTap});

  static const _statusColors = {
    'assigned': Color(0xFF0057FF),
    'on_the_way': Color(0xFF0057FF),
    'in_progress': Color(0xFF9B51E0),
    'completed': Color(0xFF00B274),
    'cancelled': Color(0xFFFF3B30),
  };
  static const _statusBg = {
    'assigned': Color(0xFFEEF3FF),
    'on_the_way': Color(0xFFEEF3FF),
    'in_progress': Color(0xFFF3EAFF),
    'completed': Color(0xFFE6F9F3),
    'cancelled': Color(0xFFFFF0F0),
  };
  static const _categoryIcons = {
    'home_service': Icons.handyman_outlined,
    'cleaning': Icons.cleaning_services_outlined,
    'errand': Icons.directions_run_rounded,
    'delivery': Icons.local_shipping_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColors[job.status] ?? const Color(0xFF6B7280);
    final statusBg = _statusBg[job.status] ?? const Color(0xFFF3F4F6);
    final icon =
        _categoryIcons[job.serviceType] ?? Icons.miscellaneous_services;

    final subtypeLabel = job.serviceSubtype
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
        .join(' ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xFF00B274), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(subtypeLabel,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A0A0A))),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.location_on_outlined,
                    size: 12, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    job.location['address'] ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              if (job.agreedPrice != null) ...[
                const SizedBox(height: 4),
                Text(
                  'GHS ${job.agreedPrice!.toStringAsFixed(0)} · Your payout: GHS ${job.taskerPayout?.toStringAsFixed(0) ?? '—'}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF00B274),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: statusBg, borderRadius: BorderRadius.circular(20)),
              child: Text(job.statusLabel,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor)),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9CA3AF)),
          ]),
        ]),
      ),
    );
  }
}

// =============================================================================
// Empty / offline states
// =============================================================================

class _OfflineState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: Colors.grey.shade100, shape: BoxShape.circle),
              child: Icon(Icons.wifi_off_rounded,
                  color: Colors.grey.shade400, size: 36),
            ),
            const SizedBox(height: 20),
            Text('You\'re offline',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text(
              'Go online to start seeing\navailable jobs near you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade500, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoJobsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: Color(0xFFE6F9F3), shape: BoxShape.circle),
              child: const Icon(Icons.search_off_rounded,
                  color: Color(0xFF00B274), size: 36),
            ),
            const SizedBox(height: 20),
            const Text('No jobs right now',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A0A0A))),
            const SizedBox(height: 8),
            Text(
              'New requests will appear here\nas customers submit them.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade500, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMyJobsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: Color(0xFFE6F9F3), shape: BoxShape.circle),
              child: const Icon(Icons.inbox_outlined,
                  color: Color(0xFF00B274), size: 36),
            ),
            const SizedBox(height: 20),
            const Text('No jobs accepted yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A0A0A))),
            const SizedBox(height: 8),
            Text(
              'Accept a job from the Available\ntab to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade500, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Approval step widget
// =============================================================================

class _ApprovalStep extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final bool done;
  final bool pending;
  final Widget? action;

  const _ApprovalStep({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.done,
    this.pending = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    Color circleColor;
    Widget circleChild;

    if (done) {
      circleColor = const Color(0xFF00B274);
      circleChild = const Icon(Icons.check, color: Colors.white, size: 14);
    } else if (pending) {
      circleColor = const Color(0xFFF59E0B);
      circleChild = const SizedBox(
          width: 10,
          height: 10,
          child:
              CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
    } else {
      circleColor = Colors.grey.shade300;
      circleChild = Text(number,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFFE6F9F3)
            : pending
                ? const Color(0xFFFFF8E6)
                : const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done
              ? const Color(0xFF00B274).withValues(alpha: 0.2)
              : pending
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                  : Colors.grey.shade200,
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
          child: Center(child: circleChild),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: done
                        ? const Color(0xFF00B274)
                        : const Color(0xFF0A0A0A))),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            if (action != null) ...[
              const SizedBox(height: 8),
              action!,
            ],
          ]),
        ),
      ]),
    );
  }
}

// =============================================================================
// Upload ID button — navigates to full IdUploadScreen
// =============================================================================

class _UploadIdButton extends StatelessWidget {
  final String uid;
  final VoidCallback onUploaded;

  const _UploadIdButton({required this.uid, required this.onUploaded});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) =>
                  IdUploadScreen(uid: FirebaseAuth.instance.currentUser!.uid)),
        );
        onUploaded();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: const Color(0xFF0057FF),
            borderRadius: BorderRadius.circular(20)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.upload_outlined, size: 14, color: Colors.white),
          SizedBox(width: 6),
          Text('Upload ID',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ]),
      ),
    );
  }
}

// =============================================================================
// Stat card widget
// =============================================================================

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.07),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A0A0A),
                  letterSpacing: -0.3)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }
}

// =============================================================================
// Section header
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A0A0A),
              letterSpacing: -0.4)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: const Color(0xFFE6F9F3),
            borderRadius: BorderRadius.circular(10)),
        child: Text('$count',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF00B274))),
      ),
    ]);
  }
}
