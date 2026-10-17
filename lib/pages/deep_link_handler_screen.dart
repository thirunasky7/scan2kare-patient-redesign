import 'package:flutter/material.dart';
import '../services/deep_link_service.dart';

class DeepLinkHandlerScreen extends StatefulWidget {
  final Uri uri;

  const DeepLinkHandlerScreen({
    super.key,
    required this.uri,
  });

  @override
  State<DeepLinkHandlerScreen> createState() => _DeepLinkHandlerScreenState();
}

class _DeepLinkHandlerScreenState extends State<DeepLinkHandlerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.handleUri(widget.uri);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
