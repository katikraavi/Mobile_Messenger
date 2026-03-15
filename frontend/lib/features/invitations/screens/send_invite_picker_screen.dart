import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/invites_provider.dart';

/// Screen for selecting a user to send an invitation to
class SendInvitePickerScreen extends ConsumerStatefulWidget {
  const SendInvitePickerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SendInvitePickerScreen> createState() =>
      _SendInvitePickerScreenState();
}

class _SendInvitePickerScreenState extends ConsumerState<SendInvitePickerScreen> {
  final _searchController = TextEditingController();
  String? _selectedUserId;
  List<Map<String, String>> _filteredUsers = [];

  // Placeholder users - TODO: Replace with actual user search from backend
  final _allUsers = [
    {'id': 'user-1', 'name': 'Alice Johnson', 'avatar': '👩'},
    {'id': 'user-2', 'name': 'Bob Smith', 'avatar': '👨'},
    {'id': 'user-3', 'name': 'Carol White', 'avatar': '👩'},
    {'id': 'user-4', 'name': 'David Brown', 'avatar': '👨'},
    {'id': 'user-5', 'name': 'Eve Davis', 'avatar': '👩'},
  ];

  @override
  void initState() {
    super.initState();
    _filteredUsers = _allUsers;
    _searchController.addListener(_filterUsers);
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers
            .where((user) =>
                user['name']!.toLowerCase().contains(query) ||
                user['id']!.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sendMutation = ref.watch(sendInviteMutationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Invitation'),
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          // User list
          Expanded(
            child: _filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_outline,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(_searchController.text.isEmpty
                            ? 'No users found'
                            : 'No users match "${_searchController.text}"'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final isSelected = _selectedUserId == user['id'];

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(user['avatar']!),
                        ),
                        title: Text(user['name']!),
                        subtitle: Text(user['id']!),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedUserId = isSelected ? null : user['id'];
                          });
                        },
                      );
                    },
                  ),
          ),
          // Send button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _selectedUserId == null || sendMutation.isLoading
                        ? null
                        : () async {
                            try {
                              await ref
                                  .read(sendInviteMutationProvider.notifier)
                                  .sendInvite(_selectedUserId!);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Invitation sent successfully!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                child: sendMutation.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Send Invitation'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
