import 'package:flutter/material.dart';
import '../models/faq.dart';

class FaqSection extends StatefulWidget {
  const FaqSection({super.key});

  @override
  State<FaqSection> createState() => _FaqSectionState();
}

class _FaqSectionState extends State<FaqSection> {
  final List<FaqItem> faqList = [
    FaqItem(
      question: "How do I book an appointment?",
      answer:
          "Yes, simply visit our website and log in or create an account. Search for a doctor based on specialization, location, or availability & confirm your booking. ",
      isExpanded: true,
    ),
    FaqItem(
      question:
          "Can i make an Appointment Online with White Plains Hospital Kendi?",
      answer: "Yes, simply visit our website and log in or create an account. Search for a doctor based on specialization, location, or availability & confirm your booking.",
    ),
    FaqItem(
      question: "Is my personal information secure?",
      answer: "Yes, simply visit our website and log in or create an account. Search for a doctor based on specialization, location, or availability & confirm your booking. ",
    ),
    FaqItem(
      question: "Can I cancel or reschedule my appointment?",
      answer:
          "Yes, simply visit our website and log in or create an account. Search for a doctor based on specialization, location, or availability & confirm your booking. ",
    ),
    FaqItem(
      question: "How do I find a specific doctor or specialist?",
      answer:
          "Yes, simply visit our website and log in or create an account. Search for a doctor based on specialization, location, or availability & confirm your booking. ",
    ),
  ];

  void _toggleItem(int index) {
    setState(() {
      for (int i = 0; i < faqList.length; i++) {
        if (i == index) {
          faqList[i].isExpanded = !faqList[i].isExpanded;
        } else {
          faqList[i].isExpanded = false; // close others
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(faqList.length, (index) {
        final item = faqList[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8EFF7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                title: Text(
                  item.question,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: GestureDetector(
                  onTap: () => _toggleItem(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      item.isExpanded ? Icons.remove : Icons.add,
                      size: 20,
                    ),
                  ),
                ),
              ),

              if (item.isExpanded)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    item.answer,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}