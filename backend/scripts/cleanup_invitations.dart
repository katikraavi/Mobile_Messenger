import 'dart:io';
import 'package:postgres/postgres.dart';

/// Database cleanup script for removing all invitations
/// 
/// Usage:
///   dart run scripts/cleanup_invitations.dart all        # Delete all invitations
///   dart run scripts/cleanup_invitations.dart count      # Show invitation count
///   dart run scripts/cleanup_invitations.dart list       # List all invitations

Future<void> main(List<String> args) async {
  const host = 'localhost';
  const port = 5432;
  const database = 'messenger_db';
  const username = 'messenger_user';
  const password = 'messenger_password';

  try {
    print('╔═══════════════════════════════════════════════════════╗');
    print('║        Database Invitation Cleanup Script            ║');
    print('╚═══════════════════════════════════════════════════════╝\n');

    final connection = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );

    try {
      if (args.isEmpty) {
        _printUsage();
        return;
      }

      final command = args[0].toLowerCase();

      switch (command) {
        case 'all':
          await _deleteAll(connection);
          break;
        case 'count':
          await _showCount(connection);
          break;
        case 'list':
          await _listInvitations(connection);
          break;
        case 'help':
          _printUsage();
          break;
        default:
          print('❌ Unknown command: $command');
          _printUsage();
          exit(1);
      }
    } finally {
      await connection.close();
    }

    print('\n✓ Operation completed successfully\n');
  } catch (e) {
    print('\n❌ Error: $e\n');
    exit(1);
  }
}

Future<void> _deleteAll(Connection connection) async {
  print('[INFO] Deleting all invitations...\n');

  // Get count before deletion
  final countBefore = await connection.query<int>(
    'SELECT COUNT(*) FROM chat_invites',
  );
  final before = countBefore.first.first ?? 0;

  // Delete all invitations
  await connection.execute('DELETE FROM chat_invites');

  print('   ✓ Deleted $before invitation(s)');
}

Future<void> _showCount(Connection connection) async {
  final result = await connection.query<int>(
    'SELECT COUNT(*) FROM chat_invites',
  );
  final count = result.first.first ?? 0;

  print('📊 Total invitations in database: $count');
}

Future<void> _listInvitations(Connection connection) async {
  final invites = await connection.query('''
    SELECT 
      id,
      sender_id,
      recipient_id,
      status,
      created_at,
      updated_at
    FROM chat_invites
    ORDER BY created_at DESC
  ''');

  if (invites.isEmpty) {
    print('📭 No invitations found');
    return;
  }

  print('📋 Invitations:');
  print('');
  for (var i = 0; i < invites.length; i++) {
    final invite = invites[i];
    print('  ${i + 1}. ID: ${invite[0]}');
    print('     Sender: ${invite[1]}');
    print('     Recipient: ${invite[2]}');
    print('     Status: ${invite[3]}');
    print('     Created: ${invite[4]}');
    print('     Updated: ${invite[5]}');
    print('');
  }
}

void _printUsage() {
  print('''
Available commands:

  all      Delete all invitations from database
  count    Show total number of invitations
  list     List all invitations with details
  help     Show this help message

Examples:

  # Delete all invitations and start fresh
  dart run scripts/cleanup_invitations.dart all

  # Check how many invitations exist
  dart run scripts/cleanup_invitations.dart count

  # See details of all invitations
  dart run scripts/cleanup_invitations.dart list
''');
}
