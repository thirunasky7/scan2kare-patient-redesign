import 'package:flutter/material.dart';
import '../services/health_hub_service.dart';
import '../models/article_model.dart';
import '../models/category_model.dart';
import '../widgets/health_hub_slider.dart';
import 'article_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'profile_screen.dart';
import 'my_bookings_screen.dart';
import 'second_opinion_page.dart';
import '../utils/auth_nav.dart';
import 'scanner_screen.dart';
import '../services/location_service.dart';
import '../widgets/common_drawer.dart';
import '../utils/deeplink_nav.dart';
import '../widgets/app_bottom_nav.dart';

class HealthHubScreen extends StatefulWidget {
  const HealthHubScreen({super.key});

  @override
  State<HealthHubScreen> createState() => _HealthHubScreenState();
}

class _HealthHubScreenState extends State<HealthHubScreen> {
  List<Article> allArticles = [];
  List<Article> filteredArticles = [];
  List<BlogCategory> categories = [];

  bool isLoading = true;
  int selectedCategory = -1;
  String searchText = "";
  String _userName = "Guest";
  String _shortAddress = '';
  String _address = "";
  final bool _isHealthHubExpanded =
      false; // Add this line for submenu expansion

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
    _loadSavedLocation();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedLocation = await LocationService.loadLocation();

    setState(() {
      _userName = prefs.getString('user_name') ?? 'Guest';

      if (savedLocation != null) {
        _address = savedLocation['address'];
      }
    });
  }

  Future<void> _loadSavedLocation() async {
    final savedLocation = await LocationService.loadLocation();

    if (savedLocation != null) {
      setState(() {
        _address = savedLocation['address'];
      });
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final data = await AuthService.getUserProfile();

      setState(() {
        _userName = data['name'] ?? 'Guest';
        _address = data['address'] ?? '';
        _shortAddress = _address;
      });
    } catch (e) {
      debugPrint("Profile load error: $e");
    }
  }

  Future<void> loadData() async {
    final data = await HealthHubService.fetchData();

    setState(() {
      allArticles = data["articles"];
      filteredArticles = allArticles;
      categories = data["categories"];
      isLoading = false;
    });
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    goToLogin();
  }

  void applyFilters() {
    List<Article> temp = allArticles;

    /// CATEGORY FILTER
    if (selectedCategory != -1) {
      temp = temp.where((a) => a.categoryId == selectedCategory).toList();
    }

    /// SEARCH FILTER
    if (searchText.isNotEmpty) {
      temp = temp
          .where(
              (a) => a.title.toLowerCase().contains(searchText.toLowerCase()))
          .toList();
    }

    setState(() {
      filteredArticles = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CommonDrawer(),
      appBar: _buildAppBar(),
      backgroundColor: const Color(0xffF4F6F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const HealthhubSlider(),
              const SizedBox(height: 15),

              /// SEARCH BAR
              Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: searchController,
                  onChanged: (value) {
                    searchText = value;
                    applyFilters();
                  },
                  decoration: const InputDecoration(
                    hintText: "Search by Health tips",
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(top: 10),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              /// CATEGORY TABS
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    /// ALL TAB
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedCategory = -1;
                          applyFilters();
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: selectedCategory == -1
                              ? const Color(0xffDCE8FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "All",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),

                    /// CATEGORY LIST
                    ...categories.map((cat) {
                      final isSelected = selectedCategory == cat.id;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCategory = cat.id;
                            applyFilters();
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xffDCE8FF)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            cat.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              /// ARTICLES LIST
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: filteredArticles.length,
                        itemBuilder: (context, index) {
                          final article = filteredArticles[index];

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ArticleDetailScreen(article: article),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12.withOpacity(.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  /// IMAGE
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 80,
                                      height: 80,
                                      child: Image.network(
                                        article.image,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[300],
                                            child: const Icon(
                                                Icons.broken_image,
                                                color: Colors.grey),
                                          );
                                        },
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  /// TEXT CONTENT
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        /// TITLE
                                        Text(
                                          article.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        const SizedBox(height: 6),

                                        /// DESCRIPTION
                                        if (article.description.isNotEmpty)
                                          Text(
                                            article.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              )
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        current: null,
        onHome: () => navigateToHome(context),
        onScan: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScannerScreen()),
        ),
        onRecentHospital: () => navigateToRecentHospitalTab(context),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0x1F62C6FF),
      surfaceTintColor: const Color(0x1F62C6FF),
      centerTitle: true,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _userName,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.grey),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  _address.isNotEmpty ? _address : "Location not set",
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Drawer appDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Image.asset(
                      "assets/scan-logo.png",
                      width: 100,
                      height: 80,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 100,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image, size: 40),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  _drawerItem(Icons.person_outline, "My Profile", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileUpdateScreen(),
                      ),
                    );
                  }),
                  _drawerItem(Icons.book, "My Bookings", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyBookingsScreen(),
                      ),
                    );
                  }),
                  _drawerItem(Icons.health_and_safety, "Health Hub", () {
                    Navigator.pop(context);
                  }),
                  _drawerItem(Icons.message, "Second Opinion", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SecondOpinionPage(),
                      ),
                    );
                  }),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
              onTap: _logout,
            )
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback? onTap) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
        const Divider(height: 1),
      ],
    );
  }
}
