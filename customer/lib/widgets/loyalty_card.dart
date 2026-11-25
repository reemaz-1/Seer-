import 'package:flutter/material.dart';

import '../controllers/loyalty_controller.dart';
import '../theme/app_colors.dart';

/// VIEW: the navy loyalty card with a timeline of cars that leads to a
/// free car wash (#68, #70).
class LoyaltyCard extends StatefulWidget {
  /// Takes the customer id, the free wash action and an optional
  /// controller; creates the card.
  const LoyaltyCard({
    super.key,
    required this.uid,
    this.onRequestFreeWash,
    this.controller,
  });

  final String uid;

  /// Opens the car wash request once the card is full.
  final VoidCallback? onRequestFreeWash;
  final LoyaltyController? controller;

  /// Takes no inputs; creates the card state.
  @override
  State<LoyaltyCard> createState() => _LoyaltyCardState();
}

class _LoyaltyCardState extends State<LoyaltyCard> {
  static const _gold = Color(0xFFF5A623);
  static const _onGold = Color(0xFF3A2600);
  static const _subText = Color(0xFFAEB8CE);
  static const _node = 34.0;
  static const _nodeWidth = 46.0;
  static const _carImage = 'assets/icon/loyalty_car.png';
  static const _giftNode = 40.0;

  // Created once so rebuilds of the home page do not restart the query.
  late final Stream<LoyaltyProgress> _progress =
      (widget.controller ?? LoyaltyController()).watch(widget.uid);

  /// Takes context; returns the card, or nothing while loading or on error.
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LoyaltyProgress>(
      stream: _progress,
      builder: (context, snapshot) {
        final progress = snapshot.data;
        if (progress == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            color: CustomerColors.darkPanel,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(progress),
              const SizedBox(height: 18),
              Semantics(
                label: progress.semanticsLabel,
                excludeSemantics: true,
                child: _timeline(progress),
              ),
              // Free washes waiting to be used (#66).
              if (progress.hasFreeWash) ...[
                const SizedBox(height: 14),
                Text(
                  progress.availableLabel!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _gold,
                  ),
                ),
                const SizedBox(height: 8),
                _freeWashButton(),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Takes the progress; returns the gift icon, title, message and counter.
  Widget _header(LoyaltyProgress progress) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.card_giftcard_rounded,
            size: 24,
            color: _gold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                progress.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                progress.message,
                style: const TextStyle(fontSize: 12.5, color: _subText),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            progress.counter,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// Takes the progress; returns the numbered car stops joined by links,
  /// then the gift. A link is colored once the stop before it is done.
  Widget _timeline(LoyaltyProgress progress) {
    final children = <Widget>[];
    for (var i = 1; i <= LoyaltyProgress.goal; i++) {
      final done = i <= progress.filled;
      children
        ..add(_carStep(i, done))
        ..add(_link(done));
    }
    children.add(_giftStep(progress.hasFreeWash));
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  /// Takes whether it is reached; returns the link between two stops.
  Widget _link(bool reached) {
    return Expanded(
      child: Container(
        height: 4,
        margin: const EdgeInsets.only(top: 15),
        color: reached
            ? CustomerColors.accent
            : Colors.white.withValues(alpha: 0.18),
      ),
    );
  }

  /// Takes the number and whether it is done; returns one car stop.
  Widget _carStep(int number, bool done) {
    return _step(
      node: Container(
        // A wide pill so the car silhouette is not squeezed.
        width: _nodeWidth,
        height: _node,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_node / 2),
          color: done
              ? CustomerColors.accent
              : Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            width: 1.5,
            color: done
                ? CustomerColors.accent
                : Colors.white.withValues(alpha: 0.28),
          ),
          boxShadow: done
              ? [
                  BoxShadow(
                    color: CustomerColors.accent.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        // The car silhouette is white; its color comes from here.
        child: Image.asset(
          _carImage,
          fit: BoxFit.contain,
          color: done ? Colors.white : Colors.white.withValues(alpha: 0.45),
          colorBlendMode: BlendMode.srcIn,
        ),
      ),
      label: '$number',
      labelColor: done ? Colors.white : Colors.white.withValues(alpha: 0.5),
    );
  }

  /// Takes whether it is earned; returns the gold gift stop at the end.
  Widget _giftStep(bool earned) {
    return Transform.translate(
      offset: const Offset(0, -3),
      child: _step(
        node: Container(
          width: _giftNode,
          height: _giftNode,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: earned ? _gold : _gold.withValues(alpha: 0.12),
            border: Border.all(
              width: 1.5,
              color: earned ? _gold : _gold.withValues(alpha: 0.6),
            ),
            boxShadow: earned
                ? [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.card_giftcard_rounded,
            size: 23,
            color: earned ? _onGold : _gold,
          ),
        ),
        label: 'مجاني',
        labelColor: _gold,
      ),
    );
  }

  /// Takes a node, its label and color; returns the node over its label.
  Widget _step({
    required Widget node,
    required String label,
    required Color labelColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        node,
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: labelColor,
          ),
        ),
      ],
    );
  }

  /// Takes no inputs; returns the gold button shown on a full card.
  Widget _freeWashButton() {
    return FilledButton(
      onPressed: widget.onRequestFreeWash,
      style: FilledButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: _onGold,
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      child: const Text('احجز الخدمة'),
    );
  }
}
