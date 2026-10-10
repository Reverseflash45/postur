import 'package:flutter/material.dart';

/// Warna dengan arti tetap di seluruh aplikasi.
abstract final class Warna {
  /// Aksen utama: hijau toska, sama dengan tab Workout di aplikasi Tracking.
  static const utama = Color(0xFF0B7A66);

  /// Repetisi benar.
  static const benar = Color(0xFF1FA35C);

  /// Repetisi dengan kesalahan postur.
  static const salah = Color(0xFFE8742F);

  /// Rekaman berjalan.
  static const rekam = Color(0xFFE5484D);

  /// Latar layar kamera dan kerangka saat bergerak.
  static const malam = Color(0xFF0A0F0E);
  static const kerangka = Color(0xFF7CF5D4);

  /// Warna kelas: benar hijau, kesalahan bergradasi jingga–merah muda
  /// supaya tiap jenis kesalahan bisa dibedakan di grafik.
  static Color kelas(int i) => switch (i) {
    0 => benar,
    1 => salah,
    2 => const Color(0xFFD9466B),
    3 => const Color(0xFF8F5BD8),
    _ => Colors.grey,
  };
}

ThemeData buatTema(Brightness b) {
  final skema = ColorScheme.fromSeed(seedColor: Warna.utama, brightness: b);
  final gelap = b == Brightness.dark;
  return ThemeData(
    colorScheme: skema,
    useMaterial3: true,
    scaffoldBackgroundColor: gelap
        ? const Color(0xFF0E1312)
        : const Color(0xFFF5F7F6),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: skema.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: gelap ? const Color(0xFF171E1C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: skema.outlineVariant.withValues(alpha: gelap ? 0.4 : 0.6),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}

/// Judul bagian di dalam daftar.
class JudulBagian extends StatelessWidget {
  const JudulBagian(this.teks, {super.key, this.aksi, this.onAksi});

  final String teks;
  final String? aksi;
  final VoidCallback? onAksi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (aksi != null)
            TextButton(
              onPressed: onAksi,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: Text(aksi!),
            ),
        ],
      ),
    );
  }
}
