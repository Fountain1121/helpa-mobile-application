import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/job_model.dart';
import '../../models/user_model.dart';
import '../../models/tasker_model.dart';
import '../../services/auth_service.dart';

/// Admin dashboard — 4 tabs:
///   0 Overview · 1 Jobs · 2 Taskers · 3 Customers
///
/// FIX: All Firestore queries use only single-field filters or single-field
/// orderBy to avoid composite-index requirements.  Client-side sorting is
/// applied where needed instead.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();

  static const _tabIcons = [
    Icons.dashboard_outlined,
    Icons.work_outline,
    Icons.handyman_outlined,
    Icons.people_outline,
  ];
  static const _tabLabels = ['Overview', 'Jobs', 'Taskers', 'Customers'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
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
    if (ok == true) await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: Column(children: [
          _buildAppBar(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              // Disable swipe — prevents accidental tab changes on scroll
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _OverviewTab(),
                _JobsTab(),
                _TaskersTab(),
                _CustomersTab(),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: const Color(0xFF0057FF),
              borderRadius: BorderRadius.circular(10)),
          child: const Center(
              child: Text('H',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 10),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('helpa',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0A0A0A),
                  letterSpacing: -0.8)),
          Text('Admin Dashboard',
              style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF0057FF),
                  fontWeight: FontWeight.w600)),
        ]),
        const Spacer(),
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
      ]),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF0057FF),
        indicatorWeight: 3,
        labelColor: const Color(0xFF0057FF),
        unselectedLabelColor: Colors.grey.shade500,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        tabs: List.generate(
          4,
          (i) => Tab(
            icon: Icon(_tabIcons[i], size: 20),
            text: _tabLabels[i],
            iconMargin: const EdgeInsets.only(bottom: 2),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Tab 0 — Overview
// =============================================================================

class _OverviewTab extends StatefulWidget {
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

// No orderBy — avoids composite index requirement.
// Counts and sorting are done client-side from the full collection snapshot.
class _OverviewTabState extends State<_OverviewTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('jobs').snapshots(),
      builder: (ctx, jobsSnap) {
        if (jobsSnap.hasError)
          return const _StreamError(msg: 'Could not load jobs.');
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('taskers').snapshots(),
          builder: (ctx, taskersSnap) {
            if (taskersSnap.hasError) {
              return const _StreamError(msg: 'Could not load taskers.');
            }
            return StreamBuilder<QuerySnapshot>(
              // Single-field filter only — no index needed
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'customer')
                  .snapshots(),
              builder: (ctx, customersSnap) {
                if (customersSnap.hasError) {
                  return const _StreamError(msg: 'Could not load customers.');
                }

                final loading = jobsSnap.connectionState ==
                        ConnectionState.waiting ||
                    taskersSnap.connectionState == ConnectionState.waiting ||
                    customersSnap.connectionState == ConnectionState.waiting;

                if (loading) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF0057FF), strokeWidth: 2));
                }

                final jobs = jobsSnap.data?.docs ?? [];
                final taskers = taskersSnap.data?.docs ?? [];
                final customers = customersSnap.data?.docs ?? [];

                final totalJobs = jobs.length;
                final completedJobs = jobs
                    .where((d) => (d.data() as Map)['status'] == 'completed')
                    .length;
                final activeJobs = jobs.where((d) {
                  final s = (d.data() as Map)['status'];
                  return s == 'assigned' ||
                      s == 'on_the_way' ||
                      s == 'in_progress';
                }).length;
                final pendingJobs = jobs
                    .where((d) => (d.data() as Map)['status'] == 'pending')
                    .length;

                final approvedTaskers = taskers
                    .where((d) => (d.data() as Map)['isApproved'] == true)
                    .length;
                final pendingTaskers = taskers.length - approvedTaskers;

                double revenue = 0;
                for (final d in jobs) {
                  final data = d.data() as Map;
                  if (data['status'] == 'completed' &&
                      data['commission'] != null) {
                    revenue += (data['commission'] as num).toDouble();
                  }
                }

                final completionRate =
                    totalJobs == 0 ? 0.0 : (completedJobs / totalJobs * 100);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const _SectionTitle('At a Glance'),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.6,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _MetricCard(
                            label: 'Total Jobs',
                            value: '$totalJobs',
                            icon: Icons.work_outline,
                            color: const Color(0xFF0057FF)),
                        _MetricCard(
                            label: 'Completed',
                            value: '$completedJobs',
                            icon: Icons.check_circle_outline,
                            color: const Color(0xFF00B274)),
                        _MetricCard(
                            label: 'Active Now',
                            value: '$activeJobs',
                            icon: Icons.bolt_outlined,
                            color: const Color(0xFF9B51E0)),
                        _MetricCard(
                            label: 'Pending',
                            value: '$pendingJobs',
                            icon: Icons.hourglass_empty_outlined,
                            color: const Color(0xFFF59E0B)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle('Platform Health'),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _HealthCard(
                          label: 'Completion Rate',
                          value: '${completionRate.round()}%',
                          icon: Icons.pie_chart_outline,
                          color: const Color(0xFF00B274),
                          progress: completionRate / 100,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _HealthCard(
                          label: 'Helpa Revenue',
                          value: 'GHS ${revenue.toStringAsFixed(0)}',
                          icon: Icons.payments_outlined,
                          color: const Color(0xFF0057FF),
                          progress: null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    const _SectionTitle('People'),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _PeopleCard(
                          label: 'Customers',
                          value: '${customers.length}',
                          icon: Icons.people_outline,
                          color: const Color(0xFF0057FF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PeopleCard(
                          label: 'Active Taskers',
                          value: '$approvedTaskers',
                          sub: '$pendingTaskers awaiting approval',
                          icon: Icons.handyman_outlined,
                          color: const Color(0xFF00B274),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    const _SectionTitle('Jobs by Status'),
                    const SizedBox(height: 12),
                    _StatusBreakdown(jobs: jobs),
                    const SizedBox(height: 32),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// Tab 1 — Jobs
// FIX: when filtering by status we use a single .where() with NO orderBy,
// then sort client-side by createdAt descending.  This avoids the composite
// index requirement that was causing the tab to break.
// =============================================================================

class _JobsTab extends StatefulWidget {
  @override
  State<_JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<_JobsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _filter = 'all';

  static const _filters = [
    ('all', 'All'),
    ('pending', 'Pending'),
    ('assigned', 'Assigned'),
    ('in_progress', 'In Progress'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
  ];

  Stream<QuerySnapshot> get _stream {
    final col = FirebaseFirestore.instance.collection('jobs');
    // No orderBy here — sort client-side to avoid composite index
    if (_filter == 'all') return col.snapshots();
    return col.where('status', isEqualTo: _filter).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      // Filter chips
      SizedBox(
        height: 52,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          scrollDirection: Axis.horizontal,
          children: _filters.map((f) {
            final (value, label) = f;
            final selected = _filter == value;
            return GestureDetector(
              onTap: () => setState(() => _filter = value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF0057FF) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: selected
                          ? const Color(0xFF0057FF)
                          : Colors.grey.shade300),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.grey.shade600)),
              ),
            );
          }).toList(),
        ),
      ),

      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _StreamError(
                  msg: 'Could not load jobs.\n${snapshot.error}');
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF0057FF), strokeWidth: 2));
            }

            // Client-side sort by createdAt descending
            final docs = [...(snapshot.data?.docs ?? [])];
            docs.sort((a, b) {
              final aData = a.data() as Map;
              final bData = b.data() as Map;
              final aTime = aData['createdAt'];
              final bTime = bData['createdAt'];
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });

            if (docs.isEmpty) {
              return _EmptyState(
                  label: 'No ${_filter == 'all' ? '' : _filter} jobs yet');
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) =>
                  _AdminJobCard(job: JobModel.fromDoc(docs[i])),
            );
          },
        ),
      ),
    ]);
  }
}

// =============================================================================
// Tab 2 — Taskers
// =============================================================================

class _TaskersTab extends StatefulWidget {
  @override
  State<_TaskersTab> createState() => _TaskersTabState();
}

class _TaskersTabState extends State<_TaskersTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _inner;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _inner = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _inner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
              color: const Color(0xFFEEF1F7),
              borderRadius: BorderRadius.circular(10)),
          child: TabBar(
            controller: _inner,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
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
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            padding: const EdgeInsets.all(3),
            tabs: const [
              Tab(text: 'Pending Approval'),
              Tab(text: 'Approved'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 4),
      Expanded(
        child: TabBarView(
          controller: _inner,
          children: const [
            _TaskerList(approvedOnly: false),
            _TaskerList(approvedOnly: true),
          ],
        ),
      ),
    ]);
  }
}

class _TaskerList extends StatelessWidget {
  final bool approvedOnly;
  const _TaskerList({required this.approvedOnly});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('taskers')
          .where('isApproved', isEqualTo: approvedOnly)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _StreamError(msg: 'Could not load taskers.');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF0057FF), strokeWidth: 2));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(
              label: approvedOnly
                  ? 'No approved taskers yet'
                  : 'No pending approvals');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _TaskerCard(
              tasker: TaskerModel.fromDoc(docs[i]), approvedOnly: approvedOnly),
        );
      },
    );
  }
}

// =============================================================================
// Tab 3 — Customers
// FIX: removed orderBy('createdAt') which required a composite index and
// caused a silent stream error that reset the entire tab.
// Sorting is now done client-side after the snapshot arrives.
// =============================================================================

class _CustomersTab extends StatefulWidget {
  @override
  State<_CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<_CustomersTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<QuerySnapshot>(
      // Single .where() only — no orderBy — no composite index needed
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'customer')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _StreamError(
              msg: 'Could not load customers.\nTry refreshing the page.');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF0057FF), strokeWidth: 2));
        }

        // Client-side sort: newest first
        final docs = [...(snapshot.data?.docs ?? [])];
        docs.sort((a, b) {
          final aData = a.data() as Map;
          final bData = b.data() as Map;
          final aTime = aData['createdAt'];
          final bTime = bData['createdAt'];
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) {
          return const _EmptyState(label: 'No customers yet');
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) =>
              _CustomerCard(user: UserModel.fromDoc(docs[i])),
        );
      },
    );
  }
}

// =============================================================================
// Admin Job Card
// =============================================================================

class _AdminJobCard extends StatelessWidget {
  final JobModel job;
  const _AdminJobCard({required this.job});

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
  static const _catIcons = {
    'home_service': Icons.handyman_outlined,
    'cleaning': Icons.cleaning_services_outlined,
    'errand': Icons.directions_run_rounded,
    'delivery': Icons.local_shipping_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[job.status] ?? const Color(0xFF6B7280);
    final bg = _statusBg[job.status] ?? const Color(0xFFF3F4F6);
    final icon = _catIcons[job.serviceType] ?? Icons.miscellaneous_services;
    final subtypeLabel = job.serviceSubtype
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
        .join(' ');

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _JobActionsSheet(job: job),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: const Color(0xFF0057FF), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subtypeLabel,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0A0A0A))),
                    Text(job.location['address'] ?? '',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(20)),
              child: Text(job.statusLabel,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _InfoChip(
                icon: Icons.payments_outlined,
                label: 'GHS ${job.budget.toStringAsFixed(0)}'),
            const SizedBox(width: 8),
            if (job.taskerId != null)
              const _InfoChip(
                  icon: Icons.person_outline, label: 'Tasker assigned'),
            const Spacer(),
            Text('Tap to manage',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9CA3AF)),
          ]),
        ]),
      ),
    );
  }
}

// =============================================================================
// Job Actions Sheet
// =============================================================================

class _JobActionsSheet extends StatefulWidget {
  final JobModel job;
  const _JobActionsSheet({required this.job});

  @override
  State<_JobActionsSheet> createState() => _JobActionsSheetState();
}

class _JobActionsSheetState extends State<_JobActionsSheet> {
  bool _loading = false;

  Future<void> _updateStatus(String status) async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.job.jobId)
          .update({'status': status});
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Status updated to $status'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.job.serviceSubtype
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
        .join(' ');

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        Text(label,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A0A0A))),
        const SizedBox(height: 4),
        Text('Current: ${widget.job.statusLabel}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 20),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: CircularProgressIndicator(
                color: Color(0xFF0057FF), strokeWidth: 2),
          )
        else ...[
          if (widget.job.status != 'completed' &&
              widget.job.status != 'cancelled')
            _SheetAction(
              label: 'Cancel Job',
              icon: Icons.cancel_outlined,
              color: const Color(0xFFFF3B30),
              bg: const Color(0xFFFFF0F0),
              onTap: () => _updateStatus('cancelled'),
            ),
          if (widget.job.status == 'pending')
            _SheetAction(
              label: 'Mark as Assigned',
              icon: Icons.assignment_outlined,
              color: const Color(0xFF0057FF),
              bg: const Color(0xFFEEF3FF),
              onTap: () => _updateStatus('assigned'),
            ),
          if (widget.job.status != 'completed' &&
              widget.job.status != 'cancelled')
            _SheetAction(
              label: 'Force Complete',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF00B274),
              bg: const Color(0xFFE6F9F3),
              onTap: () => _updateStatus('completed'),
            ),
          _SheetAction(
            label: 'Close',
            icon: Icons.close,
            color: Colors.grey.shade600,
            bg: Colors.grey.shade100,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ]),
    );
  }
}

// =============================================================================
// Tasker Card
// =============================================================================

class _TaskerCard extends StatefulWidget {
  final TaskerModel tasker;
  final bool approvedOnly;
  const _TaskerCard({required this.tasker, required this.approvedOnly});

  @override
  State<_TaskerCard> createState() => _TaskerCardState();
}

class _TaskerCardState extends State<_TaskerCard> {
  bool _loading = false;

  Future<void> _setApproval(bool value) async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('taskers')
          .doc(widget.tasker.uid)
          .update({'isApproved': value});
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tasker;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF00B274).withValues(alpha: 0.12),
            child: Text(
              t.uid.isNotEmpty ? t.uid[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Color(0xFF00B274),
                  fontWeight: FontWeight.w800,
                  fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ID: ${t.uid.substring(0, 8)}...',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A0A0A))),
              Text(
                t.skills.isEmpty ? 'No skills listed' : t.skills.join(', '),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          if (_loading)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF0057FF))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _InfoChip(
              icon: Icons.star_outline,
              label: t.totalJobsCompleted == 0
                  ? 'No jobs'
                  : '${t.totalJobsCompleted} jobs'),
          const SizedBox(width: 8),
          _InfoChip(
              icon: Icons.verified_outlined,
              label: t.idVerified ? 'ID verified' : 'ID pending'),
          const SizedBox(width: 8),
          _InfoChip(icon: Icons.payments_outlined, label: t.formattedEarnings),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _ActionButton(
              label: widget.approvedOnly ? 'Suspend' : 'Approve',
              color: widget.approvedOnly
                  ? const Color(0xFFFF3B30)
                  : const Color(0xFF00B274),
              bg: widget.approvedOnly
                  ? const Color(0xFFFFF0F0)
                  : const Color(0xFFE6F9F3),
              onTap: _loading ? null : () => _setApproval(!widget.approvedOnly),
            ),
          ),
        ]),
      ]),
    );
  }
}

// =============================================================================
// Customer Card
// =============================================================================

class _CustomerCard extends StatefulWidget {
  final UserModel user;
  const _CustomerCard({required this.user});

  @override
  State<_CustomerCard> createState() => _CustomerCardState();
}

class _CustomerCardState extends State<_CustomerCard> {
  bool _loading = false;

  Future<void> _toggleActive() async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({'isActive': !widget.user.isActive});
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFF0057FF).withValues(alpha: 0.1),
          child: Text(
            u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Color(0xFF0057FF),
                fontWeight: FontWeight.w800,
                fontSize: 16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.fullName,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A0A0A))),
            Text(u.email,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            Text(u.phone,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: u.isActive
                  ? const Color(0xFFE6F9F3)
                  : const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              u.isActive ? 'Active' : 'Suspended',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: u.isActive
                      ? const Color(0xFF00B274)
                      : const Color(0xFFFF3B30)),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF0057FF)))
          else
            GestureDetector(
              onTap: _toggleActive,
              child: Text(
                u.isActive ? 'Suspend' : 'Reactivate',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0057FF),
                    fontWeight: FontWeight.w600),
              ),
            ),
        ]),
      ]),
    );
  }
}

// =============================================================================
// Overview widgets
// =============================================================================

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A0A0A),
                letterSpacing: -1)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    );
  }
}

class _HealthCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? progress;
  const _HealthCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.8)),
        if (progress != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress!.clamp(0.0, 1.0),
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ],
      ]),
    );
  }
}

class _PeopleCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color color;
  const _PeopleCard(
      {required this.label,
      required this.value,
      this.sub,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A0A0A),
                    letterSpacing: -0.8)),
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            if (sub != null)
              Text(sub!,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ]),
        ),
      ]),
    );
  }
}

class _StatusBreakdown extends StatelessWidget {
  final List<QueryDocumentSnapshot> jobs;
  const _StatusBreakdown({required this.jobs});

  static const _statuses = [
    ('pending', 'Pending', Color(0xFFF59E0B), Color(0xFFFFF8E6)),
    ('assigned', 'Assigned', Color(0xFF0057FF), Color(0xFFEEF3FF)),
    ('in_progress', 'In Progress', Color(0xFF9B51E0), Color(0xFFF3EAFF)),
    ('completed', 'Completed', Color(0xFF00B274), Color(0xFFE6F9F3)),
    ('cancelled', 'Cancelled', Color(0xFFFF3B30), Color(0xFFFFF0F0)),
  ];

  @override
  Widget build(BuildContext context) {
    final total = jobs.isEmpty ? 1 : jobs.length;
    return Container(
      padding: const EdgeInsets.all(14),
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
        children: _statuses.map((s) {
          final (status, label, color, bg) = s;
          final count =
              jobs.where((d) => (d.data() as Map)['status'] == status).length;
          final pct = count / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: bg, borderRadius: BorderRadius.circular(8)),
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
                const Spacer(),
                Text('$count',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A0A0A))),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  backgroundColor: color.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 6,
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// =============================================================================
// Shared small widgets
// =============================================================================

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0A0A0A),
            letterSpacing: -0.4));
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFF4F6FB),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback? onTap;
  const _ActionButton(
      {required this.label, required this.color, required this.bg, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _SheetAction(
      {required this.label,
      required this.icon,
      required this.color,
      required this.bg,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String label;
  const _EmptyState({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
              color: Color(0xFFEEF3FF), shape: BoxShape.circle),
          child: const Icon(Icons.inbox_outlined,
              color: Color(0xFF0057FF), size: 30),
        ),
        const SizedBox(height: 14),
        Text(label,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500)),
      ]),
    );
  }
}

/// Shown when a Firestore stream throws an error (e.g. missing index,
/// permission denied).  Surfaces the message instead of silently resetting.
class _StreamError extends StatelessWidget {
  final String msg;
  const _StreamError({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: Color(0xFFFFF0F0), shape: BoxShape.circle),
            child: const Icon(Icons.error_outline,
                color: Color(0xFFFF3B30), size: 30),
          ),
          const SizedBox(height: 14),
          Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600, height: 1.5)),
        ]),
      ),
    );
  }
}
