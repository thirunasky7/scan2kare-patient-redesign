import 'package:flutter/material.dart';
import 'gyno_byte.dart';

class MedGenomeScreen extends StatelessWidget {
  const MedGenomeScreen({super.key});

  static const Color _teal = Color(0xFF2B6F71);
  static const Color _navy = Color(0xFF2B3A67);
  static const Color _deepTeal = Color(0xFF014652);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text("MedGenome"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/gradient.png',
              fit: BoxFit.cover,
            ),
          ),
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hero(context),
                _aboutSection(),
                _statsSection(),
                _solutionsSection(),
                _whyChooseSection(),
                _howItWorksSection(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: const Color(0xFFEAEFF3),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "Precision Genomics for Proactive Care",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "About MedGenome",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "South Asia's largest CAP-accredited laboratory and a leader in omics and diagnostic testing, delivering global-quality, affordable genomics.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GenoByteScreen(
                    title: "MedGenome",
                  ),
                ),
              );
            },
            child: const Text(
              "Book a Consultation",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Trusted genomics partner",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Headquartered in Bengaluru, MedGenome has supported 1M+ patients, partnered with 24,000+ clinicians and 8,000+ hospitals, and offers 1,300+ genetic tests across 600+ locations and ~40 countries.",
            style: TextStyle(
              fontSize: 13,
              color: Colors.black87.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsSection() {
    const stats = [
      ("1M+", "Patients"),
      ("24K+", "Clinicians"),
      ("8K+", "Hospitals"),
      ("1300+", "Genetic Tests"),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
        children: stats
            .map(
              (s) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      s.$1,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _teal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.$2,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _solutionsSection() {
    const solutions = [
      (
        "Claria NIPT",
        "Non-Invasive Prenatal Screening",
        [
          "India's 1st validated NIPT",
          "100,000+ samples analyzed",
          "iFACT® powered accuracy",
          "Low false positive rates",
          "CAP-accredited testing",
        ],
      ),
      (
        "Kardiogen Plus",
        "Heart Health Risk Assessment",
        [
          "1.3 million genetic variants",
          "CAD risk identification",
          "Personalized preventive insights",
          "Integrated risk evaluation",
        ],
      ),
      (
        "ExomeMAX",
        "Rare Genetic Disorders",
        [
          "Enhanced gene coverage",
          "Improved diagnostic yield",
          "Mitochondrial genome analysis",
          "CAP validated testing",
        ],
      ),
      (
        "Fitgen",
        "Obesity & BMI Screening",
        [
          "2 million genetic markers",
          "Personalized obesity assessment",
          "Lifestyle recommendations",
        ],
      ),
      (
        "Hereditary Cancer Gene Panel",
        "Inherited Cancer Risk Assessment",
        [
          "Multi-gene screening",
          "Early detection support",
          "Family risk insights",
          "Clinically actionable reports",
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 28, 20, 6),
          child: Text(
            "Featured Precision Genomics Solutions",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "Advanced genetic testing solutions designed to empower proactive healthcare decisions.",
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
          ),
        ),
        const SizedBox(height: 12),
        ...solutions.map(
          (s) => _solutionCard(title: s.$1, subtitle: s.$2, bullets: s.$3),
        ),
      ],
    );
  }

  Widget _solutionCard({
    required String title,
    required String subtitle,
    required List<String> bullets,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _deepTeal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _navy,
            ),
          ),
          const SizedBox(height: 10),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("•  ", style: TextStyle(color: _teal)),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.black87,
                        height: 1.35,
                      ),
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

  Widget _whyChooseSection() {
    const items = [
      (
        Icons.verified_outlined,
        "CAP Accredited Excellence",
        "Globally validated quality standards and laboratory excellence.",
      ),
      (
        Icons.psychology_outlined,
        "Advanced Bioinformatics",
        "AI/ML-enabled genomic interpretation and clinical insights.",
      ),
      (
        Icons.groups_outlined,
        "Trusted Clinical Network",
        "24,000+ clinicians and 8,000+ hospitals trust MedGenome.",
      ),
      (
        Icons.science_outlined,
        "Comprehensive Portfolio",
        "1,300+ genetic tests across multiple healthcare specialties.",
      ),
    ];

    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          color: const Color(0xFF2F7D8C),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            children: [
              const Text(
                "Why Choose MedGenome?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Science. Accuracy. Trust.",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 18),
              ...items.map(
                (item) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.$1, color: Colors.white, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$2,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.$3,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _howItWorksSection() {
    const steps = [
      ("1", "Sample Collection"),
      ("2", "Genomic Analysis"),
      ("3", "Clinical Reporting"),
      ("4", "Personalized Insights"),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "How it works",
              style: TextStyle(
                color: Colors.green.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Just 4 simple steps",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2A5A),
            ),
          ),
          const SizedBox(height: 18),
          ...steps.map(
            (step) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _teal,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      step.$1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    step.$2,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _navy,
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
}
