import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إدارة المستخدمين',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<_ViewUsersPageState> _viewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة المستخدمين'),
          backgroundColor: Colors.blue.shade700,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(icon: Icon(Icons.person_add), text: 'إضافة'),
              Tab(icon: Icon(Icons.list), text: 'السجلات'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            AddUserPage(onAdded: () => _viewKey.currentState?.fetchUsers()),
            ViewUsersPage(key: _viewKey),
          ],
        ),
      ),
    );
  }
}

class AddUserPage extends StatefulWidget {
  final VoidCallback? onAdded;
  const AddUserPage({super.key, this.onAdded});
  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  bool loading = false;

  final String apiUrl = 'http://127.0.0.1:8080/api/index.php/users';

  Future<void> addUser() async {
    if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': nameCtrl.text,
          'email': emailCtrl.text,
          'phone': phoneCtrl.text,
        }),
      );

      final data = jsonDecode(response.body);
      if (!mounted) return;

      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت الإضافة بنجاح ✅'), backgroundColor: Colors.green),
        );
        nameCtrl.clear();
        emailCtrl.clear();
        phoneCtrl.clear();
        widget.onAdded?.call();
      } else {
        throw Exception(data['error']);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'الاسم',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'البريد الإلكتروني',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: loading ? null : addUser,
              icon: loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(loading ? 'جارٍ الإضافة...' : 'إضافة', style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

class ViewUsersPage extends StatefulWidget {
  const ViewUsersPage({super.key});
  @override
  State<ViewUsersPage> createState() => _ViewUsersPageState();
}

class _ViewUsersPageState extends State<ViewUsersPage> {
  List<dynamic> users = [];
  bool loading = true;
  String? error;
  int? deletingId;

  final String apiUrl = 'http://127.0.0.1:8080/api/index.php/users';

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    if (!mounted) return;
    setState(() { loading = true; error = null; });

    try {
      final response = await http.get(Uri.parse(apiUrl));
      final data = jsonDecode(response.body);
      if (!mounted) return;

      if (data is List) {
        setState(() { users = data; loading = false; });
      } else {
        throw Exception('رد غير متوقع');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> deleteUser(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف "$name" نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => deletingId = id);

    try {
      final response = await http.delete(Uri.parse('$apiUrl?id=$id'));
      final data = jsonDecode(response.body);
      if (!mounted) return;

      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف "$name" ✅'), backgroundColor: Colors.green),
        );
        setState(() { users.removeWhere((u) => u['id'] == id); });
      } else {
        throw Exception(data['error'] ?? 'فشل الحذف');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              Text('خطأ: $error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: fetchUsers,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (users.isEmpty) {
      return RefreshIndicator(
        onRefresh: fetchUsers,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            const Center(
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا يوجد مستخدمون بعد', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final id = user['id'] as int;
          final isDeleting = deletingId == id;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade700,
                child: Text('#$id',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              title: Text(user['name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.email, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(child: Text(user['email'] ?? '', style: const TextStyle(fontSize: 13))),
                  ]),
                  Row(children: [
                    const Icon(Icons.phone, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(user['phone'] ?? '', style: const TextStyle(fontSize: 13)),
                  ]),
                ],
              ),
              trailing: isDeleting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'حذف',
                      onPressed: () => deleteUser(id, user['name'] ?? ''),
                    ),
            ),
          );
        },
      ),
    );
  }
}
