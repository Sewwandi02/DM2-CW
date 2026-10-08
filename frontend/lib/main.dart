import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

void main() {
  runApp(const SmartMoveApp());
}

class SmartMoveApp extends StatefulWidget {
  const SmartMoveApp({super.key});

  @override
  State<SmartMoveApp> createState() => _SmartMoveAppState();
}

class _SmartMoveAppState extends State<SmartMoveApp> {
  final SmartMoveApi api = SmartMoveApi();
  int selectedPage = 0;
  int connectionVersion = 0;

  Future<void> _logout() async {
    String? error;
    try {
      await api.request('/api/auth/logout', method: 'POST');
    } catch (exception) {
      error = exception.toString();
    }
    if (!mounted) return;
    setState(() {
      api.adminToken = null;
      selectedPage = 0;
      connectionVersion++;
    });
    if (error != null) {
      _showMessage(context, 'Signed out on this device. $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartMove',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff176b5b),
          surface: const Color(0xffffffff),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff3f6f5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xff172b27),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 72,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xffe5ece9)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xfffbfcfc),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xffdce5e1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xffdce5e1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xff176b5b), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0xffdcefe9),
          elevation: 0,
          height: 72,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 24,
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xff176b5b),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_bus_filled,
                    color: Colors.white, size: 23),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SmartMove',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(
                    'TRANSPORT SOLUTIONS',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        color: Color(0xff71817c)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (MediaQuery.sizeOf(context).width >= 600)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Center(
                  child: Chip(
                    avatar:
                        Icon(Icons.circle, size: 9, color: Color(0xff27876d)),
                    label: Text('LOCAL WORKSPACE'),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                    backgroundColor: Color(0xffedf6f2),
                    labelStyle: TextStyle(
                      color: Color(0xff315c4f),
                      fontSize: 10,
                      letterSpacing: .7,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'API connection',
              onPressed: _editApiAddress,
              icon: const Icon(Icons.settings_ethernet),
            ),
            if (api.adminToken != null)
              IconButton(
                tooltip: 'Sign out',
                onPressed: _logout,
                icon: const Icon(Icons.logout),
              ),
            const SizedBox(width: 12),
          ],
        ),
        body: api.adminToken == null
            ? AdminLoginPage(
                key: ValueKey('admin-login-$connectionVersion'),
                api: api,
                onSignedIn: () {
                  setState(() {
                    selectedPage = 0;
                    connectionVersion++;
                  });
                },
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1000;
                  final pages = [
                    DashboardPage(
                        key: ValueKey('dashboard-$connectionVersion'),
                        api: api),
                    OperationsPage(
                        key: ValueKey('operations-$connectionVersion'),
                        api: api),
                    MongoPage(
                      key: ValueKey('mongo-$connectionVersion'),
                      api: api,
                      isActive: selectedPage == 2,
                    ),
                    ReportsPage(
                        key: ValueKey('reports-$connectionVersion'), api: api),
                  ];
                  final content = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            isWide ? 32 : 20, 24, isWide ? 32 : 20, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _sectionTitle(selectedPage),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: const Color(0xff172b27),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _sectionDescription(selectedPage),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: const Color(0xff71817c),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              isWide ? 32 : 16, 0, isWide ? 32 : 16, 20),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: IndexedStack(
                                index: selectedPage, children: pages),
                          ),
                        ),
                      ),
                    ],
                  );

                  return Row(
                    children: [
                      if (isWide)
                        NavigationRail(
                          backgroundColor: Colors.white,
                          selectedIndex: selectedPage,
                          labelType: NavigationRailLabelType.all,
                          groupAlignment: -.75,
                          indicatorColor: const Color(0xffdcefe9),
                          selectedIconTheme:
                              const IconThemeData(color: Color(0xff176b5b)),
                          selectedLabelTextStyle: const TextStyle(
                            color: Color(0xff176b5b),
                            fontWeight: FontWeight.w700,
                          ),
                          unselectedLabelTextStyle:
                              const TextStyle(color: Color(0xff71817c)),
                          onDestinationSelected: (index) =>
                              setState(() => selectedPage = index),
                          destinations: const [
                            NavigationRailDestination(
                              icon: Icon(Icons.dashboard_outlined),
                              selectedIcon: Icon(Icons.dashboard_rounded),
                              label: Text('Dashboard'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.directions_bus_outlined),
                              selectedIcon: Icon(Icons.directions_bus_filled),
                              label: Text('Operations'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.forum_outlined),
                              selectedIcon: Icon(Icons.forum_rounded),
                              label: Text('Content'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.assessment_outlined),
                              selectedIcon: Icon(Icons.assessment_rounded),
                              label: Text('Reports'),
                            ),
                          ],
                        ),
                      if (isWide)
                        const VerticalDivider(
                            width: 1, thickness: 1, color: Color(0xffe5ece9)),
                      Expanded(child: content),
                    ],
                  );
                },
              ),
        bottomNavigationBar:
            api.adminToken != null && MediaQuery.sizeOf(context).width < 1000
                ? NavigationBar(
                    selectedIndex: selectedPage,
                    onDestinationSelected: (index) =>
                        setState(() => selectedPage = index),
                    destinations: const [
                      NavigationDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          label: 'Dashboard'),
                      NavigationDestination(
                          icon: Icon(Icons.directions_bus_outlined),
                          label: 'Operations'),
                      NavigationDestination(
                          icon: Icon(Icons.forum_outlined), label: 'Content'),
                      NavigationDestination(
                          icon: Icon(Icons.assessment_outlined),
                          label: 'Reports'),
                    ],
                  )
                : null,
      ),
    );
  }

  Future<void> _editApiAddress() async {
    final addressController = TextEditingController(text: api.baseUrl);
    final keyController = TextEditingController(text: api.apiKey);
    var showKey = false;
    final settings = await showDialog<({String address, String key})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Backend connection'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Spring Boot API URL',
                    hintText: 'http://localhost:8081',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: keyController,
                  obscureText: !showKey,
                  decoration: InputDecoration(
                    labelText: 'Private API access key',
                    hintText: 'At least 32 random characters',
                    helperText:
                        'Stored in memory only; cleared when this page reloads.',
                    suffixIcon: IconButton(
                      tooltip: showKey ? 'Hide key' : 'Show key',
                      onPressed: () => setDialogState(() => showKey = !showKey),
                      icon: Icon(
                          showKey ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                (
                  address: addressController.text.trim(),
                  key: keyController.text.trim(),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (settings != null) {
      if (settings.address.isEmpty) {
        _showMessage(context, 'Enter the backend URL.');
        return;
      }
      if (settings.key.length < 32) {
        _showMessage(
            context, 'The API access key must contain at least 32 characters.');
        return;
      }
      setState(() {
        api
          ..baseUrl = settings.address.replaceAll(RegExp(r'/$'), '')
          ..apiKey = settings.key
          ..adminToken = null;
        selectedPage = 0;
        connectionVersion++;
      });
      _showMessage(context, 'Backend settings saved. Reloading data…');
    }
  }
}

String _sectionTitle(int index) => const [
      'Dashboard',
      'Transport operations',
      'Community & content',
      'Business reports',
    ][index];

String _sectionDescription(int index) => const [
      'A clear overview of your transport service activity.',
      'Create, review, and manage the operational records.',
      'Manage vehicle media, feedback, announcements, and discussions.',
      'Explore route usage, revenue, and passenger travel history.',
    ][index];

class SmartMoveApi {
  String baseUrl = const String.fromEnvironment(
    'SMARTMOVE_API_URL',
    defaultValue: 'http://localhost:8081',
  );
  String apiKey = const String.fromEnvironment('SMARTMOVE_API_KEY');
  String? adminToken;
  final http.Client _client = http.Client();

  Future<dynamic> request(String path,
      {String method = 'GET', Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'content-type': 'application/json',
      'X-SmartMove-API-Key': apiKey,
      if (adminToken != null) 'Authorization': 'Bearer $adminToken',
    };
    late http.StreamedResponse response;
    try {
      response = await _client
          .send(http.Request(method, uri)
            ..headers.addAll(headers)
            ..body = body == null ? '' : jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } on http.ClientException catch (error) {
      throw Exception(
        'Cannot reach SmartMove API at $baseUrl. Make sure the backend is running '
        'on this port and its CORS configuration allows this app. ${error.message}',
      );
    } on TimeoutException {
      throw Exception(
          'The SmartMove API at $baseUrl did not respond within 20 seconds.');
    }
    final text = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = text;
      try {
        final payload = jsonDecode(text);
        if (payload is Map) {
          final details = <String>[
            if (payload['error'] != null) payload['error'].toString(),
            if (payload['detail'] != null &&
                payload['detail'].toString().isNotEmpty &&
                payload['detail'] != payload['error'])
              payload['detail'].toString(),
            if (payload['message'] != null &&
                payload['message'].toString().isNotEmpty &&
                payload['message'] != payload['error'])
              payload['message'].toString(),
          ];
          if (details.isNotEmpty) message = details.join('\n');
        }
      } on FormatException {
        // Keep the raw response as the diagnostic message.
      }
      throw Exception('HTTP ${response.statusCode}: $message');
    }
    return text.isEmpty ? null : jsonDecode(text);
  }

  Future<void> loginAdmin(String email, String password) async {
    final result = await request('/api/auth/login',
        method: 'POST', body: {'email': email, 'password': password});
    if (result is! Map || result['token'] is! String) {
      throw const FormatException('The sign-in response was invalid.');
    }
    adminToken = result['token'] as String;
  }

  Future<dynamic> uploadVehicleImage(
    String vehicleId,
    XFile image, {
    required String registrationNumber,
    required String vehicleType,
  }) async {
    final extension = image.name.split('.').last.toLowerCase();
    final subtype = switch (extension) {
      'jpg' || 'jpeg' => 'jpeg',
      'png' => 'png',
      'webp' => 'webp',
      'gif' => 'gif',
      _ => throw FormatException('Unsupported image format: .$extension'),
    };
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/mongo/vehicle-content/$vehicleId/image'),
    )
      ..headers['X-SmartMove-API-Key'] = apiKey
      ..fields['registrationNumber'] = registrationNumber
      ..fields['vehicleType'] = vehicleType
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        await image.readAsBytes(),
        filename: image.name,
        contentType: MediaType('image', subtype),
      ));
    if (adminToken != null) {
      request.headers['Authorization'] = 'Bearer $adminToken';
    }
    late http.StreamedResponse response;
    try {
      response =
          await _client.send(request).timeout(const Duration(seconds: 30));
    } on http.ClientException catch (error) {
      throw Exception(
        'Cannot reach SmartMove API at $baseUrl while uploading the image. ${error.message}',
      );
    } on TimeoutException {
      throw Exception('Image upload to $baseUrl timed out.');
    }
    final text = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Image upload failed (HTTP ${response.statusCode}): $text');
    }
    return text.isEmpty ? null : jsonDecode(text);
  }
}

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({
    required this.api,
    required this.onSignedIn,
    super.key,
  });

  final SmartMoveApi api;
  final VoidCallback onSignedIn;

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool obscurePassword = true;
  String? errorMessage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(
          () => errorMessage = 'Enter your administrator email and password.');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      await widget.api.loginAdmin(email, password);
      if (!mounted) return;
      passwordController.clear();
      widget.onSignedIn();
    } catch (error) {
      if (mounted) setState(() => errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined,
                      size: 48, color: Color(0xff176b5b)),
                  const SizedBox(height: 16),
                  Text(
                    'Administrator sign in',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff172b27),
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in with an administrator account to manage SmartMove.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xff71817c)),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: emailController,
                    enabled: !isLoading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      hintText: 'admin@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    enabled: !isLoading,
                    obscureText: obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _signIn(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip:
                            obscurePassword ? 'Show password' : 'Hide password',
                        onPressed: () =>
                            setState(() => obscurePassword = !obscurePassword),
                        icon: Icon(obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      errorMessage!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: isLoading ? null : _signIn,
                    icon: isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(isLoading ? 'Signing in...' : 'Sign in'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => _showMessage(
                              context,
                              'Set the backend URL and private access key using the settings button above.',
                            ),
                    icon: const Icon(Icons.settings_ethernet, size: 18),
                    label: const Text('Connection settings'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({required this.api, super.key});
  final SmartMoveApi api;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, dynamic>> dashboard = _load();

  Future<Map<String, dynamic>> _load() async => Map<String, dynamic>.from(
      await widget.api.request('/api/dashboard') as Map);

  Future<void> _refresh() async {
    final updated = _load();
    setState(() {
      dashboard = updated;
    });
    await updated;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: dashboard,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorPanel(
            message: snapshot.error.toString(),
            onRetry: _refresh,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final metrics = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Transport operations at a glance',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: metrics.entries
                    .map((entry) => SizedBox(
                          width: 180,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_title(entry.key)),
                                  const SizedBox(height: 8),
                                  Text(entry.value.toString(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium),
                                ],
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              const Text(
                  'Manage transport operations, community content, and business reports from the navigation bar.'),
            ],
          ),
        );
      },
    );
  }
}

const Map<String, List<String>> resources = {
  'app-users': ['f_name', 'l_name', 'email', 'phone', 'password'],
  'routes': ['origin', 'destination', 'distance', 'est_du'],
  'vehicles': ['reg_no', 'vehicle_type', 'capacity', 'status'],
  'drivers': ['user_id', 'license', 'status'],
  'passengers': ['user_id'],
  'admins': ['user_id'],
  'trips': [
    'departure_time',
    'arrival_time',
    'fare',
    'status',
    'route_id',
    'vehicle_id',
    'driver_id',
    'passenger_id'
  ],
  'bookings': [
    'b_date',
    'seat_no',
    'tot_am',
    'status',
    'passenger_id',
    'trip_id'
  ],
  'payments': ['amount', 'pay_date', 'pay_method', 'pay_status', 'booking_id'],
  'maintenance': [
    'maintenance_date',
    'description',
    'cost',
    'status',
    'vehicle_id'
  ],
  'feedback': ['rating', 'comments', 'passenger_id', 'trip_id'],
  'roles': ['role_name'],
  'user-roles': ['user_id', 'role_id'],
};

const Map<String, String> resourceIds = {
  'app-users': 'user_id',
  'routes': 'route_id',
  'vehicles': 'vehicle_id',
  'drivers': 'user_id',
  'passengers': 'user_id',
  'admins': 'user_id',
  'trips': 'trip_id',
  'bookings': 'booking_id',
  'payments': 'payment_id',
  'maintenance': 'maintenance_id',
  'feedback': 'feedback_id',
  'roles': 'role_id',
  'user-roles': 'user_id',
};

class OperationsPage extends StatefulWidget {
  const OperationsPage({required this.api, super.key});
  final SmartMoveApi api;

  @override
  State<OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends State<OperationsPage> {
  String selectedResource = 'routes';
  late Future<List<dynamic>> records = _load();

  Future<List<dynamic>> _load() async {
    final records = List<dynamic>.from(
        await widget.api.request('/api/$selectedResource') as List);
    if (selectedResource != 'vehicles' || records.isEmpty) return records;
    final vehicleContent = List<dynamic>.from(
        await widget.api.request('/api/mongo/vehicle-content') as List);
    final imageByVehicle = <String, String>{};
    for (final content in vehicleContent) {
      final document = Map<String, dynamic>.from(content as Map);
      final images = document['images'];
      if (images is List && images.isNotEmpty) {
        final image = Map<String, dynamic>.from(images.last as Map);
        if (image['image_url'] is String) {
          imageByVehicle[document['vehicle_id'].toString()] =
              image['image_url'] as String;
        }
      }
    }
    return records.map((record) {
      final vehicle = Map<String, dynamic>.from(record as Map);
      vehicle['_vehicle_image'] =
          imageByVehicle[vehicle['vehicle_id'].toString()];
      return vehicle;
    }).toList();
  }

  Future<void> _refresh() async {
    final updated = _load();
    setState(() {
      records = updated;
    });
    await updated;
  }

  Future<void> _editRecord({Map<String, dynamic>? record}) async {
    if (selectedResource == 'vehicles') {
      await _editVehicle(record: record);
      return;
    }
    if (record == null &&
        (selectedResource == 'passengers' || selectedResource == 'drivers')) {
      await _createPassengerOrDriver();
      return;
    }
    final fields = resources[selectedResource]!;
    final controllers = <String, TextEditingController>{
      for (final field in fields)
        if (record == null || field != resourceIds[selectedResource])
          field: TextEditingController(text: record?[field]?.toString() ?? ''),
    };
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(record == null
            ? 'Add ${_title(selectedResource)}'
            : 'Edit ${_title(selectedResource)}'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: controllers.entries
                  .map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: entry.value,
                          obscureText: entry.key == 'password',
                          decoration: InputDecoration(
                            labelText: entry.key,
                            hintText: _exampleForField(entry.key),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              for (final e in controllers.entries) e.key: e.value.text.trim()
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (values == null) return;
    final body = <String, dynamic>{};
    for (final entry in values.entries) {
      if (entry.value.isNotEmpty) {
        body[entry.key] = _convertInput(entry.key, entry.value);
      }
    }
    try {
      final id = record?[resourceIds[selectedResource]];
      final path = selectedResource == 'user-roles' && record != null
          ? '/api/user-roles/$id/${record['role_id']}'
          : '/api/$selectedResource${id == null ? '' : '/$id'}';
      await widget.api.request(
        path,
        method: record == null ? 'POST' : 'PUT',
        body: body,
      );
      await _refresh();
      if (mounted) {
        _showMessage(
            context,
            record == null
                ? 'Record created successfully.'
                : 'Record updated successfully.');
      }
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    }
  }

  Future<void> _createPassengerOrDriver() async {
    final isDriver = selectedResource == 'drivers';
    final fields = <String, TextEditingController>{
      'f_name': TextEditingController(),
      'l_name': TextEditingController(),
      'email': TextEditingController(),
      'phone (optional)': TextEditingController(),
      'password (minimum 10 characters)': TextEditingController(),
      if (isDriver) 'license': TextEditingController(),
      if (isDriver)
        'status (optional, defaults to Active)':
            TextEditingController(text: 'Active'),
    };
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isDriver
            ? 'Add Driver and User Account'
            : 'Add Passenger and User Account'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: fields.entries
                  .map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: entry.value,
                          obscureText: entry.key.startsWith('password'),
                          keyboardType: entry.key == 'email'
                              ? TextInputType.emailAddress
                              : TextInputType.text,
                          decoration: InputDecoration(
                            labelText: entry.key,
                            hintText: _exampleForField(entry.key),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final requiredFields = [
                'f_name',
                'l_name',
                'email',
                'password (minimum 10 characters)',
                if (isDriver) 'license'
              ];
              final missing = requiredFields
                  .where((field) => fields[field]!.text.trim().isEmpty)
                  .toList();
              if (missing.isNotEmpty) {
                _showMessage(context, 'Fill in: ${missing.join(', ')}');
                return;
              }
              if (fields['password (minimum 10 characters)']!.text.length <
                  10) {
                _showMessage(
                    context, 'Password must contain at least 10 characters.');
                return;
              }
              Navigator.pop(dialogContext, {
                for (final entry in fields.entries)
                  entry.key: entry.value.text.trim(),
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (values == null) return;

    try {
      final body = <String, dynamic>{
        'f_name': values['f_name'],
        'l_name': values['l_name'],
        'email': values['email'],
        'password': values['password (minimum 10 characters)'],
        if (values['phone (optional)']!.isNotEmpty)
          'phone': values['phone (optional)'],
        if (isDriver) 'license': values['license'],
        if (isDriver &&
            values['status (optional, defaults to Active)']!.isNotEmpty)
          'status': values['status (optional, defaults to Active)'],
      };
      final result = Map<String, dynamic>.from(await widget.api.request(
        '/api/$selectedResource',
        method: 'POST',
        body: body,
      ) as Map);
      await _refresh();
      if (mounted) {
        _showMessage(context,
            '${isDriver ? 'Driver' : 'Passenger'} and user account created (user ID ${result['user_id']}).');
      }
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    }
  }

  Future<void> _editVehicle({Map<String, dynamic>? record}) async {
    final controllers = <String, TextEditingController>{
      for (final field in resources['vehicles']!)
        if (record == null || field != resourceIds['vehicles'])
          field: TextEditingController(text: record?[field]?.toString() ?? ''),
    };
    XFile? selectedImage;
    final values =
        await showDialog<({Map<String, String> fields, XFile? image})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(record == null ? 'Add Vehicle' : 'Edit Vehicle'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in controllers.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: entry.value,
                        decoration: InputDecoration(
                          labelText: entry.key,
                          hintText: _exampleForField(entry.key),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  if (selectedImage != null)
                    FutureBuilder<Uint8List>(
                      future: selectedImage!.readAsBytes(),
                      builder: (context, snapshot) => snapshot.hasData
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Image.memory(
                                snapshot.data!,
                                height: 160,
                                fit: BoxFit.contain,
                              ),
                            )
                          : const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(),
                            ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final image = await openFile(
                        acceptedTypeGroups: [
                          const XTypeGroup(
                            label: 'Vehicle images',
                            extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
                          ),
                        ],
                      );
                      if (image != null) {
                        setDialogState(() => selectedImage = image);
                      }
                    },
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(selectedImage == null
                        ? record == null
                            ? 'Choose vehicle image (required)'
                            : 'Choose replacement image (optional)'
                        : selectedImage!.name),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final fields = {
                  for (final entry in controllers.entries)
                    entry.key: entry.value.text.trim()
                };
                final missing = const ['reg_no', 'vehicle_type', 'capacity']
                    .where((field) => fields[field]!.isEmpty)
                    .toList();
                if (missing.isNotEmpty) {
                  _showMessage(context, 'Fill in: ${missing.join(', ')}');
                  return;
                }
                if (record == null && selectedImage == null) {
                  _showMessage(context,
                      'Choose a vehicle image before adding the vehicle.');
                  return;
                }
                Navigator.pop(
                    dialogContext, (fields: fields, image: selectedImage));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (values == null) return;

    try {
      final body = <String, dynamic>{
        'reg_no': values.fields['reg_no'],
        'vehicle_type': values.fields['vehicle_type'],
        'capacity': num.tryParse(values.fields['capacity']!) ??
            values.fields['capacity'],
        if (values.fields['status']!.isNotEmpty)
          'status': values.fields['status'],
      };
      final id = record?['vehicle_id'];
      final result = await widget.api.request(
        '/api/vehicles${id == null ? '' : '/$id'}',
        method: record == null ? 'POST' : 'PUT',
        body: body,
      );
      final vehicleId = id ?? (result as Map)['vehicle_id'];
      if (vehicleId == null) {
        throw Exception('Vehicle saved, but no vehicle ID was returned.');
      }
      if (values.image != null) {
        try {
          await widget.api.uploadVehicleImage(
            vehicleId.toString(),
            values.image!,
            registrationNumber: values.fields['reg_no']!,
            vehicleType: values.fields['vehicle_type']!,
          );
        } catch (error) {
          await _refresh();
          throw Exception(
            'Vehicle ${record == null ? 'created' : 'updated'} as ID $vehicleId, but its image upload failed. '
            'Edit the vehicle to retry the upload. $error',
          );
        }
      }
      await _refresh();
      if (mounted) {
        _showMessage(
          context,
          values.image != null
              ? 'Vehicle and image saved successfully.'
              : 'Vehicle updated successfully.',
        );
      }
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    }
  }

  dynamic _convertInput(String field, String value) {
    const numericFields = {
      'distance',
      'capacity',
      'admin_id',
      'fare',
      'route_id',
      'vehicle_id',
      'driver_id',
      'passenger_id',
      'tot_am',
      'booking_id',
      'rating',
      'cost',
      'user_id',
      'role_id'
    };
    if (numericFields.contains(field)) {
      return num.tryParse(value) ?? value;
    }
    return value;
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    final id = record[resourceIds[selectedResource]];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this record?'),
        content: Text(
          'This will permanently delete ${_title(selectedResource)} record $id. '
          'Some related records may also be affected.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final path = selectedResource == 'user-roles'
          ? '/api/user-roles/$id/${record['role_id']}'
          : '/api/$selectedResource/$id';
      await widget.api.request(path, method: 'DELETE');
      await _refresh();
      if (mounted) _showMessage(context, 'Record deleted successfully.');
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 540;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isNarrow ? constraints.maxWidth - 32 : 280,
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedResource,
                      items: resources.keys
                          .map((key) => DropdownMenuItem(
                              value: key, child: Text(_title(key))))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          selectedResource = value;
                          records = _load();
                        });
                      },
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _editRecord(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add record'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            );
          },
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: records,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorPanel(
                    message: snapshot.error.toString(), onRetry: _refresh);
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return const Center(child: Text('No records found.'));
              }
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final item =
                      Map<String, dynamic>.from(snapshot.data![index] as Map);
                  final id = resourceIds[selectedResource]!;
                  final values = item.entries
                      .where((entry) => entry.key != id)
                      .take(4)
                      .map((entry) => '${entry.key}: ${entry.value}')
                      .join(' • ');
                  final image = item['_vehicle_image'] as String?;
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: ListTile(
                      leading: image == null
                          ? const Icon(Icons.directions_bus_outlined)
                          : Image.network(
                              '${widget.api.baseUrl}$image',
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                      title: Text('$id: ${item[id] ?? '-'}'),
                      subtitle: Text(values,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Wrap(
                        children: [
                          if (selectedResource != 'user-roles')
                            IconButton(
                                onPressed: () => _editRecord(record: item),
                                icon: const Icon(Icons.edit_outlined)),
                          IconButton(
                              onPressed: () => _deleteRecord(item),
                              icon: const Icon(Icons.delete_outline)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class MongoPage extends StatefulWidget {
  const MongoPage({required this.api, required this.isActive, super.key});
  final SmartMoveApi api;
  final bool isActive;

  @override
  State<MongoPage> createState() => _MongoPageState();
}

class _MongoPageState extends State<MongoPage> {
  static const collections = [
    'vehicle content',
    'passenger feedback',
    'vehicle ratings',
    'driver ratings',
    'complaints',
    'announcements',
    'notifications',
    'community forum',
  ];

  String selected = 'passenger feedback';
  String authorRole = 'passenger';
  final routeController = TextEditingController();
  final keywordController = TextEditingController();
  late Future<List<dynamic>> items = _load();
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    _updateRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant MongoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) _updateRefreshTimer();
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    routeController.dispose();
    keywordController.dispose();
    super.dispose();
  }

  void _updateRefreshTimer() {
    refreshTimer?.cancel();
    if (widget.isActive) {
      refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted) {
          setState(() {
            items = _load();
          });
        }
      });
    }
  }

  String get endpoint => switch (selected) {
        'vehicle content' => '/api/mongo/vehicle-content',
        'passenger feedback' =>
          '/api/mongo/feedback${routeController.text.trim().isEmpty ? '' : '?routeId=${Uri.encodeQueryComponent(routeController.text.trim())}'}',
        'vehicle ratings' => '/api/mongo/ratings/vehicles',
        'driver ratings' => '/api/mongo/ratings/drivers',
        'complaints' =>
          '/api/mongo/complaints?keyword=${Uri.encodeQueryComponent(keywordController.text.trim())}',
        'announcements' => '/api/mongo/announcements?activeOnly=false',
        'notifications' => '/api/mongo/notifications',
        _ => '/api/mongo/community',
      };

  Future<List<dynamic>> _load() async {
    final result = await widget.api.request(endpoint);
    return result is List ? List<dynamic>.from(result) : <dynamic>[];
  }

  Future<void> _query() async {
    try {
      final routeId = routeController.text.trim();
      if (selected == 'passenger feedback' &&
          routeId.isNotEmpty &&
          (int.tryParse(routeId) == null || int.parse(routeId) < 1)) {
        throw const FormatException(
            'Route ID must be a positive whole number.');
      }
      if (selected == 'complaints' && keywordController.text.trim().isEmpty) {
        throw const FormatException('Enter a keyword to search complaints.');
      }
      if (selected == 'complaints' &&
          keywordController.text.trim().length > 100) {
        throw const FormatException(
            'Complaint keyword must be 100 characters or fewer.');
      }
      late Future<List<dynamic>> updated;
      setState(() {
        updated = _load();
        items = updated;
      });
      await updated;
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: selected,
                items: collections
                    .map((item) => DropdownMenuItem(
                        value: item, child: Text(_title(item))))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selected = value;
                    items = value == 'complaints' &&
                            keywordController.text.trim().isEmpty
                        ? Future.value(<dynamic>[])
                        : _load();
                  });
                },
              ),
              if (selected == 'passenger feedback')
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: routeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Route ID (optional)',
                      hintText: 'e.g. 1',
                    ),
                  ),
                ),
              if (selected == 'complaints')
                SizedBox(
                  width: 210,
                  child: TextField(
                    controller: keywordController,
                    decoration: const InputDecoration(
                      labelText: 'Complaint keyword',
                      hintText: 'e.g. delay',
                    ),
                  ),
                ),
              FilledButton(onPressed: _query, child: const Text('Load')),
              if (selected == 'vehicle content')
                OutlinedButton.icon(
                    onPressed: _newVehicleContent,
                    icon: const Icon(Icons.directions_bus_filled_outlined),
                    label: const Text('Save vehicle media')),
              if (selected == 'passenger feedback')
                OutlinedButton.icon(
                    onPressed: _newFeedback,
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Write feedback')),
              if (selected == 'announcements')
                OutlinedButton.icon(
                    onPressed: _newAnnouncement,
                    icon: const Icon(Icons.add),
                    label: const Text('Publish announcement')),
              if (selected == 'notifications')
                OutlinedButton.icon(
                    onPressed: _newNotification,
                    icon: const Icon(Icons.add_alert_outlined),
                    label: const Text('New notification')),
              if (selected == 'community forum')
                OutlinedButton.icon(
                    onPressed: _newCommunityPost,
                    icon: const Icon(Icons.add_comment_outlined),
                    label: const Text('New discussion')),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: items,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorPanel(
                    message: snapshot.error.toString(), onRetry: _query);
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return const Center(child: Text('No items found.'));
              }
              return ListView(
                children: snapshot.data!.map((record) {
                  final map = Map<String, dynamic>.from(record as Map);
                  final title = switch (selected) {
                    'vehicle content' =>
                      'Vehicle ${map['vehicle_id']}: ${map['registration_number'] ?? ''}',
                    'passenger feedback' ||
                    'complaints' =>
                      'Rating ${map['rating'] ?? '-'} / 5 · ${map['category'] ?? ''}',
                    'vehicle ratings' =>
                      'Vehicle ${map['_id']} · ${map['average_rating']} / 5',
                    'driver ratings' =>
                      'Driver ${map['_id']} · ${map['average_rating']} / 5',
                    'community forum' => map['topic'] ?? 'Discussion',
                    'notifications' => map['title'] ?? 'Notification',
                    _ => map['title'] ?? 'Announcement',
                  };
                  final actions = <Widget>[];
                  if (selected == 'announcements' && map['_id'] != null) {
                    actions.add(IconButton(
                      tooltip:
                          map['active'] == true ? 'Deactivate' : 'Activate',
                      onPressed: () => _setAnnouncementActive(map),
                      icon: Icon(map['active'] == true
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                    ));
                  }
                  if (selected == 'notifications' &&
                      map['_id'] != null &&
                      map['read'] != true) {
                    actions.add(IconButton(
                      tooltip: 'Mark as read',
                      onPressed: () => _markNotificationRead(map),
                      icon: const Icon(Icons.mark_email_read_outlined),
                    ));
                  }
                  if ((selected == 'community forum' ||
                          selected == 'passenger feedback' ||
                          selected == 'complaints') &&
                      map['_id'] != null) {
                    actions.add(IconButton(
                      tooltip: 'Reply',
                      onPressed: () => _replyTo(map),
                      icon: const Icon(Icons.reply),
                    ));
                  }
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: Text(title.toString(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium)),
                              ...actions,
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (selected == 'vehicle content' &&
                              map['images'] is List)
                            for (final entry in map['images'] as List)
                              if (entry is Map && entry['image_url'] is String)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Image.network(
                                    '${widget.api.baseUrl}${entry['image_url']}',
                                    height: 180,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error,
                                            stackTrace) =>
                                        const Text(
                                            'Vehicle image could not be loaded.'),
                                  ),
                                ),
                          _mongoDetails(map),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<Map<String, String>?> _form(String title, List<String> names,
      {Set<String> multiline = const {}}) {
    final fields = {for (final name in names) name: TextEditingController()};
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: fields.entries
                  .map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: entry.value,
                          minLines: multiline.contains(entry.key) ? 3 : 1,
                          maxLines: multiline.contains(entry.key) ? 6 : 1,
                          decoration: InputDecoration(
                            labelText: entry.key,
                            hintText: _exampleForField(entry.key),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              {
                for (final entry in fields.entries)
                  entry.key: entry.value.text.trim()
              },
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _newVehicleContent() async {
    final values = await _form('Vehicle details and images', [
      'vehicle_id',
      'registration_number',
      'vehicle_type',
      'documents',
      'images',
      'metadata (optional)',
    ], multiline: {
      'documents',
      'images',
      'metadata (optional)'
    });
    if (values == null) return;
    try {
      final documents = _parseJson(values['documents']!, <dynamic>[]);
      final images = _parseJson(values['images']!, <dynamic>[]);
      final metadata =
          _parseJson(values['metadata (optional)']!, <String, dynamic>{});
      if (documents is! List || images is! List || metadata is! Map) {
        throw const FormatException(
            'Documents and images must be JSON arrays; metadata must be a JSON object.');
      }
      final vehicleId = int.parse(values['vehicle_id']!);
      await widget.api.request(
        '/api/mongo/vehicle-content/$vehicleId',
        method: 'PUT',
        body: {
          'registration_number': values['registration_number'],
          'vehicle_type': values['vehicle_type'],
          'documents': documents,
          'images': images,
          'metadata': metadata,
        },
      );
      await _query();
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    }
  }

  Future<void> _newFeedback() async {
    final values = await _form('Passenger feedback', [
      'passenger_id',
      'route_id',
      'trip_id (optional)',
      'vehicle_id (optional)',
      'driver_id (optional)',
      'rating (1-5)',
      'category (compliment, complaint, suggestion)',
      'comment',
      'tags (comma separated, optional)',
    ], multiline: {
      'comment'
    });
    if (values == null) return;
    try {
      final body = <String, dynamic>{
        'passenger_id': int.parse(values['passenger_id']!),
        'route_id': int.parse(values['route_id']!),
        'rating': int.parse(values['rating (1-5)']!),
        'category': values['category (compliment, complaint, suggestion)'],
        'comment': values['comment'],
      };
      for (final field in ['trip_id', 'vehicle_id', 'driver_id']) {
        final text = values[field]!;
        if (text.isNotEmpty) body[field] = int.parse(text);
      }
      final tags = values['tags (comma separated, optional)']!;
      if (tags.isNotEmpty) {
        body['tags'] = tags.split(',').map((tag) => tag.trim()).toList();
      }
      await widget.api
          .request('/api/mongo/feedback', method: 'POST', body: body);
      await _query();
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    }
  }

  Future<void> _newAnnouncement() async {
    final values = await _form('Travel announcement', [
      'title',
      'message',
      'type',
      'target_route_ids (comma separated, optional)',
      'audience (optional)',
    ], multiline: {
      'message'
    });
    if (values == null) return;
    try {
      final body = <String, dynamic>{
        'title': values['title'],
        'message': values['message'],
        'type': values['type'],
        if (values['audience']!.isNotEmpty) 'audience': values['audience'],
      };
      final routes = values['target_route_ids (comma separated, optional)']!;
      if (routes.isNotEmpty) {
        body['target_route_ids'] =
            routes.split(',').map((route) => int.parse(route.trim())).toList();
      }
      await widget.api
          .request('/api/mongo/announcements', method: 'POST', body: body);
      await _query();
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    }
  }

  Future<void> _newNotification() async {
    final values = await _form('Travel notification', [
      'recipient_id (optional)',
      'title',
      'message',
      'type',
    ], multiline: {
      'message'
    });
    if (values == null) return;
    try {
      await widget.api
          .request('/api/mongo/notifications', method: 'POST', body: {
        if (values['recipient_id (optional)']!.isNotEmpty)
          'recipient_id': int.parse(values['recipient_id (optional)']!),
        'title': values['title'],
        'message': values['message'],
        'type': values['type'],
      });
      await _query();
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    }
  }

  Future<void> _newCommunityPost() async {
    final values = await _form('Community discussion', [
      'author_name',
      'author_role (student or instructor)',
      'topic',
      'message'
    ], multiline: {
      'message'
    });
    if (values == null) return;
    try {
      await widget.api.request('/api/mongo/community', method: 'POST', body: {
        'author_name': values['author_name'],
        'author_role': values['author_role (student or instructor)'],
        'topic': values['topic'],
        'message': values['message'],
      });
      await _query();
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    }
  }

  Future<void> _replyTo(Map<String, dynamic> post) async {
    final values = await _form('Reply to ${post['topic'] ?? 'feedback'}',
        ['author_name', 'author_role (student or instructor)', 'message'],
        multiline: {'message'});
    if (values == null) return;
    try {
      final path = selected == 'community forum'
          ? '/api/mongo/community/${post['_id']}/replies'
          : '/api/mongo/feedback/${post['_id']}/replies';
      await widget.api.request(path, method: 'POST', body: {
        'author_name': values['author_name'],
        'author_role': values['author_role (student or instructor)'],
        'message': values['message'],
      });
      await _query();
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    }
  }

  Future<void> _setAnnouncementActive(Map<String, dynamic> announcement) async {
    try {
      await widget.api.request(
          '/api/mongo/announcements/${announcement['_id']}/active',
          method: 'PATCH',
          body: {'active': announcement['active'] != true});
      await _query();
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    }
  }

  Future<void> _markNotificationRead(Map<String, dynamic> notification) async {
    try {
      await widget.api.request(
          '/api/mongo/notifications/${notification['_id']}/read',
          method: 'PATCH');
      await _query();
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    }
  }

  Widget _mongoDetails(Map<String, dynamic> document) {
    final entries = document.entries
        .where((entry) => entry.key != '_id' && entry.key != 'images')
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 540 ? constraints.maxWidth : 240.0;
        return Wrap(
          spacing: 20,
          runSpacing: 14,
          children: entries.map((entry) {
            final value = entry.value is Map || entry.value is List
                ? jsonEncode(entry.value)
                : entry.value?.toString() ?? '—';
            return SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(entry.key),
                    style: const TextStyle(
                      color: Color(0xff71817c),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SelectableText(value),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  dynamic _parseJson(String text, dynamic defaultValue) =>
      text.trim().isEmpty ? defaultValue : jsonDecode(text);
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({required this.api, super.key});
  final SmartMoveApi api;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String selected = 'frequent routes';
  final from = TextEditingController(text: '2026-01-01');
  final to = TextEditingController(text: '2027-12-31');
  final passengerId = TextEditingController();
  late Future<dynamic> result = _load();

  @override
  void dispose() {
    from.dispose();
    to.dispose();
    passengerId.dispose();
    super.dispose();
  }

  String get endpoint => switch (selected) {
        'frequent routes' => '/api/reports/frequent-routes',
        'revenue by period' =>
          '/api/reports/revenue?from=${Uri.encodeQueryComponent(from.text.trim())}&to=${Uri.encodeQueryComponent(to.text.trim())}',
        'passenger history' =>
          '/api/reports/passenger-history/${Uri.encodeComponent(passengerId.text.trim())}',
        _ => '/api/reports/maintenance-summary',
      };

  Future<dynamic> _load() => widget.api.request(endpoint);

  Future<void> _run() async {
    if (selected == 'passenger history') {
      final id = int.tryParse(passengerId.text.trim());
      if (id == null || id < 1) {
        _showMessage(context, 'Enter a positive whole-number passenger ID.');
        return;
      }
    }
    if (selected == 'revenue by period') {
      final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      final startText = from.text.trim();
      final endText = to.text.trim();
      final start = DateTime.tryParse(startText);
      final end = DateTime.tryParse(endText);
      if (!datePattern.hasMatch(startText) ||
          !datePattern.hasMatch(endText) ||
          start == null ||
          end == null ||
          start.toIso8601String().substring(0, 10) != startText ||
          end.toIso8601String().substring(0, 10) != endText) {
        _showMessage(context, 'Enter valid dates using YYYY-MM-DD format.');
        return;
      }
      if (end.isBefore(start)) {
        _showMessage(
            context, 'The end date must be on or after the start date.');
        return;
      }
    }
    setState(() {
      result = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: selected,
                items: const [
                  'frequent routes',
                  'revenue by period',
                  'passenger history',
                  'maintenance summary',
                ]
                    .map((item) => DropdownMenuItem(
                        value: item, child: Text(_title(item))))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selected = value;
                    result = value == 'revenue by period' ||
                            value == 'passenger history'
                        ? Future.value(<dynamic>[])
                        : _load();
                  });
                },
              ),
              if (selected == 'revenue by period') ...[
                SizedBox(
                  width: 145,
                  child: TextField(
                    controller: from,
                    decoration: const InputDecoration(
                      labelText: 'From (YYYY-MM-DD)',
                      hintText: 'e.g. 2026-01-01',
                    ),
                  ),
                ),
                SizedBox(
                  width: 145,
                  child: TextField(
                    controller: to,
                    decoration: const InputDecoration(
                      labelText: 'To (YYYY-MM-DD)',
                      hintText: 'e.g. 2026-12-31',
                    ),
                  ),
                ),
              ],
              if (selected == 'passenger history')
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: passengerId,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Passenger ID',
                      hintText: 'e.g. 1',
                    ),
                  ),
                ),
              FilledButton(onPressed: _run, child: const Text('Run report')),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<dynamic>(
            future: result,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorPanel(
                    message: snapshot.error.toString(), onRetry: _run);
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _reportResults(snapshot.data);
            },
          ),
        ),
      ],
    );
  }

  Widget _reportResults(dynamic data) {
    if (data is List && data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.assessment_outlined,
                  size: 44, color: Color(0xff71817c)),
              const SizedBox(height: 12),
              Text(
                selected == 'revenue by period' ||
                        selected == 'passenger history'
                    ? 'Choose the report parameters, then run the report.'
                    : 'No report results were found.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (data is Map && data['daily'] is List) {
      final daily = List<dynamic>.from(data['daily'] as List);
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 36,
                runSpacing: 16,
                children: [
                  _reportValue('Date range', '${data['from']} to ${data['to']}',
                      emphasized: false),
                  _reportValue('Total revenue', data['revenue'],
                      emphasized: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Daily revenue', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (daily.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('No paid revenue was recorded in this date range.'),
              ),
            )
          else
            ...daily.map(
                (row) => _reportRecord(Map<String, dynamic>.from(row as Map))),
        ],
      );
    }

    final rows = data is List ? data : [data];
    if (rows.isEmpty) {
      return const Center(child: Text('No report results were found.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (var index = 0; index < rows.length; index++)
          _reportRecord(Map<String, dynamic>.from(rows[index] as Map),
              index: index + 1),
      ],
    );
  }

  Widget _reportRecord(Map<String, dynamic> record, {int? index}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index != null) ...[
              Text('Result $index',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
            ],
            Wrap(
              spacing: 24,
              runSpacing: 14,
              children: record.entries.map((entry) {
                return SizedBox(
                  width: 210,
                  child: _reportValue(_title(entry.key), entry.value,
                      emphasized: false),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportValue(String label, Object? value, {required bool emphasized}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xff71817c), fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value?.toString() ?? '—',
          style: TextStyle(
            color:
                emphasized ? const Color(0xff176b5b) : const Color(0xff172b27),
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            fontSize: emphasized ? 22 : 15,
          ),
        ),
      ],
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({required this.message, required this.onRetry, super.key});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

String _title(String value) => value
    .split(RegExp(r'[-_\s]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _exampleForField(String field) {
  final name = field.toLowerCase().split(' (').first.trim();
  final example = switch (name) {
    'f_name' => 'Nimal',
    'l_name' => 'Perera',
    'email' => 'nimal.perera@example.com',
    'phone' => '+94771234567',
    'password' => 'MoveSafe2026!',
    'license' => 'B1234567',
    'status' => 'Available',
    'role_name' => 'Passenger',
    'user_id' ||
    'role_id' ||
    'passenger_id' ||
    'driver_id' ||
    'admin_id' ||
    'route_id' ||
    'trip_id' ||
    'vehicle_id' ||
    'booking_id' ||
    'payment_id' ||
    'maintenance_id' ||
    'feedback_id' ||
    'recipient_id' =>
      '1',
    'origin' => 'Colombo',
    'destination' => 'Kandy',
    'distance' => '115.5',
    'est_du' => '3 hours 30 minutes',
    'reg_no' || 'registration_number' => 'ABC-1234',
    'vehicle_type' => 'Bus',
    'capacity' => '40',
    'departure_time' || 'arrival_time' || 'b_date' => '2026-10-15T08:30:00',
    'fare' || 'tot_am' || 'amount' || 'cost' => '1500.00',
    'seat_no' => 'A12',
    'pay_date' => '2026-10-15T08:30:00',
    'maintenance_date' => '2026-10-15',
    'pay_method' => 'Card',
    'pay_status' => 'Paid',
    'description' => 'Routine vehicle inspection',
    'rating' => '5',
    'comments' || 'comment' => 'The trip was comfortable and on time.',
    'documents' =>
      '[{"document_type":"insurance","document_number":"INS-2026-001","expiry_date":"2027-01-31","status":"valid"}]',
    'images' =>
      '[{"image_id":"example-id","image_url":"https://example.com/bus.jpg","file_name":"bus.jpg","content_type":"image/jpeg","size_bytes":245760}]',
    'metadata' => '{"color":"white","seats":40}',
    'category' => 'complaint',
    'tags' => 'clean, punctual',
    'title' => 'Route service update',
    'message' => 'The 08:30 service will depart from the main terminal.',
    'type' => 'service_alert',
    'target_route_ids' => '1, 2',
    'audience' => 'Passengers',
    'author_name' => 'Nimal Perera',
    'author_role' => 'student',
    'topic' => 'Suggestions for the Kandy route',
    'keyword' => 'delay',
    _ => 'Sample $field',
  };
  return 'e.g. $example';
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
