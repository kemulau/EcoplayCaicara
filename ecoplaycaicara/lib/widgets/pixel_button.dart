import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PixelButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final double width;
  final double height;

  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width = 220,
    this.height = 56,
  });

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: _isPressed
              ? const Color(0xFFECA400) 
              : const Color(0xFF8B4B35), 
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Color(0xFF442A1B),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              offset: const Offset(4, 4),
              color: Colors.black.withOpacity(0.6),
              blurRadius: 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label.toUpperCase(),
          style: GoogleFonts.pressStart2p(
            fontSize: 11,
            color: Colors.white,
            shadows: const [
              Shadow(
                offset: Offset(1, 1),
                color: Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
