import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/job_model.dart';
import '../../widgets/helpa_text_field.dart';

/// Multi-step job request form.
///
/// Step 1 — Service type + subtype
/// Step 2 — Description
/// Step 3 — Location + time + budget
/// Step 4 — Review & submit
class RequestFormScreen extends StatefulWidget {
  final String initialServiceType;

  const RequestFormScreen({super.key, required this.initialServiceType});

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  bool _isSubmitting = false;
  String? _errorMessage;

  late String _serviceType;
  String _serviceSubtype = '';
  final _descController = TextEditingController();
  final _addressController = TextEditingController();
  final _budgetController = TextEditingController();
  DateTime _preferredTime = DateTime.now().add(const Duration(hours: 2));

  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  static const _subtypes = {
    'home_service': [
      ('tv_mounting', 'TV Mounting', Icons.tv),
      ('plumbing', 'Plumbing', Icons.water_drop_outlined),
      ('electrical', 'Electrical Repairs', Icons.bolt_outlined),
      ('furniture_assembly', 'Furniture Assembly', Icons.chair_outlined),
    ],
    'cleaning': [
      ('home_cleaning', 'Home Cleaning', Icons.home_outlined),
      ('office_cleaning', 'Office Cleaning', Icons.business_outlined),
      ('deep_cleaning', 'Deep Cleaning', Icons.cleaning_services_outlined),
    ],
    'errand': [
      ('shopping', 'Shopping Run', Icons.shopping_bag_outlined),
      ('pickup', 'Pickup', Icons.directions_car_outlined),
      ('queue', 'Queue / Wait in Line', Icons.people_outline),
    ],
    'delivery': [
      ('package_delivery', 'Package Delivery', Icons.inventory_2_outlined),
      ('document_delivery', 'Document Delivery', Icons.description_outlined),
      ('food_pickup', 'Food Pickup', Icons.fastfood_outlined),
    ],
  };

  static const _typeLabels = {
    'home_service': 'Home Services',
    'cleaning': 'Cleaning',
    'errand': 'Errands',
    'delivery': 'Delivery',
  };
  static const _typeColors = {
    'home_service': Color(0xFF0057FF),
    'cleaning': Color(0xFF00B274),
    'errand': Color(0xFFFF6B00),
    'delivery': Color(0xFF9B51E0),
  };
  static const _typeIcons = {
    'home_service': Icons.handyman_outlined,
    'cleaning': Icons.cleaning_services_outlined,
    'errand': Icons.directions_run_rounded,
    'delivery': Icons.local_shipping_outlined,
  };

  @override
  void initState() {
    super.initState();
    _serviceType = widget.initialServiceType;
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _slideAnim = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _goToStep(int step) async {
    await _animController.reverse();
    setState(() {
      _step = step;
      _errorMessage = null;
    });
    _animController.forward();
  }

  void _tryAdvance() {
    if (_step == 0 && _serviceSubtype.isEmpty) {
      setState(() => _errorMessage = 'Please select a specific service.');
      return;
    }
    if (_step == 1 && _descController.text.trim().length < 10) {
      setState(() => _errorMessage =
          'Please describe what you need (at least 10 characters).');
      return;
    }
    if (_step == 2 &&
        (_addressController.text.trim().isEmpty ||
            _budgetController.text.trim().isEmpty)) {
      setState(() => _errorMessage = 'Please enter your address and budget.');
      return;
    }
    _goToStep(_step + 1);
  }

  Future<void> _submitRequest() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final budget = double.tryParse(_budgetController.text.trim()) ?? 0;
      final job = JobModel(
        jobId: '',
        customerId: uid,
        serviceType: _serviceType,
        serviceSubtype: _serviceSubtype,
        description: _descController.text.trim(),
        photos: [],
        location: {
          'address': _addressController.text.trim(),
          'lat': 0,
          'lng': 0
        },
        preferredTime: _preferredTime,
        budget: budget,
        status: 'pending',
        paymentStatus: 'unpaid',
        createdAt: DateTime.now(),
      );
      await FirebaseFirestore.instance.collection('jobs').add(job.toMap());
      if (mounted) _showSuccessSheet();
    } catch (e) {
      setState(() => _errorMessage = 'Failed to submit. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessSheet(
        serviceSubtype: _serviceSubtype,
        onDone: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressBar(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child:
                    SlideTransition(position: _slideAnim, child: _buildStep()),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final titles = [
      'What do you need?',
      'Describe the job',
      'Location & timing',
      'Review & confirm',
    ];
    final subs = [
      'Choose a specific service',
      'Help the tasker understand',
      'Where and when?',
      'Check everything looks right',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () =>
                _step == 0 ? Navigator.of(context).pop() : _goToStep(_step - 1),
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
          const Spacer(),
          Text('Step ${_step + 1} of 4',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 20),
        Text(titles[_step],
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A0A0A),
                letterSpacing: -0.7,
                height: 1.1)),
        const SizedBox(height: 4),
        Text(subs[_step],
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(4, (i) {
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
              decoration: BoxDecoration(
                color: i <= _step
                    ? const Color(0xFF0057FF)
                    : const Color(0xFFE5EAFF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      default:
        return const SizedBox.shrink();
    }
  }

  // Step 1 — Service subtype
  Widget _buildStep1() {
    final subtypes = _subtypes[_serviceType] ?? [];
    final color = _typeColors[_serviceType] ?? const Color(0xFF0057FF);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Category pill row
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _subtypes.keys.map((type) {
              final selected = type == _serviceType;
              final c = _typeColors[type] ?? const Color(0xFF0057FF);
              return GestureDetector(
                onTap: () => setState(() {
                  _serviceType = type;
                  _serviceSubtype = '';
                  _errorMessage = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? c : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: selected ? c : const Color(0xFFE5E9F0),
                        width: 1.5),
                  ),
                  child: Row(children: [
                    Icon(_typeIcons[type],
                        size: 15, color: selected ? Colors.white : c),
                    const SizedBox(width: 6),
                    Text(_typeLabels[type] ?? type,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF0A0A0A))),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        Text('Choose a service',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500)),
        const SizedBox(height: 12),
        ...subtypes.map((entry) {
          final (value, label, icon) = entry;
          final selected = _serviceSubtype == value;
          return GestureDetector(
            onTap: () => setState(() {
              _serviceSubtype = value;
              _errorMessage = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.06) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: selected ? color : const Color(0xFFE5E9F0),
                    width: selected ? 2 : 1.5),
              ),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.1)
                          : const Color(0xFFF5F7FF),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon,
                      size: 20, color: selected ? color : Colors.grey.shade500),
                ),
                const SizedBox(width: 14),
                Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected ? color : const Color(0xFF0A0A0A))),
                const Spacer(),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: color, size: 20),
              ]),
            ),
          );
        }),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          _InlineError(message: _errorMessage!),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }

  // Step 2 — Description
  Widget _buildStep2() {
    final color = _typeColors[_serviceType] ?? const Color(0xFF0057FF);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ServiceBadge(
            type: _serviceType, subtype: _serviceSubtype, color: color),
        const SizedBox(height: 20),
        Text('Describe the job',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descController,
          maxLines: 5,
          maxLength: 500,
          style: const TextStyle(
              fontSize: 15, color: Color(0xFF0A0A0A), height: 1.5),
          decoration: InputDecoration(
            hintText:
                'e.g. My kitchen tap is leaking and the pipe under the sink is dripping...',
            hintStyle: TextStyle(
                color: Colors.grey.shade400, fontSize: 14, height: 1.5),
            filled: true,
            fillColor: const Color(0xFFF5F7FF),
            contentPadding: const EdgeInsets.all(16),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFFE0E7FF), width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFF0057FF), width: 2)),
          ),
          onChanged: (_) => setState(() => _errorMessage = null),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(12)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFF0057FF)),
              SizedBox(width: 6),
              Text('Tips for a great request',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0057FF))),
            ]),
            const SizedBox(height: 8),
            ...[
              'Be specific about what needs to be done',
              'Mention any materials or tools required',
              'Note the size of the space if relevant',
            ].map((tip) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(
                                color: Color(0xFF0057FF), fontSize: 13)),
                        Expanded(
                            child: Text(tip,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    height: 1.4))),
                      ]),
                )),
          ]),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          _InlineError(message: _errorMessage!),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }

  // Step 3 — Location + time + budget
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Location',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        HelpaTextField(
          label: 'Address',
          hint: 'e.g. 15 Abelemkpe Road, Accra',
          controller: _addressController,
          prefixIcon: Icons.location_on_outlined,
          keyboardType: TextInputType.streetAddress,
        ),
        const SizedBox(height: 20),
        Text('Preferred time',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDateTime,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E7FF), width: 1.5),
            ),
            child: Row(children: [
              const Icon(Icons.access_time_outlined,
                  color: Color(0xFF0057FF), size: 20),
              const SizedBox(width: 12),
              Text(_formatDateTime(_preferredTime),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0A0A0A))),
              const Spacer(),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        Text('Your budget (GHS)',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        HelpaTextField(
          label: 'Budget',
          hint: 'e.g. 150',
          controller: _budgetController,
          prefixIcon: Icons.payments_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 8),
        Text(
          'This is your starting offer. The tasker may suggest a different price.',
          style:
              TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.5),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          _InlineError(message: _errorMessage!),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _preferredTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF0057FF))),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_preferredTime),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF0057FF))),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    setState(() => _preferredTime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

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

  // Step 4 — Review
  Widget _buildStep4() {
    final color = _typeColors[_serviceType] ?? const Color(0xFF0057FF);
    final budget = double.tryParse(_budgetController.text.trim()) ?? 0;
    final split = JobModel.calculateSplit(budget);
    final subtypeLabel = _subtypes[_serviceType]
            ?.cast<(String, String, IconData)?>()
            .firstWhere((e) => e?.$1 == _serviceSubtype, orElse: () => null)
            ?.$2 ??
        _serviceSubtype;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(_typeIcons[_serviceType], color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(subtypeLabel,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A0A0A))),
                Text(_typeLabels[_serviceType] ?? '',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ]),
            ]),
            const Divider(height: 28, color: Color(0xFFEEF1F7)),
            _ReviewRow(
                icon: Icons.notes_outlined,
                label: 'Description',
                value: _descController.text.trim()),
            const SizedBox(height: 12),
            _ReviewRow(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: _addressController.text.trim()),
            const SizedBox(height: 12),
            _ReviewRow(
                icon: Icons.access_time_outlined,
                label: 'Preferred time',
                value: _formatDateTime(_preferredTime)),
            const SizedBox(height: 12),
            _ReviewRow(
                icon: Icons.payments_outlined,
                label: 'Your budget',
                value: 'GHS ${budget.toStringAsFixed(2)}'),
          ]),
        ),
        const SizedBox(height: 20),

        // Commission breakdown
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            const Row(children: [
              Icon(Icons.info_outline, size: 16, color: Color(0xFF0057FF)),
              SizedBox(width: 6),
              Text('Estimated breakdown',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0057FF))),
            ]),
            const SizedBox(height: 10),
            _BreakdownRow(
                label: 'Tasker receives',
                value: 'GHS ${split['taskerPayout']!.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            _BreakdownRow(
                label: 'Helpa service fee',
                value: 'GHS ${split['commission']!.toStringAsFixed(2)}'),
            Divider(color: Colors.grey.shade300, height: 16),
            _BreakdownRow(
                label: 'Total',
                value: 'GHS ${budget.toStringAsFixed(2)}',
                bold: true),
          ]),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _InlineError(message: _errorMessage!),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildBottomBar() {
    final isLastStep = _step == 3;
    final color = _typeColors[_serviceType] ?? const Color(0xFF0057FF);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            Border(top: BorderSide(color: Colors.grey.shade100, width: 1.5)),
      ),
      child: GestureDetector(
        onTap:
            _isSubmitting ? null : (isLastStep ? _submitRequest : _tryAdvance),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: _isSubmitting ? color.withValues(alpha: 0.7) : color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Center(
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Text(
                    isLastStep ? 'Submit Request' : 'Continue',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2),
                  ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline, size: 16, color: Color(0xFFFF3B30)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFFB71C1C), height: 1.4))),
      ]),
    );
  }
}

class _ServiceBadge extends StatelessWidget {
  final String type;
  final String subtype;
  final Color color;
  const _ServiceBadge(
      {required this.type, required this.subtype, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = subtype.replaceAll('_', ' ').split(' ').map((w) {
      return w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w;
    }).join(' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ReviewRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: Colors.grey.shade400),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0A0A0A),
                  height: 1.4)),
        ]),
      ),
    ]);
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _BreakdownRow(
      {required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label,
          style: TextStyle(
              fontSize: 13,
              color: bold ? const Color(0xFF0A0A0A) : Colors.grey.shade600,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      const Spacer(),
      Text(value,
          style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: const Color(0xFF0A0A0A))),
    ]);
  }
}

class _SuccessSheet extends StatelessWidget {
  final String serviceSubtype;
  final VoidCallback onDone;
  const _SuccessSheet({required this.serviceSubtype, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final label = serviceSubtype.replaceAll('_', ' ').split(' ').map((w) {
      return w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w;
    }).join(' ');

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 28),
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
              color: Color(0xFFE6F9F3), shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded,
              color: Color(0xFF00B274), size: 38),
        ),
        const SizedBox(height: 20),
        const Text('Request Submitted!',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A0A0A),
                letterSpacing: -0.5)),
        const SizedBox(height: 10),
        Text(
          'Your $label request has been sent.\nWe\'ll match you with a verified tasker shortly.',
          textAlign: TextAlign.center,
          style:
              TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.6),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF8E6),
              borderRadius: BorderRadius.circular(20)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bolt, size: 14, color: Color(0xFFF59E0B)),
            SizedBox(width: 4),
            Text('Status: Pending',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF59E0B))),
          ]),
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: onDone,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF0057FF),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF0057FF).withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ],
            ),
            child: const Center(
              child: Text('Back to Home',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ]),
    );
  }
}
