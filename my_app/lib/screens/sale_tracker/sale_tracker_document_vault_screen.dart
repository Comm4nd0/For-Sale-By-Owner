import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_theme.dart';
import '../../models/sale_document.dart';
import '../../services/api_service.dart';
import '../../widgets/branded_app_bar.dart';

class SaleTrackerDocumentVaultScreen extends StatefulWidget {
  final int saleId;
  const SaleTrackerDocumentVaultScreen({super.key, required this.saleId});

  @override
  State<SaleTrackerDocumentVaultScreen> createState() =>
      _SaleTrackerDocumentVaultScreenState();
}

class _SaleTrackerDocumentVaultScreenState
    extends State<SaleTrackerDocumentVaultScreen> {
  List<DocumentChecklistItem> _checklist = [];
  bool _loading = true;
  final Set<int> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = context.read<ApiService>();
      final json = await api.getSaleDocumentChecklist(widget.saleId);
      if (mounted) {
        setState(() {
          _checklist =
              json.map((d) => DocumentChecklistItem.fromJson(d)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load documents: $e')),
        );
      }
    }
  }

  Future<void> _uploadDocument(DocumentChecklistItem item) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    try {
      final api = context.read<ApiService>();
      await api.uploadSaleDocument(
        widget.saleId,
        picked.path,
        title: item.title,
        documentId: item.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Map<String, List<DocumentChecklistItem>> get _grouped {
    final map = <String, List<DocumentChecklistItem>>{};
    for (final item in _checklist) {
      final cat = item.categoryDisplay.isNotEmpty
          ? item.categoryDisplay
          : item.category;
      map.putIfAbsent(cat, () => []).add(item);
    }
    return map;
  }

  int get _readyCount => _checklist.where((d) => d.hasFile).length;

  IconData _statusIcon(DocumentChecklistItem item) {
    if (item.hasFile) return PhosphorIconsDuotone.checkCircle;
    if (item.status == 'not_applicable') return PhosphorIconsDuotone.minus;
    return PhosphorIconsDuotone.xCircle;
  }

  Color _statusColour(DocumentChecklistItem item) {
    if (item.hasFile) return AppTheme.forestDeep;
    if (item.status == 'not_applicable') return AppTheme.stone;
    return AppTheme.error;
  }

  Color _tierColour(String tier) {
    switch (tier) {
      case 'always':
        return AppTheme.error;
      case 'if_applicable':
        return AppTheme.warning;
      default:
        return AppTheme.stone;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Document Vault',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Readiness banner
                  Card(
                    color: AppTheme.forestMist,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(PhosphorIconsDuotone.folderOpen,
                              color: AppTheme.forestDeep, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$_readyCount / ${_checklist.length} documents uploaded',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.forestDeep,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _checklist.isNotEmpty
                                        ? _readyCount / _checklist.length
                                        : 0,
                                    minHeight: 6,
                                    backgroundColor:
                                        Colors.white.withOpacity(0.5),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        AppTheme.forestDeep),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Grouped checklist
                  ..._grouped.entries.map(_buildCategorySection),
                ],
              ),
            ),
    );
  }

  Widget _buildCategorySection(
      MapEntry<String, List<DocumentChecklistItem>> entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            entry.key,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.forestDeep,
            ),
          ),
        ),
        ...entry.value.map(_buildDocumentItem),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDocumentItem(DocumentChecklistItem item) {
    final isExpanded = _expandedIds.contains(item.id);

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              _statusIcon(item),
              color: _statusColour(item),
              size: 22,
            ),
            title: Text(
              item.title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _tierColour(item.requiredTier).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.requiredTierDisplay.isNotEmpty
                        ? item.requiredTierDisplay
                        : item.requiredTier,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _tierColour(item.requiredTier),
                    ),
                  ),
                ),
                if (item.sourceDisplay.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    item.sourceDisplay,
                    style:
                        const TextStyle(fontSize: 11, color: AppTheme.slate),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!item.hasFile)
                  IconButton(
                    icon: Icon(PhosphorIconsDuotone.uploadSimple,
                        color: AppTheme.forestMid, size: 20),
                    onPressed: () => _uploadDocument(item),
                    tooltip: 'Upload',
                  ),
                IconButton(
                  icon: Icon(
                    isExpanded
                        ? PhosphorIconsDuotone.caretUp
                        : PhosphorIconsDuotone.caretDown,
                    size: 18,
                    color: AppTheme.stone,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedIds.remove(item.id);
                      } else {
                        _expandedIds.add(item.id);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          if (isExpanded && item.helperText.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item.helperText,
                  style:
                      const TextStyle(fontSize: 13, color: AppTheme.slate),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
