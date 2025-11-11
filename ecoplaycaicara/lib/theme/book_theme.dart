import 'package:flutter/material.dart';

class BookTheme extends ThemeExtension<BookTheme> {
  const BookTheme({
    required this.outerShadow,
    required this.outerPaperTop,
    required this.outerPaperBottom,
    required this.paperEdge,
    required this.spineDark,
    required this.spineMid,
    required this.spineHighlight,
    required this.edgeSheen,
    required this.parchment,
    required this.parchmentAlt,
    required this.vellum,
    required this.vellumAlt,
    required this.ink,
    required this.inkMuted,
    required this.accentLeather,
    required this.accentLeatherHighlight,
    required this.ribbon,
    required this.cardTop,
    required this.cardBottom,
    required this.cardOutline,
    required this.badgeFill,
    required this.badgeText,
  });

  final Color outerShadow;
  final Color outerPaperTop;
  final Color outerPaperBottom;
  final Color paperEdge;
  final Color spineDark;
  final Color spineMid;
  final Color spineHighlight;
  final Color edgeSheen;
  final Color parchment;
  final Color parchmentAlt;
  final Color vellum;
  final Color vellumAlt;
  final Color ink;
  final Color inkMuted;
  final Color accentLeather;
  final Color accentLeatherHighlight;
  final Color ribbon;
  final Color cardTop;
  final Color cardBottom;
  final Color cardOutline;
  final Color badgeFill;
  final Color badgeText;

  static const BookTheme standard = BookTheme(
    outerShadow: Color(0x33000000),
    outerPaperTop: Color(0xFFF6E5C8),
    outerPaperBottom: Color(0xFFE8CAA0),
    paperEdge: Color(0xFFB98B58),
    spineDark: Color(0xFF6D4221),
    spineMid: Color(0xFF8A5829),
    spineHighlight: Color(0xFFC18245),
    edgeSheen: Color(0xFFE5C68F),
    parchment: Color(0xFFF8ECD3),
    parchmentAlt: Color(0xFFEED7AF),
    vellum: Color(0xFFF2E3C5),
    vellumAlt: Color(0xFFE3CFA3),
    ink: Color(0xFF2F1E13),
    inkMuted: Color(0xFF5B4330),
    accentLeather: Color(0xFF9C642F),
    accentLeatherHighlight: Color(0xFFC78544),
    ribbon: Color(0xFFDDBF80),
    cardTop: Color(0xFFFBF2DE),
    cardBottom: Color(0xFFF0DEBC),
    cardOutline: Color(0xFFB48856),
    badgeFill: Color(0xFFF4E6C8),
    badgeText: Color(0xFF4E3623),
  );

  @override
  BookTheme copyWith({
    Color? outerShadow,
    Color? outerPaperTop,
    Color? outerPaperBottom,
    Color? paperEdge,
    Color? spineDark,
    Color? spineMid,
    Color? spineHighlight,
    Color? edgeSheen,
    Color? parchment,
    Color? parchmentAlt,
    Color? vellum,
    Color? vellumAlt,
    Color? ink,
    Color? inkMuted,
    Color? accentLeather,
    Color? accentLeatherHighlight,
    Color? ribbon,
    Color? cardTop,
    Color? cardBottom,
    Color? cardOutline,
    Color? badgeFill,
    Color? badgeText,
  }) {
    return BookTheme(
      outerShadow: outerShadow ?? this.outerShadow,
      outerPaperTop: outerPaperTop ?? this.outerPaperTop,
      outerPaperBottom: outerPaperBottom ?? this.outerPaperBottom,
      paperEdge: paperEdge ?? this.paperEdge,
      spineDark: spineDark ?? this.spineDark,
      spineMid: spineMid ?? this.spineMid,
      spineHighlight: spineHighlight ?? this.spineHighlight,
      edgeSheen: edgeSheen ?? this.edgeSheen,
      parchment: parchment ?? this.parchment,
      parchmentAlt: parchmentAlt ?? this.parchmentAlt,
      vellum: vellum ?? this.vellum,
      vellumAlt: vellumAlt ?? this.vellumAlt,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      accentLeather: accentLeather ?? this.accentLeather,
      accentLeatherHighlight:
          accentLeatherHighlight ?? this.accentLeatherHighlight,
      ribbon: ribbon ?? this.ribbon,
      cardTop: cardTop ?? this.cardTop,
      cardBottom: cardBottom ?? this.cardBottom,
      cardOutline: cardOutline ?? this.cardOutline,
      badgeFill: badgeFill ?? this.badgeFill,
      badgeText: badgeText ?? this.badgeText,
    );
  }

  @override
  ThemeExtension<BookTheme> lerp(ThemeExtension<BookTheme>? other, double t) {
    if (other is! BookTheme) return this;
    return BookTheme(
      outerShadow: Color.lerp(outerShadow, other.outerShadow, t)!,
      outerPaperTop: Color.lerp(outerPaperTop, other.outerPaperTop, t)!,
      outerPaperBottom: Color.lerp(
        outerPaperBottom,
        other.outerPaperBottom,
        t,
      )!,
      paperEdge: Color.lerp(paperEdge, other.paperEdge, t)!,
      spineDark: Color.lerp(spineDark, other.spineDark, t)!,
      spineMid: Color.lerp(spineMid, other.spineMid, t)!,
      spineHighlight: Color.lerp(spineHighlight, other.spineHighlight, t)!,
      edgeSheen: Color.lerp(edgeSheen, other.edgeSheen, t)!,
      parchment: Color.lerp(parchment, other.parchment, t)!,
      parchmentAlt: Color.lerp(parchmentAlt, other.parchmentAlt, t)!,
      vellum: Color.lerp(vellum, other.vellum, t)!,
      vellumAlt: Color.lerp(vellumAlt, other.vellumAlt, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      accentLeather: Color.lerp(accentLeather, other.accentLeather, t)!,
      accentLeatherHighlight: Color.lerp(
        accentLeatherHighlight,
        other.accentLeatherHighlight,
        t,
      )!,
      ribbon: Color.lerp(ribbon, other.ribbon, t)!,
      cardTop: Color.lerp(cardTop, other.cardTop, t)!,
      cardBottom: Color.lerp(cardBottom, other.cardBottom, t)!,
      cardOutline: Color.lerp(cardOutline, other.cardOutline, t)!,
      badgeFill: Color.lerp(badgeFill, other.badgeFill, t)!,
      badgeText: Color.lerp(badgeText, other.badgeText, t)!,
    );
  }
}
