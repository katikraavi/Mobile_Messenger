import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/invites_provider.dart';
import 'send_invite_picker_screen.dart';

/// Main invitations screen displaying pending and sent invitations in tabs
class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch pending count for badge
    final pendingCount = ref.watch(pendingInviteCountProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Invitations'),
          bottom: TabBar(
            tabs: [
              Tab(
                text: pendingCount.when(
                  data: (count) => count > 0 ? 'Pending ($count)' : 'Pending',
                  loading: () => 'Pending',
                  error: (_, __) => 'Pending',
                ),
              ),
              const Tab(text: 'Sent'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Send New Invite',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SendInvitePickerScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // Pending Invitations Tab
            _PendingTab(ref: ref),
            // Sent Invitations Tab
            _SentTab(ref: ref),
          ],
        ),
      ),
    );
  }
}

/// Pending invitations tab
class _PendingTab extends StatelessWidget {
  final WidgetRef ref;

  const _PendingTab({required this.ref});

  @override
  Widget build(BuildContext context) {
    final pendingInvites = ref.watch(pendingInvitesProvider);
    final acceptMutation = ref.watch(acceptInviteMutationProvider);
    final declineMutation = ref.watch(declineInviteMutationProvider);

    return pendingInvites.when(
      data: (invites) {
        if (invites.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No pending invitations'),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: invites.length,
          itemBuilder: (context, index) {
            final invite = invites[index];
            final isProcessing =
                acceptMutation.isLoading || declineMutation.isLoading;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: invite.senderAvatarUrl != null
                    ? NetworkImage(invite.senderAvatarUrl!)
                    : null,
                child: invite.senderAvatarUrl == null
                    ? Text(invite.senderName.substring(0, 1).toUpperCase())
                    : null,
              ),
              title: Text(invite.senderName),
              subtitle: Text(
                'Sent ${_formatDate(invite.createdAt)}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    tooltip: 'Accept',
                    onPressed: isProcessing
                        ? null
                        : () async {
                            try {
                              await ref
                                  .read(acceptInviteMutationProvider.notifier)
                                  .acceptInvite(invite.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Invitation accepted! Chat created.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
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
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    tooltip: 'Decline',
                    onPressed: isProcessing
                        ? null
                        : () async {
                            try {
                              await ref
                                  .read(declineInviteMutationProvider.notifier)
                                  .declineInvite(invite.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invitation declined'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
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
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.refresh(pendingInvitesProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sent invitations tab
class _SentTab extends StatelessWidget {
  final WidgetRef ref;

  const _SentTab({required this.ref});

  @override
  Widget build(BuildContext context) {
    final sentInvites = ref.watch(sentInvitesProvider);

    return sentInvites.when(
      data: (invites) {
        if (invites.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.send_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No sent invitations'),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: invites.length,
          itemBuilder: (context, index) {
            final invite = invites[index];
            final statusColor = _getStatusColor(invite.status);
            final statusIcon = _getStatusIcon(invite.status);

            return ListTile(
              leading: Icon(statusIcon, color: statusColor),
              title: Text(invite.recipientId),
              subtitle: Text(
                '${invite.status.toUpperCase()} • Sent ${_formatDate(invite.createdAt)}',
                style: TextStyle(fontSize: 12, color: statusColor),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.refresh(sentInvitesProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'declined':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'accepted':
        return Icons.check_circle;
      case 'declined':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inMinutes < 1) {
    return 'just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else {
    return '${date.month}/${date.day}/${date.year}';
  }
}
