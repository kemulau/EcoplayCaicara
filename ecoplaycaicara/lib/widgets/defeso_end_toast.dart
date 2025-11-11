import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Mostra “Defeso encerrado...” quando [defesoAtivo] muda de true -> false.
/// Ignora cliques e some sozinho após o fade-out.
class DefesoEndToast extends StatefulWidget {
  const DefesoEndToast({
    super.key,
    required this.defesoAtivo,
    this.fadeIn = const Duration(milliseconds: 220),
    this.hold = const Duration(milliseconds: 1600),
    this.fadeOut = const Duration(milliseconds: 260),
    this.bottomPadding = 16,
  });

  final ValueListenable<bool> defesoAtivo;
  final Duration fadeIn;
  final Duration hold;
  final Duration fadeOut;
  final double bottomPadding;

  @override
  State<DefesoEndToast> createState() => _DefesoEndToastState();
}

class _DefesoEndToastState extends State<DefesoEndToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late bool _lastActive;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: 0,
      lowerBound: 0,
      upperBound: 1,
      duration: const Duration(milliseconds: 220),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _lastActive = widget.defesoAtivo.value;
    widget.defesoAtivo.addListener(_onDefesoChanged);
  }

  @override
  void didUpdateWidget(covariant DefesoEndToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defesoAtivo != widget.defesoAtivo) {
      oldWidget.defesoAtivo.removeListener(_onDefesoChanged);
      _lastActive = widget.defesoAtivo.value;
      widget.defesoAtivo.addListener(_onDefesoChanged);
    }
  }

  void _onDefesoChanged() {
    final cur = widget.defesoAtivo.value;
    if (_lastActive && !cur) {
      _showToast();
    }
    _lastActive = cur;
  }

  Future<void> _showToast() async {
    _holdTimer?.cancel();
    _controller.stop();
    _controller.value = 0;

    await _controller.animateTo(1.0, duration: widget.fadeIn);
    _holdTimer = Timer(widget.hold, () async {
      if (!mounted) return;
      await _controller.animateTo(0.0, duration: widget.fadeOut);
    });
  }

  @override
  void dispose() {
    widget.defesoAtivo.removeListener(_onDefesoChanged);
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.bottomPadding),
            child: FadeTransition(
              opacity: _fade,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  border: Border.all(color: const Color(0xFF7A4E2F), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      offset: const Offset(2, 3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Text(
                  'Defeso encerrado! Você pode capturar novamente.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3E40),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
