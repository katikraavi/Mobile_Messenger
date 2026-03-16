import 'package:flutter/material.dart';

/// EditMessageDialog widget (T053, US4)
/// 
/// Allows editing of message content with validation
class EditMessageDialog extends StatefulWidget {
  final String messageId;
  final String currentContent;
  final Function(String newContent) onSave;
  final VoidCallback? onCancel;

  const EditMessageDialog({
    Key? key,
    required this.messageId,
    required this.currentContent,
    required this.onSave,
    this.onCancel,
  }) : super(key: key);

  @override
  State<EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<EditMessageDialog> {
  late TextEditingController _controller;
  bool _isSubmitting = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentContent);
    _controller.addListener(_checkForChanges);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkForChanges() {
    setState(() {
      _hasChanges = _controller.text != widget.currentContent &&
          _controller.text.trim().isNotEmpty;
    });
  }

  Future<void> _handleSave() async {
    final newContent = _controller.text.trim();
    
    if (newContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message cannot be empty')),
      );
      return;
    }

    if (newContent == widget.currentContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      widget.onSave(newContent);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Message'),
      content: TextField(
        controller: _controller,
        maxLines: null,
        enabled: !_isSubmitting,
        decoration: InputDecoration(
          hintText: 'Edit your message...',
          border: const OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  widget.onCancel?.call();
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting || !_hasChanges ? null : _handleSave,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
