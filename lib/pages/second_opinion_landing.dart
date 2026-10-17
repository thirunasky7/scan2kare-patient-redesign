import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'faq_section.dart';
import 'second_opinion_page.dart';
import '../config/api_config.dart';

class SecondOptionScreen extends StatefulWidget {
  const SecondOptionScreen({super.key});

  @override
  State<SecondOptionScreen> createState() => _SecondOptionScreenState();
}

class _SecondOptionScreenState extends State<SecondOptionScreen> {
  int selectedOption = 0;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController altPhoneController = TextEditingController();

  Widget optionCard(int index, String title, IconData icon) {
    bool isSelected = selectedOption == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedOption = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.blue : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget textField(String hint, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  void submit() {
    print("Option: $selectedOption");
    print("Name: ${nameController.text}");
    print("Phone: ${phoneController.text}");
    print("Alt Phone: ${altPhoneController.text}");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Submitted successfully")),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    altPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Second Opinion"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            infoCard(
              title: "Welcome to Second Opinion",
              subtitle: "",
              description:
                  "Get trusted medical guidance from top specialists worldwide, helping you make confident and informed health decisions",
              bgColor: const Color(0xff579ac6), // light beige
            ),
            infoCard(
              title: "Trusted Expert Review",
              subtitle: "Verified Specialists Across Multiple Countries",
              description:
                  "Get your medical reports evaluated by top-certified doctors worldwide, ensuring accurate and unbiased guidance you can trust.",
              bgColor: const Color(0xFFE6D6CF), // light beige
            ),
            infoCard(
              title: "AI-Powered Clarity",
              subtitle: "Smart Insights Before You See the Doctor",
              description:
                  "Our AI analyzes your reports, highlights key findings, and helps match you with the right specialist instantly.",
              bgColor: const Color(0xFFD6E3E8), // light blue
            ),
            infoCard(
              title: "Confident Health Decisions",
              subtitle: "Clear, Actionable Second Opinion Reports",
              description:
                  "Receive easy-to-understand expert recommendations, treatment comparisons, and next steps—empowering you to make informed decisions.",
              bgColor: Colors.white70, // light blue
            ),
            const SizedBox(height: 35),
            const Text(
              "Get Expert Opinions by Health Category",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const Text(
                "Explore a wide range of medical categories tailored to your specific health concerns. Our platform securely analyzes your reports and connects you with top specialist doctors for unbiased second opinions. Each review provides clear guidance, treatment comparisons, and expert-recommended next steps. We are committed to giving you clarity, confidence, and the right direction for your health decisions. Choose the category that best matches your condition to begin."),
            const SizedBox(height: 35),
            medicalCard(
              image:
                  "${ApiConfig.siteUrl}/public/assets/images/second-opinion/Cardiology.png",
              title: "Cardiology",
              subtitle: "(Heart Problems)",
            ),
            medicalCard(
              image:
                  "${ApiConfig.siteUrl}/public/assets/images/second-opinion/Neurology.png",
              title: "Neurology",
              subtitle: "(Brain & Nerve Disorders)",
            ),
            medicalCard(
              image:
                  "${ApiConfig.siteUrl}/public/assets/images/second-opinion/Orthopedics.png",
              title: "Orthopedics",
              subtitle: "(Bone & Joint Issues)",
            ),
            medicalCard(
              image:
                  "${ApiConfig.siteUrl}/public/assets/images/second-opinion/Oncology.png",
              title: "Oncology",
              subtitle: "(Cancer)",
            ),
            medicalCard(
              image:
                  "${ApiConfig.siteUrl}/public/assets/images/second-opinion/Nephrology.png",
              title: "Nephrology",
              subtitle: "(Kidney Issues)",
            ),
            medicalCard(
              image:
                  "${ApiConfig.siteUrl}/public/assets/images/second-opinion/Gastroenterology.png",
              title: "Gastroenterology",
              subtitle: "(Digestive Disorders)",
            ),
            medicalCard(
              image:
                  "${ApiConfig.siteUrl}/public/assets/images/second-opinion/Endocrinology.png",
              title: "Endocrinology",
              subtitle: "(Diabetes & Hormonal Disorders)",
            ),
            medicalCard(
              image:
                  "${ApiConfig.siteUrl}/public/assets/images/second-opinion/Rheumatology.png",
              title: "Rheumatology",
              subtitle: "(Arthritis & Autoimmune Conditions)",
            ),
            medicalCard(
              image:
                  "${ApiConfig.siteUrl}/public/assets/images/second-opinion/Dermatology.png",
              title: "Dermatology",
              subtitle: "(Skin Conditions)",
            ),
            const SizedBox(height: 35),
            networkCard(
              title: "Second Opinion – India Network",
              subtitle: "Fast report uploads & instant AI analysis",
              gradientColors: [
                const Color(0xFF1C8E7C),
                const Color(0xFF1FA187),
              ],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SecondOpinionPage(network: 'India'),
                ),
              ),
            ),
            networkCard(
              title: "Second Opinion – U.S. Network",
              subtitle: "Reviewed by board-certified U.S. doctors",
              gradientColors: [
                const Color(0xFF7B2CBF),
                const Color(0xFF9D4EDD),
              ],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SecondOpinionPage(network: 'U.S.'),
                ),
              ),
            ),
            const SizedBox(height: 35),
            answerSection(),
          ],
        ),
      ),
    );
  }

  Widget infoCard({
    required String title,
    required String subtitle,
    required String description,
    required Color bgColor,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget medicalCard({
    required String image,
    required String title,
    required String subtitle,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SecondOpinionPage(category: title),
            ),
          );
        },
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              SizedBox(
                height: 52,
                width: 52,
                child: Image.network(
                  image,
                  height: 52,
                  width: 52,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.medical_services_outlined,
                    size: 32,
                    color: Colors.grey.shade400,
                  ),
                  loadingBuilder: (context, child, progress) =>
                      progress == null
                          ? child
                          : const Center(
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2C44),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget networkCard({
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 18),
                  SizedBox(width: 6),
                  Text(
                    "Submit Reports",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget answerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 🔹 Small title
        const Text(
          "Get Your Answer",
          style: TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 6),

        // 🔹 Main heading
        const Text(
          "Frequently Searched\nSecond Opinion Procedures",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0B2C4A),
          ),
        ),

        const SizedBox(height: 20),

        // 🔹 Image stack with badge
        Stack(
          alignment: Alignment.center,
          children: [
            // BACK LAYERS (for stacked effect)
            Positioned(
              top: 5,
              child: _stackCard(offset: 20),
            ),
            Positioned(
              top: 5,
              child: _stackCard(offset: 10),
            ),

            // MAIN IMAGE CARD
            Container(
              width: 260,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: NetworkImage(
                      "${ApiConfig.siteUrl}/public/assets/img/faq-img.png"),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // 🔵 Center circle
            Positioned(
              top: -10,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: const Center(
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: Colors.blue,
                  ),
                ),
              ),
            ),

            // 😊 Bottom badge
            Positioned(
              bottom: -20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Text("😊",
                        style:
                            TextStyle(fontFamilyFallback: ['Segoe UI Emoji'])),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "95k+",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "Happy Patients",
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        const FaqSection(),
      ],
    );
  }

  Widget _stackCard({required double offset}) {
    return Container(
      width: 260,
      height: 300,
      margin: EdgeInsets.only(left: offset),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
