import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/copyable_error_widget.dart';
import '../services/search_service.dart';
import '../../invitations/providers/invites_provider.dart';
import '../../invitations/services/invite_error_handler.dart';

/// Callback when a result is tapped
typedef OnResultTap = Function(UserSearchResult result);

/// Widget to display search results list
class SearchResultListWidget extends ConsumerWidget {
  final List<UserSearchResult> results;
  final bool isLoading;
  final String? error;
  final OnResultTap onTap;
  final VoidCallback onRetry;

  const SearchResultListWidget({
    Key? key,
    required this.results,
    required this.isLoading,
    this.error,
    required this.onTap,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Show loading state
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show error state
    if (error != null && error!.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: CopyableErrorWidget(
            error: error!,
            title: 'Search Error',
            onRetry: onRetry,
          ),
        ),
      );
    }

    // Show empty state if no results
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_search, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No results found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching with different keywords',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Show results list
    return ListView.builder(
      itemCount: results.length,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemBuilder: (context, index) {
        final result = results[index];
        return _SearchResultTile(
          result: result,
          onTap: () => onTap(result),
          ref: ref,
        );
      },
    );
  }
}

/// Individual search result tile
class _SearchResultTile extends StatelessWidget {
  final UserSearchResult result;
  final VoidCallback onTap;
  final WidgetRef ref;

  const _SearchResultTile({
    required this.result,
    required this.onTap,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              // Profile picture
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[300],
                  image: result.profilePictureUrl != null
                      ? DecorationImage(
                          image: NetworkImage(result.profilePictureUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: result.profilePictureUrl == null
                    ? Center(
                        child: Icon(
                          Icons.person,
                          color: Colors.grey[600],
                          size: 28,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.email,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Private profile badge
              if (result.isPrivateProfile)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(
                    Icons.lock,
                    size: 18,
                    color: Colors.grey[500],
                  ),
                ),
              // Actions menu
              PopupMenuButton(
                icon: Icon(Icons.more_vert, color: Colors.grey[500]),
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.person, size: 20),
                        SizedBox(width: 8),
                        Text('View Profile'),
                      ],
                    ),
                    onTap: onTap,
                  ),
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.mail_outline, size: 20),
                        SizedBox(width: 8),
                        Text('Send Invitation'),
                      ],
                    ),
                    onTap: () {
                      _sendInvitation(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Send invitation to the user
  void _sendInvitation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return _SendInvitationDialog(
          result: result,
          ref: ref,
          onSuccess: () {
            Navigator.of(dialogContext).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invitation sent to ${result.username}!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          onError: (error) {
            Navigator.of(dialogContext).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          },
        );
      },
    );
  }
}

/// Dialog for sending invitation to a user
class _SendInvitationDialog extends ConsumerStatefulWidget {
  final UserSearchResult result;
  final WidgetRef ref;
  final VoidCallback onSuccess;
  final Function(String) onError;

  const _SendInvitationDialog({
    required this.result,
    required this.ref,
    required this.onSuccess,
    required this.onError,
  });

  @override
  ConsumerState<_SendInvitationDialog> createState() =>
      _SendInvitationDialogState();
}

class _SendInvitationDialogState extends ConsumerState<_SendInvitationDialog> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Invitation'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text('Send a chat invitation to ${widget.result.username}?'),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[300],
                  image: widget.result.profilePictureUrl != null
                      ? DecorationImage(
                          image: NetworkImage(widget.result.profilePictureUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: widget.result.profilePictureUrl == null
                    ? Center(
                        child: Icon(
                          Icons.person,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.result.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      widget.result.email,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendInvitation,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }

  Future<void> _sendInvitation() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(sendInviteMutationProvider.notifier)
          .sendInvite(widget.result.userId);
      widget.onSuccess();
    } catch (e) {
      final errorMessage =
          InviteErrorHandler.getUserFriendlyMessage(e);
      InviteErrorHandler.logError('Send Invite from Search', e);
      widget.onError(errorMessage);
    }
  }
}
