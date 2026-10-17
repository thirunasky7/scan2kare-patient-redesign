import 'package:flutter/material.dart';

import '../services/favorites_service.dart';

/// Heart toggle for a doctor or hospital.
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.type,
    required this.id,
    this.size = 24,
    this.padding = const EdgeInsets.all(8),
    this.background,
    this.snapshot,
  });

  /// [FavoritesService.doctor] or [FavoritesService.hospital].
  final String type;
  final int id;
  final double size;
  final EdgeInsets padding;
  final Color? background;

  /// Optional display fields stored locally so Favourites works without the API.
  final Map<String, dynamic>? snapshot;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  static const Color _activeColor = Color(0xFFE53935);
  static const Color _inactiveColor = Color(0xFF9E9E9E);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 1),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  bool _inFlight = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_inFlight) return;
    setState(() => _inFlight = true);
    _controller.forward(from: 0);

    try {
      await FavoritesService.toggle(
        type: widget.type,
        id: widget.id,
        snapshot: widget.snapshot,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update favourite. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _inFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<int>>(
      valueListenable: FavoritesService.notifierFor(widget.type),
      builder: (context, ids, _) {
        final isFavorite = ids.contains(widget.id);

        return Semantics(
          button: true,
          label: isFavorite ? 'Remove from favourites' : 'Add to favourites',
          child: InkWell(
            onTap: _inFlight ? null : _onTap,
            customBorder: const CircleBorder(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.background,
              ),
              child: Padding(
                padding: widget.padding,
                child: ScaleTransition(
                  scale: _scale,
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: widget.size,
                    color: isFavorite ? _activeColor : _inactiveColor,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
