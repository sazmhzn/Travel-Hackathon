import 'package:flutter/material.dart';

/// Raw brand palette. Never use these directly in feature code — read semantic
/// tokens from `AppSemanticColors` via `context.semanticColors` instead.
///
/// Ramps follow a 0 (lightest) → 95/100 (darkest) step so both light and dark
/// themes can pick from the same family.
class AppColors {
  AppColors._();

  // ─── Teal (brand) ─────────────────────────────────────────
  static const Color teal0 = Color(0xFFE6F4F2);
  static const Color teal10 = Color(0xFFC2E5E0);
  static const Color teal20 = Color(0xFF99D3CB);
  static const Color teal30 = Color(0xFF5FB8AC);
  static const Color teal40 = Color(0xFF2E9E8D);
  static const Color teal50 = Color(0xFF0F766E);
  static const Color teal60 = Color(0xFF0B635C);
  static const Color teal70 = Color(0xFF09514B);
  static const Color teal80 = Color(0xFF073F3A);
  static const Color teal90 = Color(0xFF052E2B);
  static const Color teal95 = Color(0xFF031F1D);

  // ─── Orange (safety accent) ───────────────────────────────
  static const Color orange0 = Color(0xFFFDEADE);
  static const Color orange10 = Color(0xFFFBD5BC);
  static const Color orange20 = Color(0xFFF8B98E);
  static const Color orange30 = Color(0xFFF59B5F);
  static const Color orange40 = Color(0xFFF17D34);
  static const Color orange50 = Color(0xFFEA580C);
  static const Color orange60 = Color(0xFFC74A09);
  static const Color orange70 = Color(0xFFA43C08);
  static const Color orange80 = Color(0xFF7E2D06);
  static const Color orange90 = Color(0xFF571F04);
  static const Color orange95 = Color(0xFF331203);

  // ─── Red (danger) ─────────────────────────────────────────
  static const Color red0 = Color(0xFFFDE8E8);
  static const Color red10 = Color(0xFFFBCFCF);
  static const Color red20 = Color(0xFFF7ABAB);
  static const Color red30 = Color(0xFFF27A7A);
  static const Color red40 = Color(0xFFEC4B4B);
  static const Color red50 = Color(0xFFDC2626);
  static const Color red60 = Color(0xFFB91C1C);
  static const Color red70 = Color(0xFF991B1B);
  static const Color red80 = Color(0xFF7F1D1D);
  static const Color red90 = Color(0xFF5C1515);
  static const Color red95 = Color(0xFF3B0E0E);

  // ─── Yellow (warning) ─────────────────────────────────────
  static const Color yellow0 = Color(0xFFFEF3D6);
  static const Color yellow10 = Color(0xFFFDE7AD);
  static const Color yellow20 = Color(0xFFFBD57A);
  static const Color yellow30 = Color(0xFFF8C24A);
  static const Color yellow40 = Color(0xFFF4AD1C);
  static const Color yellow50 = Color(0xFFD97706);
  static const Color yellow60 = Color(0xFFB45309);
  static const Color yellow70 = Color(0xFF92400E);
  static const Color yellow80 = Color(0xFF78350F);
  static const Color yellow90 = Color(0xFF571F0A);
  static const Color yellow95 = Color(0xFF331203);

  // ─── Green (success) ──────────────────────────────────────
  static const Color green0 = Color(0xFFE6F6EE);
  static const Color green10 = Color(0xFFC3EBD6);
  static const Color green20 = Color(0xFF9ADFBC);
  static const Color green30 = Color(0xFF5ECB93);
  static const Color green40 = Color(0xFF2FB873);
  static const Color green50 = Color(0xFF16A34A);
  static const Color green60 = Color(0xFF15803D);
  static const Color green70 = Color(0xFF116632);
  static const Color green80 = Color(0xFF0E4F27);
  static const Color green90 = Color(0xFF0A381C);
  static const Color green95 = Color(0xFF061F10);

  // ─── Blue (info / link) ───────────────────────────────────
  static const Color blue0 = Color(0xFFE8EFFD);
  static const Color blue10 = Color(0xFFCFDEFB);
  static const Color blue20 = Color(0xFFA9C4F7);
  static const Color blue30 = Color(0xFF7BA4F2);
  static const Color blue40 = Color(0xFF4A7FE8);
  static const Color blue50 = Color(0xFF2563EB);
  static const Color blue60 = Color(0xFF1D4ED8);
  static const Color blue70 = Color(0xFF1E40AF);
  static const Color blue80 = Color(0xFF1B3488);
  static const Color blue90 = Color(0xFF16265F);
  static const Color blue95 = Color(0xFF0E193D);

  // ─── Neutral ──────────────────────────────────────────────
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral2 = Color(0xFFFAFAFA);
  static const Color neutral5 = Color(0xFFF7F7F7);
  static const Color neutral10 = Color(0xFFF2F4F4);
  static const Color neutral20 = Color(0xFFE6E9E9);
  static const Color neutral30 = Color(0xFFD3D8D8);
  static const Color neutral40 = Color(0xFFA6ADAD);
  static const Color neutral50 = Color(0xFF7A8383);
  static const Color neutral60 = Color(0xFF5A6363);
  static const Color neutral70 = Color(0xFF3F4646);
  static const Color neutral80 = Color(0xFF2A2F2F);
  static const Color neutral90 = Color(0xFF191D1D);
  static const Color neutral95 = Color(0xFF101313);
  static const Color neutral1000 = Color(0xFF0A0C0C);
  static const Color neutralDarkSurface = Color(0xFF161A1A);

  // ─── Alpha black ──────────────────────────────────────────
  static const Color alphaBlack0 = Color(0x00000000);
  static const Color alphaBlack10 = Color(0x1A000000);
  static const Color alphaBlack20 = Color(0x33000000);
  static const Color alphaBlack30 = Color(0x4D000000);
  static const Color alphaBlack40 = Color(0x66000000);
  static const Color alphaBlack50 = Color(0x80000000);
  static const Color alphaBlack60 = Color(0x99000000);
  static const Color alphaBlack70 = Color(0xB3000000);
  static const Color alphaBlack80 = Color(0xCC000000);
  static const Color alphaBlack90 = Color(0xE6000000);
  static const Color alphaBlack95 = Color(0xF2000000);

  // ─── Alpha white ──────────────────────────────────────────
  static const Color alphaWhite0 = Color(0x00FFFFFF);
  static const Color alphaWhite10 = Color(0x1AFFFFFF);
  static const Color alphaWhite20 = Color(0x33FFFFFF);
  static const Color alphaWhite30 = Color(0x4DFFFFFF);
  static const Color alphaWhite40 = Color(0x66FFFFFF);
  static const Color alphaWhite50 = Color(0x80FFFFFF);
  static const Color alphaWhite60 = Color(0x99FFFFFF);
  static const Color alphaWhite70 = Color(0xB3FFFFFF);
  static const Color alphaWhite80 = Color(0xCCFFFFFF);
  static const Color alphaWhite90 = Color(0xE6FFFFFF);
  static const Color alphaWhite95 = Color(0xF2FFFFFF);

  // ─── Functional map / marker colors ───────────────────────
  // These are data-encoding colors on the map, not theme chrome. Kept here so
  // no feature file hardcodes a hex again.
  static const Color mapMissing = Color(0xFFE53935);
  static const Color mapOffRoute = Color(0xFFFF3D00);
  static const Color mapGuide = Color(0xFF1D4ED8);
  static const Color mapMember = Color(0xFFEC4899);
  static const Color mapSharedLocation = Color(0xFFC026D3);
  static const Color mapSos = red50;
  static const Color mapRecording = Color(0xFF0000FF);
  static const Color mapSelfOnPath = Color(0xFF0000FF);
  static const Color mapSelfOffPath = Color(0xFFDC2626);
  static const Color mapStart = Color(0xFFFACC15);
  static const Color mapStroke = neutral0;

  // ─── Shimmer ──────────────────────────────────────────────
  static const Color shimmerBase = neutral10;
  static const Color shimmerHighlight = neutral0;
  static const Color shimmerBaseDark = Color(0xFF1C2222);
  static const Color shimmerHighlightDark = Color(0xFF2A3131);
}
