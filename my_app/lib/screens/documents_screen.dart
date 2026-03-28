import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../models/property_document.dart';
import '../constants/api_constants.dart';

class DocumentsScreen extends StatefulWidget {
  final int propertyId;
  final bool isOwner;
  const DocumentsScreen({super.key, required this.propertyId, this.isOwner = false});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<PropertyDocument> _documents = [];
  bool _loading = true;

  static const _documentTypes = {
    'epc': 'EPC Certificate',
    'title_deeds': 'Title Deeds',
    'searches': 'Searches',
    'ta6': 'TA6 Form',
    'ta10': 'TA10 Form',
    'survey': 'Survey',
    'floor_plan': 'Floor Plan',
    'other': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    try {
      final api = context.read<ApiService>();
      final docs = await api.getPropertyDocuments(widget.propertyId);
      if (mounted) setState(() { _documents = docs; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadDocument() async {
    String selectedType = 'other';
    final titleController = TextEditingController();
    bool isPublic = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Upload Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Document Type'),
                items: _documentTypes.entries.map((e) =>
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
                ).toList(),
                onChanged: (v) => setDialogState(() => selectedType = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title (optional)'),
              ),
              SwitchListTile(
                title: const Text('Public'),
                subtitle: const Text('Visible to potential buyers'),
                value: isPublic,
                onChanged: (v) => setDialogState(() => isPublic = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Select File')),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    try {
      final api = context.read<ApiService>();
      await api.uploadPropertyDocument(
        widget.propertyId,
        file,
        documentType: selectedType,
        title: titleController.text.isNotEmpty ? titleController.text : null,
        isPublic: isPublic,
      );
      _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteDocument(PropertyDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Delete "${doc.title.isNotEmpty ? doc.title : doc.documentTypeDisplay}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final api = context.read<ApiService>();
      await api.deletePropertyDocument(widget.propertyId, doc.id);
      _loadDocuments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  PhosphorIconData _docIcon(String type) {
    switch (type) {
      case 'epc': return PhosphorIconsDuotone.leaf;
      case 'survey': return PhosphorIconsDuotone.magnifyingGlass;
      case 'floor_plan': return PhosphorIconsDuotone.mapTrifold;
      default: return PhosphorIconsDuotone.fileText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      floatingActionButton: widget.isOwner
          ? FloatingActionButton(
              onPressed: _uploadDocument,
              child: PhosphorIcon(PhosphorIconsDuotone.uploadSimple),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? const Center(child: Text('No documents'))
              : RefreshIndicator(
                  onRefresh: _loadDocuments,
                  child: ListView.builder(
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      final doc = _documents[index];
                      return ListTile(
                        leading: PhosphorIcon(_docIcon(doc.documentType)),
                        title: Text(doc.title.isNotEmpty ? doc.title : doc.documentTypeDisplay),
                        subtitle: Text(doc.documentTypeDisplay),
                        trailing: widget.isOwner
                            ? IconButton(
                                icon: PhosphorIcon(PhosphorIconsDuotone.trash),
                                onPressed: () => _deleteDocument(doc),
                              )
                            : doc.isPublic
                                ? PhosphorIcon(PhosphorIconsDuotone.eye, size: 20, color: Colors.grey)
                                : PhosphorIcon(PhosphorIconsDuotone.lock, size: 20, color: Colors.grey),
                      );
                    },
                  ),
                ),
    );
  }
}
