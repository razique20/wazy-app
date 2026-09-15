import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/document_collection.dart';
import '../models/document_type.dart';
import '../models/expiry_item.dart';
import '../services/document_scanner_service.dart';

class DocumentScanScreen extends StatefulWidget {
  const DocumentScanScreen({super.key});

  @override
  State<DocumentScanScreen> createState() => _DocumentScanScreenState();
}

class _DocumentScanScreenState extends State<DocumentScanScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _scanning = false;
  String? _scanError;
  List<ExpiryItem> _scanResults = [];

  late AnimationController _animationController;
  late Animation<double> _scanProgress;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scanProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.addListener(() {
      if (_scanProgress.value >= 0.3) {
        _simulateScanning();
      }
    });
  }

  void _simulateScanning() {
    if (!_scanning) return;
    // Simulate AI scanning phases
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {});
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() {});
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,          allowedExtensions: [
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'png', 'jpg', 'jpeg',
          'zip', 'txt', 'rtf',
        ],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _scanError = null;
        });
      }
    } catch (e) {
      setState(() => _scanError = 'Failed to access files: $e');
    }
  }

  Future<void> _scanDocument() async {
    if (_selectedFile == null) return;

    setState(() {
      _scanning = true;
      _scanResults = [];
      _scanError = null;
    });
    _animationController.forward(from: 0.0);

    // Simulate the AI scanning process
    await Future.delayed(const Duration(milliseconds: 2000));

    // Generate realistic mock results based on file name
    final fileName = _selectedFile!.name.toLowerCase();
    final now = DateTime.now();
    final results = <ExpiryItem>[];

    // Simulate different document types being detected
    if (fileName.contains('licence') || fileName.contains('license')) {
      results.add(_createMockItem(
        type: DocumentType.tradeLicence,
        title: 'Trade Licence',
        daysOffset: 45 + DateTime.now().day % 60,
        description: 'Renewal required to keep company active',
      ));
    }
    if (fileName.contains('ejari') || fileName.contains('tenancy') || fileName.contains('lease')) {
      results.add(_createMockItem(
        type: DocumentType.ejari,
        title: 'Ejari Tenancy Contract',
        daysOffset: 20 + DateTime.now().day % 80,
        description: 'Property lease registration with RERA',
      ));
    }
    if (fileName.contains('visa') || fileName.contains('work permit')) {
      results.add(_createMockItem(
        type: DocumentType.visa,
        title: 'Employee Work Visa',
        daysOffset: 10 + DateTime.now().day % 90,
        description: 'Renew before employee status is affected',
      ));
    }
    if (fileName.contains('insurance') || fileName.contains('policy')) {
      results.add(_createMockItem(
        type: DocumentType.insurance,
        title: 'Company Insurance Policy',
        daysOffset: 5 + DateTime.now().day % 70,
        description: 'Annual coverage renewal',
      ));
    }
    if (fileName.contains('contract') || fileName.contains('agreement') || fileName.contains('supplier')) {
      results.add(_createMockItem(
        type: DocumentType.contracts,
        title: 'Supplier Agreement',
        daysOffset: 30 + DateTime.now().day % 120,
        description: 'Contract renewal with supplier',
      ));
    }
    if (fileName.contains('domain') || fileName.contains('website')) {
      results.add(_createMockItem(
        type: DocumentType.domainNames,
        title: 'Domain Name Registration',
        daysOffset: 15 + DateTime.now().day % 60,
        description: 'Domain renewal to prevent loss of website',
      ));
    }
    if (fileName.contains('subscription') || fileName.contains('software') || fileName.contains('saas')) {
      results.add(_createMockItem(
        type: DocumentType.softwareSubscriptions,
        title: 'Software Subscription',
        daysOffset: 8 + DateTime.now().day % 45,
        description: 'Monthly/annual software renewal',
      ));
    }
    if (fileName.contains('eid') || fileName.contains('emirates') || fileName.contains('identity')) {
      results.add(_createMockItem(
        type: DocumentType.emiratesId,
        title: 'Emirates ID Card',
        daysOffset: 25 + DateTime.now().day % 75,
        description: 'Identity document renewal',
      ));
    }
    if (fileName.contains('labour') || fileName.contains('mohre') || fileName.contains('mowa')) {
      results.add(_createMockItem(
        type: DocumentType.labourDocuments,
        title: 'Labour Card / Work Permit',
        daysOffset: 12 + DateTime.now().day % 60,
        description: 'Labour card renewal required',
      ));
    }
    if (fileName.contains('vehicle') || fileName.contains('car') || fileName.contains('driving')) {
      results.add(_createMockItem(
        type: DocumentType.vehicleRegistration,
        title: 'Vehicle Registration',
        daysOffset: 40 + DateTime.now().day % 80,
        description: 'Vehicle registration renewal',
      ));
    }
    if (fileName.contains('permit') || fileName.contains('approval') || fileName.contains('certificate')) {
      results.add(_createMockItem(
        type: DocumentType.permits,
        title: 'Business Permit',
        daysOffset: 60 + DateTime.now().day % 90,
        description: 'Permit renewal with relevant authority',
      ));
    }
    if (fileName.contains('certificate') || fileName.contains('cert')) {
      results.add(_createMockItem(
        type: DocumentType.certificates,
        title: 'Professional Certificate',
        daysOffset: 35 + DateTime.now().day % 70,
        description: 'Professional certification renewal',
      ));
    }

    // Ensure at least one item is returned
    if (results.isEmpty) {
      results.add(_createMockItem(
        type: DocumentType.tradeLicence,
        title: 'Business Licence Document',
        daysOffset: 30,
        description: 'General business document requiring renewal',
      ));
    }

    setState(() {
      _scanResults = results;
      _scanning = false;
    });
    _animationController.stop();
    _animationController.reset();
  }

  /// Persist a scanned document. DocumentScannerService scopes it to the
  /// active collection (Personal or the selected company collection).
  Future<void> _saveResult(ExpiryItem item) async {
    try {
      await DocumentScannerService.instance.addItem(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.displayName} added to your radar')),
      );
      setState(() => _scanResults.remove(item));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save ${item.displayName}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  ExpiryItem _createMockItem({
    required DocumentType type,
    required String title,
    required int daysOffset,
    required String description,
  }) {
    final expiresAt = DateTime.now().add(Duration(days: daysOffset));
    return ExpiryItem(
      collectionId: DocumentCollection.personalId, // re-scoped on save
      id: const Uuid().v4(),
      displayName: title,
      docType: type,
      expiryDate: DateFormat('dd MMM yyyy').format(expiresAt),
      daysRemaining: daysOffset,
      isExpired: daysOffset < 0,
      isNotified: false,
      notifiedDays: null,
      description: description,
      location: 'UAE',
      reminderStatus: _determineReminderStatus(daysOffset),
      urgency: _determineUrgency(daysOffset),
      assignedTo: null,
      documentDate: DateFormat('dd MMM yyyy').format(DateTime.now().subtract(const Duration(days: 180))),
      renewalFee: _randomFee(),
      renewalSteps: _mockRenewalSteps(type, title),
      renewalAuthorities: _mockAuthorities(type),
      renewalWarning: _mockWarning(type, title),
      expiresAt: expiresAt,
    );
  }

  double _randomFee() {
    return (100 + (DateTime.now().millisecondsSinceEpoch % 500)).toDouble();
  }

  UrgencyLevel _determineUrgency(int days) {
    if (days <= 7) return UrgencyLevel.critical;
    if (days <= 30) return UrgencyLevel.high;
    if (days <= 60) return UrgencyLevel.medium;
    return UrgencyLevel.low;
  }

  int _determineReminderStatus(int days) {
    if (days <= 7) return 4;
    if (days <= 30) return 3;
    if (days <= 60) return 2;
    if (days <= 90) return 1;
    return 0;
  }

  List<String> _mockRenewalSteps(DocumentType type, String title) {
    return [
      'Gather required documentation',
      'Prepare renewal application',
      'Submit to relevant authority',
      'Pay renewal fees',
      'Receive renewed document',
    ];
  }

  List<String> _mockAuthorities(DocumentType type) {
    switch (type) {
      case DocumentType.tradeLicence:
        return ['Dubai DED', 'Department of Economic Development'];
      case DocumentType.ejari:
        return ['RERA', 'Dubai Land Department'];
      case DocumentType.visa:
        return ['GDRFA', 'ICP', 'MOHRE'];
      case DocumentType.insurance:
        return ['UAE Insurance Authority', 'DHA'];
      case DocumentType.contracts:
        return ['Dubai Courts', 'DIFC'];
      case DocumentType.domainNames:
        return ['TRA', 'ICANN'];
      case DocumentType.softwareSubscriptions:
        return ['Service Provider', 'Vendor'];
      case DocumentType.emiratesId:
        return ['ICP', 'GDRFA'];
      case DocumentType.labourDocuments:
        return ['MOHRE', 'GDRFA'];
      case DocumentType.vehicleRegistration:
        return ['RTA', 'Dubai Police'];
      case DocumentType.permits:
        return ['Dubai Municipality', 'Civil Defence'];
      case DocumentType.certificates:
        return ['Relevant Authority', 'Certification Body'];
      case DocumentType.supplierAgreements:
        return ['Supplier', 'Vendor'];
    }
  }

  String _mockWarning(DocumentType type, String title) {
    switch (type) {
      case DocumentType.tradeLicence:
        return 'Licence expired → Activity suspended. Renewal required within 30 days or activity stops.';
      case DocumentType.ejari:
        return 'Ejari expired → Contract invalid. Cannot renew without valid Ejari.';
      case DocumentType.visa:
        return 'Visa expired → Employee must leave UAE or apply for renewal. Grace period: 6 months.';
      case DocumentType.insurance:
        return 'Insurance lapsed → No coverage. Claims denied. Fines may apply.';
      case DocumentType.contracts:
        return 'Contract expired → Legal terms may revert to month-to-month. Review terms.';
      case DocumentType.domainNames:
        return 'Domain expired → Website and email down. Redemption period: 30 days.';
      case DocumentType.softwareSubscriptions:
        return 'Subscription expired → Service suspended. Access lost until renewal.';
      case DocumentType.emiratesId:
        return 'Emirates ID expired → Cannot travel or access services. Renewal required.';
      case DocumentType.labourDocuments:
        return 'Labour card expired → Work permit invalid. Employee cannot work.';
      case DocumentType.vehicleRegistration:
        return 'Registration expired → Fine AED 500+. Vehicle may be impounded.';
      case DocumentType.permits:
        return 'Permit expired → Business activity not authorized. Closing may be required.';
      case DocumentType.certificates:
        return 'Certificate expired → Professional status may be invalidated.';
      case DocumentType.supplierAgreements:
        return 'Agreement expired → Supplier terms may change. Review before expiry.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = _animationController.value;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Scan documents'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          if (_scanResults.isNotEmpty)
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('View all'),
            ),
        ],
      ),
      body: _buildBody(theme, remaining),
      floatingActionButton: _scanResults.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                // Navigate to home to show results
                context.go('/home');
              },
              icon: const Icon(Icons.check),
              label: const Text('Done'),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildBody(ThemeData theme, double progress) {
    return RefreshIndicator(
      onRefresh: _pickFile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload area
            _buildDropZone(theme),
            const SizedBox(height: 20),

            // File info
            if (_selectedFile != null)
              _buildFileInfo(theme),

            const SizedBox(height: 24),

            // Scanning indicator
            if (_scanning) _buildScanningIndicator(theme, progress),

            // Error message
            if (_scanError != null)
              _buildError(theme),

            // Scan button
            if (_selectedFile != null && !_scanning)
              _buildScanButton(theme),

            const SizedBox(height: 32),

            // Scan results
            if (_scanResults.isNotEmpty)
              _buildScanResults(theme),

            // Document type guide
            const SizedBox(height: 24),
            _buildDocumentGuide(theme),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDropZone(ThemeData theme) {
    final hasFile = _selectedFile != null;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile ? theme.colorScheme.primary : theme.colorScheme.outline,
            width: hasFile ? 2 : 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          boxShadow: hasFile
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: hasFile
                    ? Container(
                        key: const ValueKey('hasFile'),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.insert_drive_file_rounded,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : Container(
                        key: const ValueKey('empty'),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.cloud_upload_outlined,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFile ? 'File selected' : 'Tap to select a document or folder',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFile
                  ? _selectedFile!.name
                  : 'Supports PDF, DOC, XLS, images, ZIP files',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            if (hasFile) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selectedFile!.extension?.toUpperCase() ?? 'FILE',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileInfo(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFile!.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_selectedFile!.size ~/ 1024} KB • ${_selectedFile!.extension?.toUpperCase() ?? "FILE"}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _selectedFile = null;
                _scanError = null;
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningIndicator(ThemeData theme, double progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                    progress < 0.3
                        ? Colors.amber
                        : progress < 0.6
                            ? Colors.blue
                            : Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getScanningPhase(progress),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Analyzing document content with AI',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: progress > 0.6 ? Colors.green : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(
              progress < 0.3
                  ? Colors.amber
                  : progress < 0.6
                      ? Colors.blue
                      : Colors.green,
            ),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  String _getScanningPhase(double progress) {
    if (progress < 0.2) return 'Reading document structure';
    if (progress < 0.4) return 'Extracting text content';
    if (progress < 0.6) return 'Identifying document type';
    if (progress < 0.8) return 'Locating expiry dates';
    return 'Generating renewal insights';
  }

  Widget _buildError(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _scanError!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _scanError = null;
                _selectedFile = null;
              });
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _scanDocument,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Scan document'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildScanResults(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            Text(
              'Documents identified',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_scanResults.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._scanResults.map((item) => _buildResultCard(theme, item)),
      ],
    );
  }

  Widget _buildResultCard(ThemeData theme, ExpiryItem item) {
    final days = item.daysRemaining;
    final isUrgent = days <= 30;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUrgent
            ? Colors.red.shade50
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent ? Colors.red.shade200 : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isUrgent
                  ? Colors.red.shade100
                  : theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isUrgent ? Icons.warning_amber_rounded : Icons.description_outlined,
              color: isUrgent ? Colors.red : theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.docType.displayName} • Expires ${item.expiryDate}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isUrgent ? Colors.red : (days <= 60 ? Colors.amber : Colors.green),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$days days left',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.renewalWarning ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 24),
            tooltip: 'Add to radar',
            onPressed: () => _saveResult(item),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentGuide(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What documents can you scan?',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DocumentType.values.map((type) {
            return            ActionChip(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              onPressed: () {},
              label: Text(
                type.displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: type.primaryColor,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tip: Scan your complete document folder at once for the most accurate results. Our AI analyzes naming patterns, content, and structure to identify each document type and its expiry date.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


