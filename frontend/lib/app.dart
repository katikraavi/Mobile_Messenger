import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:frontend/core/services/api_client.dart';
import 'package:frontend/core/push_notifications/push_notification_handler.dart';
import 'package:frontend/features/auth/models/auth_models.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/screens/auth_flow_screen.dart';
import 'package:frontend/features/search/screens/search_screen.dart';
import 'package:frontend/features/profile/screens/profile_view_screen.dart';
import 'package:frontend/features/invitations/screens/invitations_screen.dart';
import 'package:frontend/features/invitations/providers/invites_provider.dart';
import 'package:frontend/features/chats/screens/chat_list_screen.dart';
import 'package:frontend/features/chats/providers/chat_cache_invalidator.dart';

/// Root widget for Mobile Messenger application
/// 
/// Responsible for:
/// - Setting up Material Design theme
/// - Configuring app navigation
/// - Handling backend connection status
/// - Displaying appropriate UI based on connection state

class MessengerApp extends StatefulWidget {
  const MessengerApp({super.key});

  @override
  State<MessengerApp> createState() => _MessengerAppState();
}

class _MessengerAppState extends State<MessengerApp> {
  bool _isConnected = false;
  bool _isInitializing = true;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initializeBackendConnection();
    _initializePushNotifications();
  }

  /// Initialize push notifications
  /// 
  /// Sets up Firebase Cloud Messaging to receive and handle push notifications
  Future<void> _initializePushNotifications() async {
    try {
      await PushNotificationHandler().initialize(navigatorKey: _navigatorKey);
      print('[App] Push notifications initialized');
    } catch (e) {
      print('[App Error] Failed to initialize push notifications: $e');
    }
  }

  /// Wait for backend connection to be established
  Future<void> _initializeBackendConnection() async {
    // Give the API client initialization from main() a moment to complete
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Initialize auth provider - restore session if token exists
    if (mounted) {
      await context.read<AuthProvider>().initialize();
    }
    
    setState(() {
      _isConnected = ApiClient.isConnected;
      _isInitializing = false;
    });

    print('[App] Backend connected: $_isConnected');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Mobile Messenger',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      routes: {
        '/invitations': (context) => const InvitationsScreen(),
      },
      home: _buildHome(),
    );
  }

  /// Build home screen based on connection status
  Widget _buildHome() {
    if (_isInitializing) {
      return const _LoadingScreen();
    }

    if (!_isConnected) {
      return const _ConnectionErrorScreen();
    }

    return const _HomeScreen();
  }
}

/// Loading screen shown while app initializes
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Initializing Mobile Messenger',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Connecting to backend...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Error screen shown if backend connection fails
class _ConnectionErrorScreen extends StatelessWidget {
  const _ConnectionErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Connection Failed',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Unable to connect to backend server. Please check that docker-compose is running and try restarting the app.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Restart app or retry connection
                print('[App] Retry clicked');
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home screen placeholder
class _HomeScreen extends riverpod.ConsumerStatefulWidget {
  const _HomeScreen();

  @override
  riverpod.ConsumerState<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends riverpod.ConsumerState<_HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        print('[HomeScreen] isAuthenticated: ${authProvider.isAuthenticated}, user: ${authProvider.user?.username}');
        
        // Show auth flow if not authenticated
        if (!authProvider.isAuthenticated) {
          return AuthFlowScreen(
            onAuthSuccess: () {
              print('[Auth] User logged in: ${authProvider.user?.username}');
              // Invalidate invite cache because a new user just logged in
              print('[Auth] Invalidating invite cache for new user');
              ref.read(invitesCacheInvalidatorProvider.notifier).state++;
              // Invalidate chat cache on login (T025)
              print('[Auth] Invalidating chat cache for new user');
              ref.read(chatsCacheInvalidatorProvider.notifier).state++;
            },
          );
        }

        // Show main app if authenticated
        return _AuthenticatedHomeScreen(
          user: authProvider.user!,
          authProvider: authProvider,
        );
      },
    );
  }
}

/// Authenticated home screen with bottom navigation
class _AuthenticatedHomeScreen extends riverpod.ConsumerStatefulWidget {
  final User user;
  final AuthProvider authProvider;

  const _AuthenticatedHomeScreen({
    required this.user,
    required this.authProvider,
  });

  @override
  riverpod.ConsumerState<_AuthenticatedHomeScreen> createState() => _AuthenticatedHomeScreenState();
}

class _AuthenticatedHomeScreenState extends riverpod.ConsumerState<_AuthenticatedHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Watch pending invites to show count badge
    final pendingInvites = ref.watch(pendingInvitesProvider);
    final pendingCount = pendingInvites.maybeWhen(
      data: (invites) => invites.length,
      orElse: () => 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: _selectedIndex == 0 
          ? const Text('Search Users')
          : _selectedIndex == 1
          ? const Text('Chats')
          : _selectedIndex == 2
          ? const Text('Invitations')
          : const Text('My Profile'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Clear auth state first, then invalidate invite cache
              await widget.authProvider.logout();
              // After logout completes, increment cache invalidator to clear any remaining data
              ref.read(invitesCacheInvalidatorProvider.notifier).state++;
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Search Tab
          _SearchTab(user: widget.user),
          
          // Chat List Tab (T024)
          const ChatListScreen(),
          
          // Invitations Tab
          const InvitationsScreen(),
          
          // Profile Tab - Show user's own profile with pre-loaded data
          ProfileViewScreen(
            userId: widget.user.userId,
            isOwnProfile: true,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text(pendingCount.toString()),
              child: const Icon(Icons.mail),
            ),
            label: 'Invitations',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

/// Search tab content
class _SearchTab extends StatelessWidget {
  final User user;

  const _SearchTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                'Welcome, ${user.username}!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                user.email,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              const Text(
                'Status: Connected',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Backend URL: ${ApiClient.getBaseUrl()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 32),
              
              // Main Search Button - PROMINENT
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SearchScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_search, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            'Search Users',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Test Info Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Ready to Chat!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Use the search feature to find other users and send them invitations to chat!',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
