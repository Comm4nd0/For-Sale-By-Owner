// Comprehensive Flutter widget tests for For Sale By Owner mobile app.
//
// These tests verify that all user-facing screens render correctly,
// contain the expected UI elements, and respond to user interaction.
// They use lightweight mock services to avoid real network calls.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:for_sale_by_owner/constants/app_theme.dart';
import 'package:for_sale_by_owner/services/auth_service.dart';
import 'package:for_sale_by_owner/services/api_service.dart';
import 'package:for_sale_by_owner/main.dart';
import 'package:for_sale_by_owner/screens/login_screen.dart';
import 'package:for_sale_by_owner/screens/register_screen.dart';
import 'package:for_sale_by_owner/screens/main_shell.dart';
import 'package:for_sale_by_owner/screens/dashboard_screen.dart';
import 'package:for_sale_by_owner/screens/tools_screen.dart';
import 'package:for_sale_by_owner/screens/account_screen.dart';
import 'package:for_sale_by_owner/screens/stamp_duty_screen.dart';
import 'package:for_sale_by_owner/screens/mortgage_calculator_screen.dart';
import 'package:for_sale_by_owner/models/chat_room.dart';
import 'package:for_sale_by_owner/models/notification_counts.dart';
import 'package:for_sale_by_owner/models/dashboard_stats.dart';
import 'package:for_sale_by_owner/models/offer.dart';
import 'package:for_sale_by_owner/models/paginated_response.dart';
import 'package:for_sale_by_owner/models/property.dart';
import 'package:for_sale_by_owner/models/user_profile.dart';
import 'package:for_sale_by_owner/models/viewing_request.dart';
import 'package:for_sale_by_owner/models/mortgage_calculation.dart';

// ─── Test helpers ──────────────────────────────────────────────────────

/// Minimal AuthService for testing - extends real AuthService but avoids
/// network calls. We can't easily mock it without mockito, so we use
/// a subclass that overrides key properties.
class TestAuthService extends ChangeNotifier implements AuthService {
  bool _isAuthenticated;
  String? _token;
  int? _userId;
  String? _email;
  String? _firstName;
  String? _lastName;
  bool _isLoading = false;

  TestAuthService({
    bool authenticated = false,
    String? email,
    String? firstName,
    String? lastName,
    int? userId,
  })  : _isAuthenticated = authenticated,
        _token = authenticated ? 'test-token' : null,
        _userId = userId ?? (authenticated ? 1 : null),
        _email = email ?? (authenticated ? 'test@example.com' : null),
        _firstName = firstName ?? (authenticated ? 'Test' : null),
        _lastName = lastName ?? (authenticated ? 'User' : null);

  @override
  String? get token => _token;
  @override
  int? get userId => _userId;
  @override
  String? get email => _email;
  @override
  String? get firstName => _firstName;
  @override
  String? get lastName => _lastName;
  @override
  bool get isAuthenticated => _isAuthenticated;
  @override
  bool get isStaff => false;
  @override
  String get userType => 'Buyer';
  @override
  bool get isLoading => _isLoading;

  @override
  void Function()? onAuthenticatedHook;
  @override
  void Function()? onLogoutHook;

  @override
  Future<void> init() async {}

  @override
  Future<LoginResult> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 50));
    _isLoading = false;
    // Simulate failure for tests
    notifyListeners();
    return LoginResult.invalidCredentials();
  }

  @override
  Future<LoginResult> completeTwoFactorLogin({
    required String challengeId,
    required String code,
  }) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 50));
    _isLoading = false;
    notifyListeners();
    return LoginResult.invalidCredentials();
  }

  @override
  Future<bool> register(String email, String firstName, String lastName,
      String password, String rePassword) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 50));
    _isLoading = false;
    notifyListeners();
    return false;
  }

  @override
  Future<void> logout() async {
    _token = null;
    _userId = null;
    _email = null;
    _firstName = null;
    _lastName = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}

/// Stub ApiService that returns canned data (or throws) without hitting the
/// network. Only the endpoints DashboardScreen / MainShell call are overridden;
/// the remaining methods inherit from ApiService and are never invoked in tests.
class FakeApiService extends ApiService {
  FakeApiService({
    this.shouldFail = false,
    DashboardStats? stats,
    NotificationCounts? counts,
    List<dynamic>? sales,
    List<ViewingRequest>? viewings,
    List<Offer>? offers,
    List<ChatRoom>? chatRooms,
  })  : stats = stats ??
            DashboardStats(
              totalListings: 5,
              activeListings: 3,
              totalViews: 42,
              totalMessages: 7,
              unreadMessages: 1,
              totalSaves: 10,
              pendingViewings: 2,
              totalOffers: 3,
              pendingOffers: 1,
              viewsByDay: const [],
              propertyStats: const [],
            ),
        counts = counts ??
            NotificationCounts(
              pendingViewings: 0,
              unreadMessages: 0,
              pendingOffers: 0,
            ),
        sales = sales ?? const [],
        viewings = viewings ?? const [],
        offers = offers ?? const [],
        chatRooms = chatRooms ?? const [],
        super(() => 'test-token');

  bool shouldFail;
  DashboardStats stats;
  NotificationCounts counts;
  List<dynamic> sales;
  List<ViewingRequest> viewings;
  List<Offer> offers;
  List<ChatRoom> chatRooms;

  /// When true, [getDashboardStats] throws to exercise the error-state path.
  /// The other endpoints continue to return canned data so the rest of the
  /// screen's FutureBuilders resolve cleanly and don't leak unhandled errors
  /// into the test zone.
  @override
  Future<DashboardStats> getDashboardStats() async {
    if (shouldFail) throw Exception('simulated failure');
    return stats;
  }

  @override
  Future<NotificationCounts> getNotificationCounts() async => counts;

  @override
  Future<List<dynamic>> getSales() async => sales;

  @override
  Future<PaginatedResponse<ViewingRequest>> getReceivedViewings(
          {int page = 1}) async =>
      PaginatedResponse<ViewingRequest>(
        count: viewings.length,
        results: viewings,
      );

  @override
  Future<List<Offer>> getOffers({bool? received}) async => offers;

  @override
  Future<List<ChatRoom>> getChatRooms() async => chatRooms;
}

/// Wraps a widget in MaterialApp + providers for testing.
Widget buildTestWidget({
  required Widget child,
  TestAuthService? authService,
  ApiService? apiService,
}) {
  final auth = authService ?? TestAuthService();
  final api = apiService ?? ApiService(() => auth.token);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>.value(value: auth),
      Provider<ApiService>.value(value: api),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    ),
  );
}

// ─── Login Screen Tests ────────────────────────────────────────────────

void main() {
  group('LoginScreen', () {
    testWidgets('renders email and password fields', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const LoginScreen(embedded: true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('renders register link', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const LoginScreen(embedded: true),
      ));
      await tester.pumpAndSettle();

      expect(find.text("Don't have an account? Register"), findsOneWidget);
    });

    testWidgets('shows validation errors on empty submit', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const LoginScreen(embedded: true),
      ));
      await tester.pumpAndSettle();

      // Tap Login without entering data
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // Should show 'Required' validation messages
      expect(find.text('Required'), findsWidgets);
    });

    testWidgets('can enter email and password', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const LoginScreen(embedded: true),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.pumpAndSettle();

      expect(find.text('user@test.com'), findsOneWidget);
      expect(find.text('password123'), findsOneWidget);
    });

    testWidgets('navigates to register screen', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const LoginScreen(embedded: true),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Don't have an account? Register"));
      await tester.pumpAndSettle();

      // RegisterScreen should now be shown
      expect(find.text('First Name'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('Login button disabled during loading', (tester) async {
      final auth = TestAuthService();
      await tester.pumpWidget(buildTestWidget(
        child: const LoginScreen(embedded: true),
        authService: auth,
      ));
      await tester.pumpAndSettle();

      // Enter valid data
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );

      // Tap login
      await tester.tap(find.text('Login'));
      await tester.pump();

      // During loading, should show CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Drain pending timers from the login future
      await tester.pump(const Duration(seconds: 1));
    });
  });

  // ─── Register Screen Tests ──────────────────────────────────────────

  group('RegisterScreen', () {
    testWidgets('renders all form fields', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const RegisterScreen(embedded: true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('First Name'), findsOneWidget);
      expect(find.text('Last Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('shows validation errors on empty submit', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const RegisterScreen(embedded: true),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsWidgets);
    });

    testWidgets('shows password length validation', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const RegisterScreen(embedded: true),
      ));
      await tester.pumpAndSettle();

      // Fill form with short password
      await tester.enterText(
        find.widgetWithText(TextFormField, 'First Name'),
        'John',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Last Name'),
        'Doe',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'john@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'short',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'short',
      );

      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.text('Min 8 characters'), findsOneWidget);
    });

    testWidgets('has login navigation link', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const RegisterScreen(embedded: true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Already have an account? Login'), findsOneWidget);
    });

    testWidgets('has terms and user agreement checkboxes', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const RegisterScreen(embedded: true),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNWidgets(2));
      expect(
        find.text('I agree to the Terms & Conditions and Privacy Policy.'),
        findsOneWidget,
      );
    });

    testWidgets('shows error when terms not agreed', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const RegisterScreen(embedded: true),
      ));
      await tester.pumpAndSettle();

      // Fill all fields with valid data
      await tester.enterText(
        find.widgetWithText(TextFormField, 'First Name'), 'John');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Last Name'), 'Doe');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'john@test.com');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'), 'password123');

      // Submit without checking checkboxes
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(
        find.text('You must agree to the Terms & Conditions and Privacy Policy.'),
        findsOneWidget,
      );
    });
  });

  // ─── MainShell Tests ──────────────────────────────────────────────

  group('MainShell', () {
    testWidgets('shows guest navigation tabs when not authenticated',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const MainShell(),
        authService: TestAuthService(authenticated: false),
      ));
      await tester.pump();

      // Guest tabs: Home, Tools, Services, Login
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Tools'), findsOneWidget);
      expect(find.text('Services'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);

      // Drain pending AutoRetry timers
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('shows authenticated navigation tabs and Dashboard item',
        (tester) async {
      final fake = FakeApiService();
      // firstName: '' keeps the Account label plain ("Account" rather than
      // "Account (<name>)") so the finder matches exactly once.
      await tester.pumpWidget(buildTestWidget(
        child: const MainShell(),
        authService: TestAuthService(authenticated: true, firstName: ''),
        apiService: fake,
      ));
      await tester.pump();

      // Authenticated tabs: Home, Dashboard, Tools, Services, Account
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Tools'), findsOneWidget);
      expect(find.text('Services'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);

      final navBar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(navBar.items.length, 5);
      // The shell starts on Home (index 0); Dashboard is at index 1.
      expect(navBar.currentIndex, 0);

      // Drain pending AutoRetry / 60s polling timers
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('has bottom navigation bar', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const MainShell(),
        authService: TestAuthService(authenticated: false),
      ));
      await tester.pump();

      expect(find.byType(BottomNavigationBar), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('bottom nav has 4 items', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const MainShell(),
        authService: TestAuthService(authenticated: false),
      ));
      await tester.pump();

      final navBar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(navBar.items.length, 4);

      await tester.pump(const Duration(seconds: 30));
    });
  });

  // ─── Dashboard Screen Tests ──────────────────────────────────────

  group('DashboardScreen', () {
    testWidgets('shows loading indicator then stats when API returns',
        (tester) async {
      final fake = FakeApiService(
        stats: DashboardStats(
          totalListings: 4,
          activeListings: 2,
          totalViews: 99,
          totalMessages: 6,
          unreadMessages: 0,
          totalSaves: 8,
          pendingViewings: 1,
          totalOffers: 0,
          pendingOffers: 0,
          viewsByDay: const [],
          propertyStats: const [],
        ),
      );

      await tester.pumpWidget(buildTestWidget(
        child: const DashboardScreen(),
        authService: TestAuthService(authenticated: true),
        apiService: fake,
      ));

      // First frame: stats still loading.
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Flush the microtasks created by Future.value-backed stubs.
      await tester.pump();
      await tester.pump();

      // Stats row is now rendered. 'Views' only appears in the stats section,
      // so it's a reliable marker that the success state has taken over.
      expect(find.text('Views'), findsOneWidget);
      expect(find.text('Listings'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      // The totalViews value from the fake should be displayed.
      expect(find.text('99'), findsOneWidget);

      // Drain any residual retry / polling timers before tearing down.
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('shows retry button when stats API fails', (tester) async {
      final fake = FakeApiService(shouldFail: true);

      await tester.pumpWidget(buildTestWidget(
        child: const DashboardScreen(),
        authService: TestAuthService(authenticated: true),
        apiService: fake,
      ));

      // Loading state is shown while retries are in flight.
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // AutoRetryMixin retries 3 times with 2s/4s/8s delays (14s total).
      // Pump past the last delay so the catch block can render the error UI.
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();

      expect(find.text('Retry loading stats'), findsOneWidget);
    });

    testWidgets('shows login required banner when unauthenticated',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const DashboardScreen(),
        authService: TestAuthService(authenticated: false),
        apiService: FakeApiService(),
      ));
      await tester.pump();

      expect(find.text('Login Required'), findsOneWidget);
      expect(find.text('Please log in to view your dashboard.'),
          findsOneWidget);
    });
  });

  // ─── Tools Screen Tests ──────────────────────────────────────────

  group('ToolsScreen', () {
    testWidgets('renders all tool cards', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const ToolsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Property Tools'), findsOneWidget);
      expect(find.text('Mortgage Calculator'), findsOneWidget);
      expect(find.text('House Price Lookup'), findsOneWidget);
      expect(find.text('Price Comparison'), findsOneWidget);
      expect(find.text('Stamp Duty Calculator'), findsOneWidget);
      // Last card sits below the default 800x600 test viewport and the
      // ListView's cacheExtent, so it isn't built until we scroll to it.
      await tester.scrollUntilVisible(
        find.text('Neighbourhood Reviews'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Neighbourhood Reviews'), findsOneWidget);
    });

    testWidgets('shows descriptive subtitle text', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const ToolsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('Free tools to help you buy or sell your property.'),
        findsOneWidget,
      );
    });

    testWidgets('tool cards are tappable', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const ToolsScreen(),
      ));
      await tester.pumpAndSettle();

      // Tap Mortgage Calculator should navigate
      await tester.tap(find.text('Mortgage Calculator'));
      await tester.pumpAndSettle();

      // Should see the mortgage calculator screen
      expect(find.text('Property Price (£)'), findsOneWidget);
    });

    testWidgets('stamp duty tool navigates correctly', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const ToolsScreen(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stamp Duty Calculator'));
      await tester.pumpAndSettle();

      // Should see the stamp duty screen
      expect(find.text('Property Price'), findsOneWidget);
      expect(find.text('First-Time Buyer'), findsOneWidget);
    });
  });

  // ─── Account Screen Tests ────────────────────────────────────────

  group('AccountScreen', () {
    testWidgets('shows login required when not authenticated', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const AccountScreen(),
        authService: TestAuthService(authenticated: false),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Login Required'), findsOneWidget);
      expect(
        find.text('Please log in to access your account.'),
        findsOneWidget,
      );
    });

    testWidgets('shows menu sections when authenticated', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const AccountScreen(),
        authService: TestAuthService(authenticated: true, firstName: 'John'),
      ));
      // Just pump once (no pumpAndSettle since it makes API calls)
      await tester.pump();

      // Section titles
      expect(find.text('Buyer Tools'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('shows buyer tools', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const AccountScreen(),
        authService: TestAuthService(authenticated: true),
      ));
      await tester.pump();

      expect(find.text('Buyer Profile'), findsOneWidget);
      expect(find.text('Buyer Verification'), findsOneWidget);
    });

    testWidgets('shows settings menu', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const AccountScreen(),
        authService: TestAuthService(authenticated: true),
      ));
      await tester.pump();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Two-Factor Authentication'), findsOneWidget);
    });

    testWidgets('has logout button', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const AccountScreen(),
        authService: TestAuthService(authenticated: true),
      ));
      await tester.pump();

      expect(find.text('Logout'), findsOneWidget);
    });
  });

  // ─── Mortgage Calculator Screen Tests ────────────────────────────

  group('MortgageCalculatorScreen', () {
    testWidgets('renders all input fields', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const MortgageCalculatorScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Mortgage Calculator'), findsOneWidget);
      expect(find.text('Property Price (£)'), findsOneWidget);
      expect(find.text('Deposit (%)'), findsOneWidget);
      expect(find.text('Interest Rate (%)'), findsOneWidget);
      expect(find.text('Term (years)'), findsOneWidget);
      expect(find.text('Calculate'), findsOneWidget);
    });

    testWidgets('has default values for deposit, rate, and term',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const MortgageCalculatorScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('10'), findsOneWidget); // deposit
      expect(find.text('4.5'), findsOneWidget); // rate
      expect(find.text('25'), findsOneWidget); // term
    });

    testWidgets('pre-fills price when provided', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const MortgageCalculatorScreen(propertyPrice: 250000),
      ));
      await tester.pumpAndSettle();

      expect(find.text('250000'), findsOneWidget);
    });

    testWidgets('shows validation error on empty price', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const MortgageCalculatorScreen(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOneWidget);
    });
  });

  // ─── Stamp Duty Screen Tests ─────────────────────────────────────

  group('StampDutyScreen', () {
    testWidgets('renders form fields', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const StampDutyScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Property Price'), findsOneWidget);
      expect(find.text('Country'), findsOneWidget);
      expect(find.text('England'), findsOneWidget);
      expect(find.text('Scotland'), findsOneWidget);
      expect(find.text('Wales'), findsOneWidget);
      expect(find.text('First-Time Buyer'), findsOneWidget);
      expect(find.text('Additional Property'), findsOneWidget);
      expect(find.text('Calculate'), findsOneWidget);
    });

    testWidgets('has country segmented button', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const StampDutyScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<String>), findsOneWidget);
    });

    testWidgets('has toggle switches', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const StampDutyScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsNWidgets(2));
    });

    testWidgets('shows validation on empty submit', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const StampDutyScreen(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a property price'), findsOneWidget);
    });

    testWidgets('can toggle first-time buyer switch', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const StampDutyScreen(),
      ));
      await tester.pumpAndSettle();

      // Initially off
      final switchTile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'First-Time Buyer'),
      );
      expect(switchTile.value, false);

      // Toggle it
      await tester.tap(find.text('First-Time Buyer'));
      await tester.pumpAndSettle();

      final updatedSwitch = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'First-Time Buyer'),
      );
      expect(updatedSwitch.value, true);
    });
  });

  // ─── App Theme Tests ─────────────────────────────────────────────

  group('AppTheme', () {
    test('lightTheme is not null', () {
      expect(AppTheme.lightTheme, isNotNull);
    });

    test('lightTheme uses Material3', () {
      expect(AppTheme.lightTheme.useMaterial3, isTrue);
    });

    test('primary colors are defined', () {
      expect(AppTheme.forestDeep, isNotNull);
      expect(AppTheme.forestMid, isNotNull);
      expect(AppTheme.forestLight, isNotNull);
      expect(AppTheme.forestMist, isNotNull);
    });

    test('semantic colors are defined', () {
      expect(AppTheme.success, isNotNull);
      expect(AppTheme.warning, isNotNull);
      expect(AppTheme.error, isNotNull);
      expect(AppTheme.info, isNotNull);
    });
  });

  // ─── FSBOApp Tests ───────────────────────────────────────────────

  group('FSBOApp', () {
    testWidgets('builds without errors', (tester) async {
      final auth = TestAuthService(authenticated: false);
      await tester.pumpWidget(FSBOApp(authService: auth));
      await tester.pump();

      expect(find.byType(MaterialApp), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('has correct title', (tester) async {
      final auth = TestAuthService(authenticated: false);
      await tester.pumpWidget(FSBOApp(authService: auth));
      await tester.pump();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.title, 'For Sale By Owner');

      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('provides AuthService and ApiService', (tester) async {
      final auth = TestAuthService(authenticated: false);
      await tester.pumpWidget(FSBOApp(authService: auth));
      await tester.pump();

      // The providers should be available in the widget tree
      expect(find.byType(MultiProvider), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('has MainShell as home', (tester) async {
      final auth = TestAuthService(authenticated: false);
      await tester.pumpWidget(FSBOApp(authService: auth));
      await tester.pump();

      expect(find.byType(MainShell), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
    });
  });

  // ─── BrandedAppBar / AppBarLogo Tests ────────────────────────────

  group('BrandedAppBar', () {
    testWidgets('shows For Sale branding text', (tester) async {
      // Use LoginScreen which includes BrandedAppBar
      await tester.pumpWidget(buildTestWidget(
        child: const LoginScreen(embedded: true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('For Sale'), findsOneWidget);
      expect(find.text('BY OWNER'), findsOneWidget);
    });
  });

  // ─── Model Tests ─────────────────────────────────────────────────

  group('NotificationCounts', () {
    test('fromJson creates correct instance', () {
      final counts =
          NotificationCounts.fromJson({'pending_viewings': 3, 'unread_messages': 5, 'pending_offers': 2});
      expect(counts.pendingViewings, 3);
      expect(counts.unreadMessages, 5);
      expect(counts.pendingOffers, 2);
      expect(counts.total, 10);
    });

    test('fromJson handles missing fields', () {
      final counts = NotificationCounts.fromJson({});
      expect(counts.pendingViewings, 0);
      expect(counts.unreadMessages, 0);
      expect(counts.pendingOffers, 0);
      expect(counts.total, 0);
    });
  });

  group('DashboardStats', () {
    test('fromJson creates correct instance', () {
      final stats = DashboardStats.fromJson({
        'total_listings': 5,
        'active_listings': 3,
        'total_views': 100,
        'total_messages': 20,
        'unread_messages': 5,
        'total_saves': 10,
        'pending_viewings': 2,
        'total_offers': 3,
        'pending_offers': 1,
        'views_by_day': [],
        'property_stats': [],
      });
      expect(stats.totalListings, 5);
      expect(stats.activeListings, 3);
      expect(stats.totalViews, 100);
      expect(stats.unreadMessages, 5);
    });

    test('fromJson handles empty json', () {
      final stats = DashboardStats.fromJson({});
      expect(stats.totalListings, 0);
      expect(stats.activeListings, 0);
      expect(stats.viewsByDay, isEmpty);
      expect(stats.propertyStats, isEmpty);
    });
  });

  group('Property model', () {
    test('fromJson creates property with all fields', () {
      final property = Property.fromJson({
        'id': 1,
        'owner': 1,
        'title': 'Test Property',
        'slug': 'test-property',
        'description': 'A lovely home',
        'property_type': 'detached',
        'property_type_display': 'Detached',
        'status': 'active',
        'status_display': 'Active',
        'price': '250000.00',
        'address_line_1': '123 Test St',
        'address_line_2': '',
        'city': 'London',
        'county': 'Greater London',
        'postcode': 'SW1A 1AA',
        'bedrooms': 3,
        'bathrooms': 2,
        'reception_rooms': 1,
        'epc_rating': 'C',
        'epc_rating_display': 'C',
        'images': [],
        'feature_list': [],
        'floorplans': [],
        'price_history': [],
        'owner_name': 'John Doe',
        'owner_is_verified': true,
        'is_saved': false,
        'image_count': 5,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      });

      expect(property.id, 1);
      expect(property.title, 'Test Property');
      expect(property.price, 250000.0);
      expect(property.bedrooms, 3);
      expect(property.city, 'London');
      expect(property.ownerIsVerified, true);
    });

    test('formattedPrice returns comma-separated value', () {
      final property = Property.fromJson({
        'id': 1,
        'price': '1250000.00',
        'title': '',
        'slug': '',
        'description': '',
        'property_type': '',
        'property_type_display': '',
        'status': '',
        'status_display': '',
        'address_line_1': '',
        'address_line_2': '',
        'city': '',
        'county': '',
        'postcode': '',
        'bedrooms': 0,
        'bathrooms': 0,
        'reception_rooms': 0,
        'epc_rating': '',
        'epc_rating_display': '',
        'images': [],
        'feature_list': [],
        'floorplans': [],
        'price_history': [],
        'owner_name': '',
        'owner_is_verified': false,
        'is_saved': false,
        'image_count': 0,
        'created_at': '',
        'updated_at': '',
      });

      expect(property.formattedPrice, '£1,250,000');
    });

    test('toJson returns expected map', () {
      final property = Property.fromJson({
        'id': 1,
        'owner': 1,
        'title': 'My Home',
        'slug': 'my-home',
        'description': 'Nice',
        'property_type': 'flat',
        'property_type_display': 'Flat',
        'status': 'active',
        'status_display': 'Active',
        'price': '300000',
        'address_line_1': '1 Main St',
        'address_line_2': '',
        'city': 'Manchester',
        'county': 'Greater Manchester',
        'postcode': 'M1 1AA',
        'bedrooms': 2,
        'bathrooms': 1,
        'reception_rooms': 1,
        'epc_rating': 'B',
        'epc_rating_display': 'B',
        'images': [],
        'feature_list': [],
        'floorplans': [],
        'price_history': [],
        'owner_name': '',
        'owner_is_verified': false,
        'is_saved': false,
        'image_count': 0,
        'created_at': '',
        'updated_at': '',
      });

      final json = property.toJson();
      expect(json['title'], 'My Home');
      expect(json['property_type'], 'flat');
      expect(json['bedrooms'], 2);
      expect(json['city'], 'Manchester');
    });
  });

  group('UserProfile model', () {
    test('fromJson creates profile', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'email': 'test@example.com',
        'first_name': 'John',
        'last_name': 'Doe',
        'phone': '07700900000',
        'dark_mode': false,
        'notification_enquiries': true,
        'notification_viewings': true,
        'notification_price_drops': false,
        'notification_saved_searches': true,
      });

      expect(profile.id, 1);
      expect(profile.email, 'test@example.com');
      expect(profile.firstName, 'John');
      expect(profile.phone, '07700900000');
      expect(profile.notificationPriceDrops, false);
    });
  });

  // ─── Widget Interaction Tests ────────────────────────────────────

  group('Navigation flow tests', () {
    testWidgets('guest user sees login tab in bottom nav', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const MainShell(),
        authService: TestAuthService(authenticated: false),
      ));
      await tester.pump();

      // Tap Login tab
      await tester.tap(find.text('Login'));
      await tester.pump();

      // Login screen content should be visible
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('guest user can navigate to Tools tab', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const MainShell(),
        authService: TestAuthService(authenticated: false),
      ));
      await tester.pump();

      // Tap Tools tab
      await tester.tap(find.text('Tools'));
      await tester.pump();

      expect(find.text('Property Tools'), findsOneWidget);
      expect(find.text('Mortgage Calculator'), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
    });
  });

  // ─── Auth Service Unit Tests ─────────────────────────────────────

  group('TestAuthService', () {
    test('unauthenticated state', () {
      final auth = TestAuthService(authenticated: false);
      expect(auth.isAuthenticated, false);
      expect(auth.token, isNull);
      expect(auth.userId, isNull);
      expect(auth.email, isNull);
    });

    test('authenticated state', () {
      final auth = TestAuthService(
        authenticated: true,
        email: 'user@test.com',
        firstName: 'Jane',
        lastName: 'Smith',
        userId: 42,
      );
      expect(auth.isAuthenticated, true);
      expect(auth.token, 'test-token');
      expect(auth.userId, 42);
      expect(auth.email, 'user@test.com');
      expect(auth.firstName, 'Jane');
      expect(auth.lastName, 'Smith');
    });

    test('logout clears state', () async {
      final auth = TestAuthService(authenticated: true);
      expect(auth.isAuthenticated, true);

      await auth.logout();

      expect(auth.isAuthenticated, false);
      expect(auth.token, isNull);
      expect(auth.userId, isNull);
    });
  });

  // ─── Additional Model Tests ──────────────────────────────────────

  group('MortgageCalculation model', () {
    test('fromJson creates calculation', () {
      final calc = MortgageCalculation.fromJson({
        'price': 250000.0,
        'deposit': 25000.0,
        'loan_amount': 225000.0,
        'interest_rate': 4.5,
        'term_years': 25,
        'monthly_payment': 1234.56,
        'total_cost': 370368.0,
        'total_interest': 145368.0,
        'stamp_duty': 2500.0,
      });

      expect(calc.propertyPrice, 250000.0);
      expect(calc.deposit, 25000.0);
      expect(calc.monthlyPayment, 1234.56);
      expect(calc.loanAmount, 225000.0);
      expect(calc.totalRepayment, 370368.0);
      expect(calc.totalInterest, 145368.0);
      expect(calc.stampDuty, 2500.0);
    });

    test('fromJson handles null values with defaults', () {
      final calc = MortgageCalculation.fromJson({});
      expect(calc.propertyPrice, 0);
      expect(calc.monthlyPayment, 0);
      expect(calc.termYears, 25);
    });
  });
}
