import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Full-screen ID verification upload flow for taskers.
///
/// Steps:
///   1. Choose ID type (Ghana Card, Voter's ID, Passport, Driver's Licence)
///   2. Pick image from camera or gallery
///   3. Preview + submit — uploads to Firebase Storage,
///      writes idDocumentUrl + idDocumentType to Firestore taskers doc
class IdUploadScreen extends StatefulWidget {
  final String uid;
  final VoidCallback? onUploaded;

  const IdUploadScreen({super.key, required this.uid, this.onUploaded});

  @override
  State<IdUploadScreen> createState() => _IdUploadScreenState();
}

class _IdUploadScreenState extends State<IdUploadScreen> {
  // Steps: 0 = choose type, 1 = pick image, 2 = preview & submit
  int _step = 0;
  String _idType = '';
  XFile? _pickedFile;
  Uint8List? _previewBytes;
  bool _uploading = false;
  String? _error;
  bool _done = false;

  static const _idTypes = [
    ('ghana_card', 'Ghana Card', Icons.credit_card_outlined),
    ('voters_id', "Voter's ID", Icons.how_to_vote_outlined),
    ('passport', 'Passport', Icons.book_outlined),
    ('drivers_licence', "Driver's Licence", Icons.directions_car_outlined),
  ];

  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedFile = file;
        _previewBytes = bytes;
        _step = 2;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Could not access camera or gallery. '
          'Please grant permissions and try again.');
    }
  }

  Future<void> _upload() async {
    if (_pickedFile == null || _previewBytes == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final uid = widget.uid.isNotEmpty
          ? widget.uid
          : FirebaseAuth.instance.currentUser!.uid;

      // 1. Upload to Firebase Storage: tasker_ids/{uid}/id_document.jpg
      final ref = FirebaseStorage.instance
          .ref()
          .child('tasker_ids')
          .child(uid)
          .child('id_document.jpg');

      final uploadTask = ref.putData(
        _previewBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // 2. Write URL + type to Firestore taskers doc
      await FirebaseFirestore.instance.collection('taskers').doc(uid).update({
        'idDocumentUrl': downloadUrl,
        'idDocumentType': _idType,
        'idVerified': false, // admin will flip this to true after review
      });

      setState(() {
        _done = true;
        _uploading = false;
      });
      widget.onUploaded?.call();
    } on FirebaseException catch (e) {
      setState(() {
        _error = e.message ?? 'Upload failed. Please try again.';
        _uploading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Upload failed. Check your connection and try again.';
        _uploading = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _step = 1;
      _pickedFile = null;
      _previewBytes = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildProgress(),
          Expanded(child: _done ? _buildDoneState() : _buildStep()),
          if (!_done) _buildBottomBar(),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    final titles = [
      'Choose ID type',
      'Take or upload photo',
      'Review & submit'
    ];
    final subs = [
      'Select your valid government-issued ID',
      'Make sure all text is clearly visible',
      'Check the image before submitting',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () {
              if (_step == 0) {
                Navigator.of(context).pop();
              } else {
                setState(() {
                  _step = _step - 1;
                  _error = null;
                });
              }
            },
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
          Text('Step ${_step + 1} of 3',
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

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(
            3,
            (i) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: i <= _step
                          ? const Color(0xFF00B274)
                          : const Color(0xFFE5EAFF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step router
  // ---------------------------------------------------------------------------
  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildStep0();
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // Step 0 — Choose ID type
  // ---------------------------------------------------------------------------
  Widget _buildStep0() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      children: [
        // Accepted IDs notice
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F9F3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.verified_outlined,
                size: 18, color: Color(0xFF00B274)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'We accept valid, unexpired Ghana government-issued IDs only. '
                'Make sure the document is yours and clearly readable.',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade700, height: 1.5),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        ..._idTypes.map((entry) {
          final (value, label, icon) = entry;
          final selected = _idType == value;
          return GestureDetector(
            onTap: () => setState(() {
              _idType = value;
              _error = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF00B274).withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF00B274)
                      : const Color(0xFFE5E9F0),
                  width: selected ? 2 : 1.5,
                ),
              ),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF00B274).withValues(alpha: 0.1)
                        : const Color(0xFFF5F7FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                      size: 22,
                      color: selected
                          ? const Color(0xFF00B274)
                          : Colors.grey.shade500),
                ),
                const SizedBox(width: 14),
                Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? const Color(0xFF00B274)
                            : const Color(0xFF0A0A0A))),
                const Spacer(),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF00B274), size: 20),
              ]),
            ),
          );
        }),
        if (_error != null) ...[
          const SizedBox(height: 8),
          _ErrorBox(message: _error!),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 — Pick image
  // ---------------------------------------------------------------------------
  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected ID type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF00B274).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: const Color(0xFF00B274).withValues(alpha: 0.25)),
            ),
            child: Text(
              _idTypes
                      .cast<(String, String, IconData)?>()
                      .firstWhere((e) => e?.$1 == _idType, orElse: () => null)
                      ?.$2 ??
                  _idType,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00B274)),
            ),
          ),
          const SizedBox(height: 28),

          // Camera option
          _PickerOption(
            icon: Icons.camera_alt_outlined,
            title: 'Take a photo',
            subtitle: 'Use your camera to photograph your ID',
            color: const Color(0xFF0057FF),
            onTap: () => _pickImage(ImageSource.camera),
          ),
          const SizedBox(height: 14),

          // Gallery option
          _PickerOption(
            icon: Icons.photo_library_outlined,
            title: 'Upload from gallery',
            subtitle: 'Choose an existing photo from your device',
            color: const Color(0xFF9B51E0),
            onTap: () => _pickImage(ImageSource.gallery),
          ),

          const SizedBox(height: 24),

          // Tips
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.tips_and_updates_outlined,
                      size: 16, color: Color(0xFF0057FF)),
                  SizedBox(width: 6),
                  Text('Photo tips',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0057FF))),
                ]),
                const SizedBox(height: 8),
                ...[
                  'Place ID on a flat, dark background',
                  'Ensure all four corners are visible',
                  'No glare or shadows over the text',
                  'All text must be clearly readable',
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
                                      height: 1.4)),
                            ),
                          ]),
                    )),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBox(message: _error!),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 — Preview & submit
  // ---------------------------------------------------------------------------
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image preview
          if (_previewBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                _previewBytes!,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _reset,
              child:
                  const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.refresh, size: 16, color: Color(0xFF0057FF)),
                SizedBox(width: 6),
                Text('Retake / choose different photo',
                    style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0057FF),
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ],

          const SizedBox(height: 20),

          // Checklist before submitting
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.checklist_outlined,
                      size: 16, color: Color(0xFFF59E0B)),
                  SizedBox(width: 6),
                  Text('Before you submit',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF59E0B))),
                ]),
                const SizedBox(height: 8),
                ...[
                  'The ID is yours and unexpired',
                  'All text and photo are clearly visible',
                  'No part of the card is cut off',
                ].map((item) => Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Row(children: [
                        const Icon(Icons.check,
                            size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        Text(item,
                            style: TextStyle(
                                fontSize: 13, color: Colors.brown.shade700)),
                      ]),
                    )),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            _ErrorBox(message: _error!),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Done state
  // ---------------------------------------------------------------------------
  Widget _buildDoneState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
                color: Color(0xFFE6F9F3), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded,
                color: Color(0xFF00B274), size: 42),
          ),
          const SizedBox(height: 24),
          const Text('ID Submitted!',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A0A0A),
                  letterSpacing: -0.6)),
          const SizedBox(height: 12),
          Text(
            'Your ID has been uploaded successfully.\n'
            'Our team will review and verify it, usually within 24 hours.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: Colors.grey.shade500, height: 1.6),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.hourglass_empty_outlined,
                  size: 14, color: Color(0xFFF59E0B)),
              SizedBox(width: 6),
              Text('Pending admin review',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF59E0B))),
            ]),
          ),
          const SizedBox(height: 36),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF00B274),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF00B274).withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6))
                ],
              ),
              child: const Center(
                child: Text('Back to Profile',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom bar
  // ---------------------------------------------------------------------------
  Widget _buildBottomBar() {
    String label;
    VoidCallback? onTap;

    if (_step == 0) {
      label = 'Continue';
      onTap = () {
        if (_idType.isEmpty) {
          setState(() => _error = 'Please select an ID type to continue.');
          return;
        }
        setState(() {
          _step = 1;
          _error = null;
        });
      };
    } else if (_step == 1) {
      // On step 1 the picker tiles act as the CTAs — hide the bar
      return const SizedBox.shrink();
    } else {
      label = _uploading ? 'Uploading...' : 'Submit ID';
      onTap = _uploading ? null : _upload;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            Border(top: BorderSide(color: Colors.grey.shade100, width: 1.5)),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: _uploading
                ? const Color(0xFF00B274).withValues(alpha: 0.7)
                : const Color(0xFF00B274),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF00B274).withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Center(
            child: _uploading
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

// =============================================================================
// Sub-widgets
// =============================================================================

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PickerOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E9F0), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A0A0A))),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ]),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

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
