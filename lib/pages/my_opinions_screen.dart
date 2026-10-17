import 'package:flutter/material.dart';
import '../services/opinion_service.dart';
import '../models/opinion_model.dart';
import '../widgets/second_opinion_slider.dart';
import '../widgets/connect_widget.dart';
import '../widgets/common_drawer.dart';

class MyOpinionsScreen extends StatefulWidget {
  const MyOpinionsScreen({super.key});

  @override
  State<MyOpinionsScreen> createState() => _MyOpinionsScreenState();
}

class _MyOpinionsScreenState extends State<MyOpinionsScreen> {
  List<Opinion> opinions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadOpinions();
  }

  Future<void> loadOpinions() async {
    try {
      final data = await OpinionService.fetchOpinions();

      setState(() {
        opinions = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F6F9),
      drawer: const CommonDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // leading: const BackButton(color: Colors.black),
        title: const Text(
          "Second opinion",
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: loadOpinions,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SecondOpinionSlider(),

            const SizedBox(height: 50),
            const ConnectBanner(
              image1: 'assets/01.png',
              image2: 'assets/2.png',
              height: 140,
            ),
            const SizedBox(height: 12),

            /// TITLE
            const Text(
              "My Opinion Files",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 10),

            /// LIST
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: opinions.length,
                itemBuilder: (context, index) {
                  final item = opinions[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12.withOpacity(.05),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        /// REPORT IMAGE
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            "assets/logo-icon.png",
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),

                        const SizedBox(width: 12),

                        /// TEXT
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${item.firstName} ${item.lastName}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Created on ${item.createdAt.split('T')[0]}",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              //const SizedBox(height: 6),
                              // const Text(
                              //   "Book Now",
                              //   style: TextStyle(
                              //     color: Colors.blue,
                              //     fontSize: 13,
                              //   ),
                              // ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
              )
          ],
        ),
        ),
      ),
    );
  }

  Widget _optionCard({
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11),
          )
        ],
      ),
    );
  }
}
