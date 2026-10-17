import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/health_hub_service.dart';
import '../models/video_model.dart';
import '../models/video_category_model.dart';
import '../widgets/youtube_player_widget.dart';
import '../services/location_service.dart';
import '../widgets/health_hub_slider.dart';
import '../widgets/video_thumbnail.dart';
import '../widgets/common_drawer.dart';
import 'scanner_screen.dart';
import '../utils/deeplink_nav.dart';
import '../widgets/app_bottom_nav.dart';

class HealthHubVideoScreen extends StatefulWidget {
  const HealthHubVideoScreen({super.key});

  @override
  State<HealthHubVideoScreen> createState() => _HealthHubVideoScreenState();
}

class _HealthHubVideoScreenState extends State<HealthHubVideoScreen> {
  List<Video> allVideos = [];
  List<Video> filteredVideos = [];
  List<VideoCategory> categories = [];

  bool isLoading = true;
  bool isLoadingMore = false;

  int selectedCategory = -1;
  String searchText = "";

  String _userName = "Guest";
  String _address = "";

  int currentPage = 1;
  int lastPage = 1;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadVideos();
    _loadSavedLocation();
    _loadUserData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!isLoadingMore && currentPage < lastPage) {
        loadMoreVideos();
      }
    }
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

  Future<void> loadVideos({int? categoryId}) async {
    setState(() {
      isLoading = true;
      currentPage = 1;
      allVideos.clear();
      filteredVideos.clear();
    });

    final data = await HealthHubService.fetchVideos(
      categoryId: categoryId,
      page: 1,
    );

    setState(() {
      allVideos = data["videos"];
      categories = data["categories"];
      currentPage = data["currentPage"];
      lastPage = data["lastPage"];
      isLoading = false;
    });

    _applyFilters();
  }

  Future<void> loadMoreVideos() async {
    if (isLoadingMore) return;

    setState(() {
      isLoadingMore = true;
    });

    final nextPage = currentPage + 1;

    final data = await HealthHubService.fetchVideos(
      categoryId: selectedCategory != -1 ? selectedCategory : null,
      page: nextPage,
    );

    setState(() {
      allVideos.addAll(data["videos"]);
      currentPage = data["currentPage"];
      lastPage = data["lastPage"];
      isLoadingMore = false;
    });

    _applyFilters();
  }

  /// ✅ FIXED FILTER LOGIC
  void _applyFilters() {
    List<Video> temp = List.from(allVideos);

    // Category Filter
    if (selectedCategory != -1) {
      temp = temp.where((v) {
        return v.category?.id == selectedCategory;
      }).toList();
    }

    // Search Filter
    if (searchText.isNotEmpty) {
      temp = temp.where((v) {
        return (v.title ?? "").toLowerCase().contains(searchText.toLowerCase());
      }).toList();
    }

    setState(() {
      filteredVideos = temp;
    });
  }

  /// ✅ FIXED CATEGORY TAP
  void _onCategoryTap(int categoryId) {
    setState(() {
      selectedCategory = categoryId;
      searchText = "";
      searchController.clear();
    });

    loadVideos(categoryId: categoryId == -1 ? null : categoryId);
  }

  void _onSearchChanged(String value) {
    setState(() {
      searchText = value;
    });

    _applyFilters();
  }

  void _playVideo(String videoId, String title) {
    if (videoId.isEmpty) return;
    YoutubePlayerWidget.open(
      context,
      videoId: videoId,
      videoTitle: title,
    );
  }

  String? _extractYoutubeIdFromUrl(String url) {
    if (url.isEmpty) return null;

    final RegExp regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
    );

    final match = regExp.firstMatch(url);
    return match?.group(1);
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
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: "Search videos...",
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
                    GestureDetector(
                      onTap: () => _onCategoryTap(-1),
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
                    ...categories.map((cat) {
                      final isSelected = selectedCategory == cat.id;

                      return GestureDetector(
                        onTap: () => _onCategoryTap(cat.id!),
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
                            cat.categoryName ?? "",
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              /// VIDEO LIST
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredVideos.isEmpty
                        ? const Center(
                            child: Text(
                              "No videos found",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount:
                                filteredVideos.length + (isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == filteredVideos.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final video = filteredVideos[index];

                              String? videoId = video.youtubeVideoId;

                              if (videoId == null || videoId.isEmpty) {
                                videoId = _extractYoutubeIdFromUrl(
                                    video.youtubeUrl ?? '');
                              }

                              if (videoId == null || videoId.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return VideoThumbnail(
                                thumbnailUrl: video.thumbnail ??
                                    'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
                                videoTitle: video.title ?? "Untitled",
                                videoId: videoId,
                                authorName: video.authorName,
                                publishedDate: video.publishedDate,
                                onTap: () => _playVideo(
                                    videoId!, video.title ?? "Video"),
                              );
                            },
                          ),
              ),
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

  /// APP BAR
  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0x1F62C6FF),
      centerTitle: true,
      title: Column(
        children: [
          Text(
            _userName,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.w600),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, size: 14),
              Flexible(
                child: Text(
                  _address.isNotEmpty ? _address : "Location not set",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
