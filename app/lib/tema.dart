import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sistem tampilan Postur: panel instrumen lab biomekanik.
///
/// Gelap karena layar utamanya adalah kamera, dan data berwarna lebih
/// terbaca di atas latar gelap. Satu aksen (kuning sinyal) untuk aksi dan
/// target; hijau dan koral hanya untuk arti benar/salah. Angka memakai
/// huruf condensed, label memakai mono huruf kapital, batas memakai garis
/// rambut dan sudut kecil, bukan kartu membulat.
abstract final class Pal {
  static const latar = Color(0xFF0C0E0F);
  static const lapis = Color(0xFF141719);
  static const lapis2 = Color(0xFF1B1F22);
  static const garis = Color(0xFF262B2F);
  static const garisKuat = Color(0xFF363C41);
  static const kapur = Color(0xFFF1EFE8);
  static const redup = Color(0xFF9AA0A5);
  static const samar = Color(0xFF5F666C);
  static const sinyal = Color(0xFFFFC93C);
  static const benar = Color(0xFF3DD68C);
  static const salah = Color(0xFFFF6B57);
  static const rekam = Color(0xFFFF4D5E);

  /// Warna per kelas: benar hijau, tiap jenis kesalahan punya rona sendiri.
  static Color kelas(int i) => switch (i) {
    0 => benar,
    1 => salah,
    2 => const Color(0xFFFF5FA2),
    3 => const Color(0xFF9D8CFF),
    _ => samar,
  };
}

/// Nama lama, dipertahankan supaya pemakaian lama tetap konsisten.
abstract final class Warna {
  static const utama = Pal.sinyal;
  static const benar = Pal.benar;
  static const salah = Pal.salah;
  static const rekam = Pal.rekam;
  static const malam = Pal.latar;
  static const kerangka = Pal.kapur;
  static Color kelas(int i) => Pal.kelas(i);
}

abstract final class Huruf {
  static const kondensed = 'BarlowCondensed';
  static const isi = 'Barlow';
  static const mono = 'PlexMono';

  /// Angka dan judul besar.
  static TextStyle angka(
    double ukuran, {
    Color warna = Pal.kapur,
    FontWeight tebal = FontWeight.w800,
  }) => TextStyle(
    fontFamily: kondensed,
    fontSize: ukuran,
    fontWeight: tebal,
    height: 0.92,
    letterSpacing: ukuran > 40 ? -1 : -0.2,
    color: warna,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Judul bagian dan nama gerakan (dipakai dengan teks kapital).
  static TextStyle judul(double ukuran, {Color warna = Pal.kapur}) => TextStyle(
    fontFamily: kondensed,
    fontSize: ukuran,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 0.4,
    color: warna,
  );

  /// Label kecil huruf kapital, gaya pembacaan alat ukur.
  static TextStyle label({
    Color warna = Pal.redup,
    double ukuran = 11,
    FontWeight tebal = FontWeight.w500,
  }) => TextStyle(
    fontFamily: mono,
    fontSize: ukuran,
    fontWeight: tebal,
    letterSpacing: 1.1,
    height: 1.3,
    color: warna,
  );

  static TextStyle teks({
    Color warna = Pal.kapur,
    double ukuran = 15,
    FontWeight tebal = FontWeight.w400,
  }) => TextStyle(
    fontFamily: isi,
    fontSize: ukuran,
    fontWeight: tebal,
    height: 1.4,
    color: warna,
  );
}

ThemeData buatTema() {
  const skema = ColorScheme.dark(
    primary: Pal.sinyal,
    onPrimary: Pal.latar,
    secondary: Pal.benar,
    onSecondary: Pal.latar,
    surface: Pal.lapis,
    onSurface: Pal.kapur,
    onSurfaceVariant: Pal.redup,
    surfaceContainerLowest: Pal.latar,
    surfaceContainerLow: Pal.lapis,
    surfaceContainer: Pal.lapis,
    surfaceContainerHigh: Pal.lapis2,
    surfaceContainerHighest: Pal.lapis2,
    outline: Pal.garisKuat,
    outlineVariant: Pal.garis,
    error: Pal.salah,
    tertiaryContainer: Pal.lapis2,
    onTertiaryContainer: Pal.kapur,
  );
  final dasar = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: Huruf.isi,
  );
  return dasar.copyWith(
    colorScheme: skema,
    scaffoldBackgroundColor: Pal.latar,
    canvasColor: Pal.latar,
    hintColor: Pal.samar,
    dividerColor: Pal.garis,
    splashFactory: InkRipple.splashFactory,
    textTheme: dasar.textTheme.apply(
      fontFamily: Huruf.isi,
      bodyColor: Pal.kapur,
      displayColor: Pal.kapur,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Pal.latar,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: const IconThemeData(color: Pal.kapur),
      titleTextStyle: Huruf.judul(22),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Pal.lapis,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        side: BorderSide(color: Pal.garis),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Pal.garis,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      titleTextStyle: Huruf.teks(tebal: FontWeight.w600),
      subtitleTextStyle: Huruf.teks(warna: Pal.redup, ukuran: 13.5),
      iconColor: Pal.redup,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Pal.sinyal,
        foregroundColor: Pal.latar,
        disabledBackgroundColor: Pal.lapis2,
        disabledForegroundColor: Pal.samar,
        minimumSize: const Size(0, 52),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        textStyle: Huruf.judul(19),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Pal.kapur,
        minimumSize: const Size(0, 52),
        side: const BorderSide(color: Pal.garisKuat),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        textStyle: Huruf.judul(19),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Pal.sinyal,
        textStyle: Huruf.label(ukuran: 12),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Pal.lapis,
        foregroundColor: Pal.redup,
        selectedBackgroundColor: Pal.kapur,
        selectedForegroundColor: Pal.latar,
        side: const BorderSide(color: Pal.garisKuat),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        textStyle: Huruf.judul(17),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Pal.latar : Pal.redup,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Pal.sinyal : Pal.lapis2,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Pal.sinyal : Pal.garisKuat,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Pal.sinyal : Pal.samar,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Pal.sinyal,
      inactiveTrackColor: Pal.lapis2,
      thumbColor: Pal.sinyal,
      overlayColor: Color(0x22FFC93C),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Pal.lapis,
      labelStyle: Huruf.label(),
      floatingLabelStyle: Huruf.label(warna: Pal.sinyal),
      helperStyle: Huruf.teks(warna: Pal.samar, ukuran: 12.5),
      hintStyle: Huruf.teks(warna: Pal.samar),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        borderSide: BorderSide(color: Pal.garisKuat),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        borderSide: BorderSide(color: Pal.sinyal, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Pal.lapis,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        side: BorderSide(color: Pal.garis),
      ),
      titleTextStyle: Huruf.judul(24),
      contentTextStyle: Huruf.teks(warna: Pal.redup),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Pal.lapis,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: Pal.garisKuat,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Pal.kapur,
      contentTextStyle: Huruf.teks(warna: Pal.latar, tebal: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Pal.sinyal),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: Pal.redup,
      collapsedIconColor: Pal.redup,
      textColor: Pal.kapur,
      collapsedTextColor: Pal.kapur,
    ),
  );
}

// ---------------------------------------------------------------------------
// Komponen dasar
// ---------------------------------------------------------------------------

/// Label mono kapital kecil.
class Label extends StatelessWidget {
  const Label(this.teks, {super.key, this.warna = Pal.redup, this.ukuran = 11});

  final String teks;
  final Color warna;
  final double ukuran;

  @override
  Widget build(BuildContext context) => Text(
    teks.toUpperCase(),
    style: Huruf.label(warna: warna, ukuran: ukuran),
  );
}

/// Bidang bergaris rambut.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.warna = Pal.lapis,
    this.garis = Pal.garis,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color warna;
  final Color garis;

  @override
  Widget build(BuildContext context) {
    final isi = Padding(padding: padding, child: child);
    return Material(
      color: warna,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        side: BorderSide(color: garis),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? isi : InkWell(onTap: onTap, child: isi),
    );
  }
}

/// Satu pembacaan: label mono di atas angka condensed.
class Bacaan extends StatelessWidget {
  const Bacaan({
    super.key,
    required this.label,
    required this.nilai,
    this.satuan,
    this.warna = Pal.kapur,
    this.ukuran = 40,
  });

  final String label;
  final String nilai;
  final String? satuan;
  final Color warna;
  final double ukuran;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Label(label),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(nilai, style: Huruf.angka(ukuran, warna: warna)),
            if (satuan != null) ...[
              const SizedBox(width: 3),
              Text(satuan!, style: Huruf.label(ukuran: 11)),
            ],
          ],
        ),
      ],
    );
  }
}

/// Judul halaman besar: label kecil di atas, judul condensed kapital.
class KepalaLayar extends StatelessWidget {
  const KepalaLayar({
    super.key,
    required this.judul,
    this.atas,
    this.kembali = false,
    this.aksi,
  });

  final String judul;
  final String? atas;
  final bool kembali;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(kembali ? 4 : 20, 8, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (kembali)
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: Pal.kapur),
              tooltip: 'Kembali',
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (atas != null) Label(atas!),
                if (atas != null) const SizedBox(height: 4),
                Text(judul.toUpperCase(), style: Huruf.angka(38)),
              ],
            ),
          ),
          ?aksi,
        ],
      ),
    );
  }
}

/// Judul bagian di dalam daftar: label mono dengan garis.
class JudulBagian extends StatelessWidget {
  const JudulBagian(this.teks, {super.key, this.aksi, this.onAksi});

  final String teks;
  final String? aksi;
  final VoidCallback? onAksi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 10),
      child: Row(
        children: [
          Label(teks, warna: Pal.kapur),
          const SizedBox(width: 10),
          const Expanded(child: Divider()),
          if (aksi != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onAksi,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Label('$aksi →', warna: Pal.sinyal),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lencana kecil berwarna (DEMO, REC, SINTETIS).
class Lencana extends StatelessWidget {
  const Lencana(
    this.teks, {
    super.key,
    this.warna = Pal.sinyal,
    this.isi = false,
  });

  final String teks;
  final Color warna;

  /// Isi penuh (teks gelap) atau garis tepi saja.
  final bool isi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isi ? warna : Colors.transparent,
        border: Border.all(color: warna),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        teks.toUpperCase(),
        style: Huruf.label(
          warna: isi ? Pal.latar : warna,
          ukuran: 10,
          tebal: FontWeight.w500,
        ),
      ),
    );
  }
}
