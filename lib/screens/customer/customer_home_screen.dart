import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/job_model.dart';
import '../../services/auth_service.dart';
import 'request_form_screen.dart';

/// The main home screen for customers.
///
/// Shows:
///  - Personalised greeting with user first name
///  - 4 service category cards
///  - Recent jobs stream from Firestore
///  - Sign out via avatar menu
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with SingleTickerProviderStateMixin {
  UserModel? _user;
  bool _loadingUser = true;

  late AnimationController _animController;
  late List<Animation<double>> _cardAnims;

  final AuthService _authService = AuthService();

  static const _categories = [
    _ServiceCategory(
      icon: Icons.handyman_outlined,
      label: 'Home\nServices',
      sublabel: 'Repairs & installs',
      serviceType: 'home_service',
      color: Color(0xFF0057FF),
      lightColor: Color(0xFFEEF3FF),
    ),
    _ServiceCategory(
      icon: Icons.cleaning_services_outlined,
      label: 'Cleaning',
      sublabel: 'Home & office',
      serviceType: 'cleaning',
      color: Color(0xFF00B274),
      lightColor: Color(0xFFE6F9F3),
    ),
    _ServiceCategory(
      icon: Icons.directions_run_rounded,
      label: 'Errands',
      sublabel: 'Shopping & pickups',
      serviceType: 'errand',
      color: Color(0xFFFF6B00),
      lightColor: Color(0xFFFFF0E6),
    ),
    _ServiceCategory(
      icon: Icons.local_shipping_outlined,
      label: 'Delivery',
      sublabel: 'Same-day parcels',
      serviceType: 'delivery',
      color: Color(0xFF9B51E0),
      lightColor: Color(0xFFF3EAFF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _cardAnims = List.generate(
      _categories.length,
          (i) => CurvedAnimation(
        parent: _animController,
        curve: Interval(i * 0.12, 0.6 + i * 0.1, curve: Curves.easeOut),
      ),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted && doc.exists) {
      setState(() {
        _user = UserModel.fromDoc(doc);
        _loadingUser = false;
      });
    }
  }

  String get _firstName =>
      _user == null ? '' : _user!.fullName.split(' ').first;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _openRequestForm(String serviceType) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) =>
            RequestFormScreen(initialServiceType: serviceType),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildGreeting()),
            SliverToBoxAdapter(child: _buildSectionLabel('Services')),
            SliverToBoxAdapter(child: _buildCategoryGrid()),
            SliverToBoxAdapter(child: _buildSectionLabel('Recent Jobs')),
            _buildRecentJobs(),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFFF7F9FC),
      elevation: 0,
      floating: true,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF0057FF),
              borderRadius: BorderRadius.circular(9),
            ),
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
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: Stack(children: [
            const Icon(Icons.notifications_outlined,
                color: Color(0xFF0A0A0A), size: 26),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFFFF3B30), shape: BoxShape.circle)),
            ),
          ]),
        ),
        PopupMenuButton<String>(
          onSelected: (v) { if (v == 'signout') _confirmSignOut(); },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          offset: const Offset(0, 48),
          child: Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF0057FF).withOpacity(0.12),
              child: Text(
                _loadingUser || _firstName.isEmpty ? '?' : _firstName[0],
                style: const TextStyle(
                    color: Color(0xFF0057FF),
                    fontWeight: FontWeight.w800,
                    fontSize: 15),
              ),
            ),
          ),
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Text(_user?.fullName ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xFF0A0A0A))),
            ),
            const PopupMenuDivider(),
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
    );
  }

  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          _loadingUser ? 'Hello 👋' : '$_greeting, $_firstName 👋',
          style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A0A0A),
              letterSpacing: -0.6,
              height: 1.2),
        ),
        const SizedBox(height: 4),
        Text('What do you need help with today?',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
      ]),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(label,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A0A0A),
              letterSpacing: -0.4)),
    );
  }

  Widget _buildCategoryGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.35,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(_categories.length, (i) {
          final cat = _categories[i];
          return FadeTransition(
            opacity: _cardAnims[i],
            child: SlideTransition(
              position: Tween<Offset>(
                  begin: const Offset(0, 0.2), end: Offset.zero)
                  .animate(_cardAnims[i]),
              child: _CategoryCard(
                  category: cat,
                  onTap: () => _openRequestForm(cat.serviceType)),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRecentJobs() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .where('customerId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(5)
            .snapshots(),
        builder: (context, snapshot) {
          // Show error — most commonly a missing Firestore composite index
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.error_outline,
                          size: 16, color: Color(0xFFFF3B30)),
                      SizedBox(width: 8),
                      Text('Could not load jobs',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF3B30))),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      snapshot.error.toString().contains('FAILED_PRECONDITION')
                          ? 'A Firestore index is required. Check the Firebase '
                          'Console → Firestore → Indexes and create a composite '
                          'index on: customerId (ASC) + createdAt (DESC).'
                          : snapshot.error.toString(),
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF0057FF), strokeWidth: 2)),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _EmptyJobsState(
                onBookNow: () => _openRequestForm('home_service'));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _JobCard(job: JobModel.fromDoc(docs[i])),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

class _ServiceCategory {
  final IconData icon;
  final String label;
  final String sublabel;
  final String serviceType;
  final Color color;
  final Color lightColor;

  const _ServiceCategory({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.serviceType,
    required this.color,
    required this.lightColor,
  });
}

class _CategoryCard extends StatefulWidget {
  final _ServiceCategory category;
  final VoidCallback onTap;
  const _CategoryCard({required this.category, required this.onTap});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: cat.color.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4)),
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 1)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: cat.lightColor,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(cat.icon, color: cat.color, size: 22),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cat.label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A0A0A),
                        height: 1.2,
                        letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text(cat.sublabel,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w400)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyJobsState extends StatelessWidget {
  final VoidCallback onBookNow;
  const _EmptyJobsState({required this.onBookNow});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEEF1F7), width: 1.5),
        ),
        child: Column(children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
                color: const Color(0xFFEEF3FF),
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.inbox_outlined,
                color: Color(0xFF0057FF), size: 30),
          ),
          const SizedBox(height: 16),
          const Text('No jobs yet',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A0A0A))),
          const SizedBox(height: 6),
          Text('Book your first service and get\nthings done today.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onBookNow,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFF0057FF),
                  borderRadius: BorderRadius.circular(30)),
              child: const Text('Book a service',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final JobModel job;
  const _JobCard({required this.job});

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
    final icon = _categoryIcons[job.serviceType] ?? Icons.miscellaneous_services;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
          child: Icon(icon, color: const Color(0xFF0057FF), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              job.serviceSubtype
                  .replaceAll('_', ' ')
                  .split(' ')
                  .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
                  .join(' '),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A0A0A)),
            ),
            const SizedBox(height: 3),
            Text(job.location['address'] ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 10),
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
      ]),
    );
  }
}