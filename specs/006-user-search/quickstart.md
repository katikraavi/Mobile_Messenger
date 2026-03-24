# Quick Start: User Search Implementation

**Date**: 2026-03-12 | **Spec**: [006-user-search](spec.md)

This guide provides code templates and patterns for implementing the User Search feature.

## Backend Implementation Patterns

### Phase 1: Database Migration

**File**: `backend/migrations/013_add_search_indexes.dart`

```dart
import 'package:shelf_plus/shelf_plus.dart';

Future<void> migration(Database database) async {
  // Create case-insensitive indexes for search
  await database.query('''
    CREATE INDEX IF NOT EXISTS idx_user_username_lower 
    ON "user"(LOWER(username));
  ''');
  
  await database.query('''
    CREATE INDEX IF NOT EXISTS idx_user_email_lower 
    ON "user"(LOWER(email));
  ''');
  
  await database.query('''
    CREATE INDEX IF NOT EXISTS idx_user_is_verified 
    ON "user"(is_verified);
  ''');
}
```

### Phase 2A: UserSearchResult Model

**File**: `backend/lib/src/models/user_search_result.dart`

```dart
class UserSearchResult {
  final String userId;
  final String username;
  final String email;
  final String? profilePictureUrl;
  final bool isPrivateProfile;

  UserSearchResult({
    required this.userId,
    required this.username,
    required this.email,
    this.profilePictureUrl,
    required this.isPrivateProfile,
  });

  // Serialize to JSON for API response
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'username': username,
    'email': email,
    'profilePictureUrl': profilePictureUrl,
    'isPrivateProfile': isPrivateProfile,
  };

  // Deserialize from database query
  factory UserSearchResult.fromRow(Map<String, dynamic> row) {
    return UserSearchResult(
      userId: row['id'] as String,
      username: row['username'] as String,
      email: row['email'] as String,
      profilePictureUrl: row['profile_picture_url'] as String?,
      isPrivateProfile: row['is_private_profile'] as bool? ?? false,
    );
  }
}
```

### Phase 2B: SearchService

**File**: `backend/lib/src/services/search_service.dart`

```dart
import 'package:postgres/postgres.dart';

class SearchValidationException implements Exception {
  final String message;
  SearchValidationException(this.message);

  @override
  String toString() => message;
}

class SearchService {
  final Connection database;

  SearchService(this.database);

  // Validate username query
  void validateUsername(String query) {
    if (query.isEmpty || query.length > 100) {
      throw SearchValidationException('Query must be between 1 and 100 characters');
    }
    // Allow alphanumeric, underscore, dash only
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(query)) {
      throw SearchValidationException('Username can only contain letters, numbers, underscore, and dash');
    }
  }

  // Validate email query
  void validateEmail(String query) {
    if (query.isEmpty || query.length > 100) {
      throw SearchValidationException('Query must be between 1 and 100 characters');
    }
    if (query.length < 3) {
      throw SearchValidationException('Email query must be at least 3 characters');
    }
    if (!query.contains('@')) {
      throw SearchValidationException('Invalid email format');
    }
  }

  // Search by username
  Future<List<UserSearchResult>> searchByUsername(String query, int maxResults) async {
    try {
      validateUsername(query);
    } catch (e) {
      // Return empty list for invalid queries (no error differentiation)
      return [];
    }

    try {
      final results = await database.query(
        '''
        SELECT id, username, email, profile_picture_url, is_private_profile 
        FROM "user" 
        WHERE LOWER(username) LIKE LOWER(\$1) AND is_verified = true 
        ORDER BY username ASC 
        LIMIT \$2
        ''',
        parameters: ['$query%', maxResults],
      );

      return results
          .map((row) => UserSearchResult.fromRow(row.toColumnMap()))
          .toList();
    } catch (e) {
      print('Search error: $e');
      return []; // Return empty list on DB error
    }
  }

  // Search by email
  Future<List<UserSearchResult>> searchByEmail(String query, int maxResults) async {
    try {
      validateEmail(query);
    } catch (e) {
      // Return empty list for invalid queries
      return [];
    }

    try {
      final results = await database.query(
        '''
        SELECT id, username, email, profile_picture_url, is_private_profile 
        FROM "user" 
        WHERE LOWER(email) LIKE LOWER(\$1) AND is_verified = true 
        ORDER BY CASE WHEN LOWER(email) = LOWER(\$2) THEN 0 ELSE 1 END, email ASC 
        LIMIT \$3
        ''',
        parameters: ['$query%', query, maxResults],
      );

      return results
          .map((row) => UserSearchResult.fromRow(row.toColumnMap()))
          .toList();
    } catch (e) {
      print('Search error: $e');
      return [];
    }
  }
}
```

### Phase 2C: API Endpoints

**File**: `backend/lib/src/endpoints/search_handler.dart`

```dart
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/search_service.dart';

class SearchHandler {
  final SearchService searchService;

  SearchHandler(this.searchService);

  Router get router => Router()
    ..get('/search/username', _searchUsername)
    ..get('/search/email', _searchEmail);

  // GET /search/username?q=query&limit=10
  Future<Response> _searchUsername(Request request) async {
    // Verify authentication (middleware should handle)
    final userId = request.context['userId'];
    if (userId == null) {
      return Response.unauthorized();
    }

    // Get query parameters
    final query = request.url.queryParameters['q'];
    final limitStr = request.url.queryParameters['limit'] ?? '10';

    if (query == null || query.isEmpty) {
      return Response.badRequest(
        body: '{"error": "Missing required query parameter: q"}',
        headers: {'Content-Type': 'application/json'},
      );
    }

    final limit = int.tryParse(limitStr) ?? 10;
    if (limit < 1 || limit > 100) {
      return Response.badRequest(
        body: '{"error": "Limit must be between 1 and 100"}',
        headers: {'Content-Type': 'application/json'},
      );
    }

    try {
      final results = await searchService.searchByUsername(query, limit);
      final json = jsonEncode(results.map((r) => r.toJson()).toList());
      return Response.ok(
        json,
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: '{"error": "Unable to process search"}',
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // GET /search/email?q=query&limit=10
  Future<Response> _searchEmail(Request request) async {
    // Verify authentication
    final userId = request.context['userId'];
    if (userId == null) {
      return Response.unauthorized();
    }

    // Get query parameters
    final query = request.url.queryParameters['q'];
    final limitStr = request.url.queryParameters['limit'] ?? '10';

    if (query == null || query.isEmpty) {
      return Response.badRequest(
        body: '{"error": "Missing required query parameter: q"}',
        headers: {'Content-Type': 'application/json'},
      );
    }

    final limit = int.tryParse(limitStr) ?? 10;
    if (limit < 1 || limit > 100) {
      return Response.badRequest(
        body: '{"error": "Limit must be between 1 and 100"}',
        headers: {'Content-Type': 'application/json'},
      );
    }

    try {
      final results = await searchService.searchByEmail(query, limit);
      final json = jsonEncode(results.map((r) => r.toJson()).toList());
      return Response.ok(
        json,
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: '{"error": "Unable to process search"}',
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
```

### Phase 2D: Register in Server

**File**: `backend/lib/src/server.dart` (excerpt)

```dart
final app = Router();

// ... existing routes ...

// Add search endpoints with auth middleware
final searchHandler = SearchHandler(searchService);
app.mount('/search', _authMiddleware(searchHandler.router));

// Auth middleware function
Middleware _authMiddleware(Handler innerHandler) {
  return (Request request) async {
    final token = request.headers['authorization']?.replaceFirst('Bearer ', '');
    if (token == null || token.isEmpty) {
      return Response.unauthorized();
    }
    
    try {
      final userId = verifyJWT(token); // Your JWT verification
      return await innerHandler(
        request.change(context: {'userId': userId}),
      );
    } catch (e) {
      return Response.unauthorized();
    }
  };
}
```

## Frontend Implementation Patterns

### Phase 3A: Riverpod Providers

**File**: `frontend/lib/features/search/providers/search_results_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/search_service.dart';
import '../models/user_search_result.dart';

final searchServiceProvider = Provider((ref) => SearchService());

final searchResultsProvider = FutureProvider.family<
    List<UserSearchResult>,
    ({String query, String searchType, int limit})
>((ref, params) async {
  final service = ref.watch(searchServiceProvider);
  
  if (params.query.isEmpty) {
    return [];
  }

  try {
    if (params.searchType == 'email') {
      return await service.searchByEmail(params.query, params.limit);
    } else {
      return await service.searchByUsername(params.query, params.limit);
    }
  } catch (e) {
    return []; // Return empty list on error
  }
});
```

**File**: `frontend/lib/features/search/providers/search_form_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchFormState {
  final String query;
  final String searchType; // 'username' or 'email'
  final bool isSearching;

  SearchFormState({
    this.query = '',
    this.searchType = 'username',
    this.isSearching = false,
  });

  SearchFormState copyWith({
    String? query,
    String? searchType,
    bool? isSearching,
  }) {
    return SearchFormState(
      query: query ?? this.query,
      searchType: searchType ?? this.searchType,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

final searchFormProvider =
    StateNotifierProvider<SearchFormNotifier, SearchFormState>((ref) {
  return SearchFormNotifier();
});

class SearchFormNotifier extends StateNotifier<SearchFormState> {
  SearchFormNotifier() : super(SearchFormState());

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setSearchType(String type) {
    state = state.copyWith(searchType: type, query: '');
  }

  void setIsSearching(bool isSearching) {
    state = state.copyWith(isSearching: isSearching);
  }
}
```

### Phase 3B: Frontend Search Service

**File**: `frontend/lib/features/search/services/search_service.dart`

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_search_result.dart';

class SearchService {
  final String baseUrl = 'http://localhost:8081';
  final String token; // From auth store

  SearchService(this.token);

  Future<List<UserSearchResult>> searchByUsername(
    String query, {
    int limit = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/search/username?q=$query&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonList = jsonDecode(response.body) as List;
        return jsonList
            .map((json) => UserSearchResult.fromJson(json))
            .toList();
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        return [];
      } else {
        throw Exception('Failed to search');
      }
    } catch (e) {
      return [];
    }
  }

  Future<List<UserSearchResult>> searchByEmail(
    String query, {
    int limit = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/search/email?q=$query&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonList = jsonDecode(response.body) as List;
        return jsonList
            .map((json) => UserSearchResult.fromJson(json))
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}
```

### Phase 3C: Search Bar Widget with Debounce

**File**: `frontend/lib/features/search/widgets/search_bar_widget.dart`

```dart
import 'package:flutter/material.dart';
import 'dart:async';

class SearchBarWidget extends StatefulWidget {
  final Function(String) onQueryChanged;
  final Function() onSearch;
  final String searchType;
  final Function(String) onSearchTypeChanged;

  const SearchBarWidget({
    required this.onQueryChanged,
    required this.onSearch,
    required this.searchType,
    required this.onSearchTypeChanged,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Start new debounce timer (500ms)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      widget.onQueryChanged(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search type toggle (Username / Email)
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => widget.onSearchTypeChanged('username'),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: widget.searchType == 'username'
                            ? Colors.blue
                            : Colors.grey,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    'Username',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => widget.onSearchTypeChanged('email'),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: widget.searchType == 'email'
                            ? Colors.blue
                            : Colors.grey,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    'Email',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        // Search input field
        TextField(
          controller: _controller,
          onChanged: _onTextChanged,
          decoration: InputDecoration(
            hintText: 'Search ${widget.searchType == 'email' ? 'by email' : 'by username'}',
            prefixIcon: Icon(Icons.search),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      widget.onQueryChanged('');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
```

### Phase 3D: Search Result List Widget

**File**: `frontend/lib/features/search/widgets/search_result_list_widget.dart`

```dart
import 'package:flutter/material.dart';
import '../models/user_search_result.dart';

class SearchResultListWidget extends StatelessWidget {
  final List<UserSearchResult> results;
  final bool isLoading;
  final Function(String) onTap;

  const SearchResultListWidget({
    required this.results,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) => _buildShimmer(),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Text('No results found'),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _buildResultItem(context, result);
      },
    );
  }

  Widget _buildShimmer() {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[300],
      ),
      title: Container(
        height: 16,
        color: Colors.grey[300],
      ),
      subtitle: Container(
        height: 14,
        color: Colors.grey[300],
      ),
    );
  }

  Widget _buildResultItem(BuildContext context, UserSearchResult result) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: result.profilePictureUrl != null
            ? NetworkImage(result.profilePictureUrl!)
            : null,
        child: result.profilePictureUrl == null
            ? Icon(Icons.person)
            : null,
      ),
      title: Text(result.username),
      subtitle: Text(result.email),
      onTap: () => onTap(result.userId),
    );
  }
}
```

### Phase 3E: Search Screen

**File**: `frontend/lib/features/search/screens/search_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_form_provider.dart';
import '../providers/search_results_provider.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/search_result_list_widget.dart';

class SearchScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(searchFormProvider);
    final searchResults = ref.watch(
      searchResultsProvider(
        (
          query: formState.query,
          searchType: formState.searchType,
          limit: 20,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Find Users'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Search bar with toggle
            SearchBarWidget(
              onQueryChanged: (query) {
                ref.read(searchFormProvider.notifier).setQuery(query);
              },
              onSearch: () {
                // Manual search trigger if needed
              },
              searchType: formState.searchType,
              onSearchTypeChanged: (type) {
                ref.read(searchFormProvider.notifier).setSearchType(type);
              },
            ),
            SizedBox(height: 16),
            // Results list
            Expanded(
              child: searchResults.when(
                data: (results) => SearchResultListWidget(
                  results: results,
                  isLoading: false,
                  onTap: (userId) {
                    // Navigate to profile
                    context.push('/profile/$userId');
                  },
                ),
                loading: () => SearchResultListWidget(
                  results: [],
                  isLoading: true,
                  onTap: (_) {},
                ),
                error: (err, stack) => Center(
                  child: Text('Error: $err'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Testing Templates

### Backend Unit Test

**File**: `backend/test/unit/search_query_validation_test.dart`

```dart
import 'package:test/test.dart';
import '../../lib/src/services/search_service.dart';

void main() {
  late SearchService searchService;

  setUp(() {
    // Mock database connection
    searchService = SearchService(mockDatabase);
  });

  group('Username Validation', () {
    test('accepts valid username', () {
      expect(() => searchService.validateUsername('alice'), returnsNormally);
    });

    test('rejects empty query', () {
      expect(
        () => searchService.validateUsername(''),
        throwsA(isA<SearchValidationException>()),
      );
    });

    test('rejects query > 100 chars', () {
      expect(
        () => searchService.validateUsername('a' * 101),
        throwsA(isA<SearchValidationException>()),
      );
    });

    test('rejects special characters', () {
      expect(
        () => searchService.validateUsername('alice<>'),
        throwsA(isA<SearchValidationException>()),
      );
    });
  });

  group('Email Validation', () {
    test('accepts valid email', () {
      expect(() => searchService.validateEmail('alice@'), returnsNormally);
    });

    test('rejects query without @', () {
      expect(
        () => searchService.validateEmail('alice'),
        throwsA(isA<SearchValidationException>()),
      );
    });

    test('rejects query < 3 chars', () {
      expect(
        () => searchService.validateEmail('a@'),
        throwsA(isA<SearchValidationException>()),
      );
    });
  });
}
```

### Frontend Widget Test

**File**: `frontend/test/features/search/widgets/search_bar_widget_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SearchBarWidget renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchBarWidget(
            onQueryChanged: (_) {},
            onSearch: () {},
            searchType: 'username',
            onSearchTypeChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('Debounce works correctly', (WidgetTester tester) async {
    int callCount = 0;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchBarWidget(
            onQueryChanged: (_) => callCount++,
            onSearch: () {},
            searchType: 'username',
            onSearchTypeChanged: (_) {},
          ),
        ),
      ),
    );

    // Type quickly
    await tester.enterText(find.byType(TextField), 'ali');
    await tester.pump(); // Trigger frame
    await tester.pump(Duration(milliseconds: 250)); // Half debounce
    
    expect(callCount, 0);

    // Wait for debounce to complete
    await tester.pump(Duration(milliseconds: 300));
    
    expect(callCount, 1);
  });
}
```

## Integration Testing with cURL

```bash
# Test 1: Username search
curl -X GET "http://localhost:8081/search/username?q=alice&limit=10" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Test 2: Email search
curl -X GET "http://localhost:8081/search/email?q=alice@&limit=10" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Test 3: Case-insensitive
curl -X GET "http://localhost:8081/search/username?q=ALICE&limit=10" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Test 4: Performance with timing
time curl -X GET "http://localhost:8081/search/username?q=alice" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```
