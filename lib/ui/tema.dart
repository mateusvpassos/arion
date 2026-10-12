import 'package:flutter/material.dart';

/// Visual da família Kino/Strata (igual ao MyMusic web): grafite quase
/// preto, Geist, bordas finas e o destaque vindo da cor escolhida (verde da
/// marca por padrão).
class Tema {
  /// Verde do ícone. As outras cores das configurações geram os tons pelo matiz.
  static const marca = 0xFF4ADE80;

  /// Padrão antigo (índigo do Material): quem nunca escolheu cor vai p/ a marca.
  static const padraoAntigo = 0xFF3D5AFE;

  static const cores = [
    marca, 0xFF3D5AFE, 0xFF7E57C2, 0xFFD81B60,
    0xFFF4511E, 0xFF00897B, 0xFF1E88E5, 0xFF8D6E63,
  ];

  static Color _hsl(double h, double s, double l) =>
      HSLColor.fromAHSL(1, (h % 360 + 360) % 360, s.clamp(0, 1), l.clamp(0, 1)).toColor();

  /// Cor do destaque (botões, acordes na tela escura...).
  static Color destaque(int seed, bool escuro) {
    if (seed == marca) return escuro ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    final c = HSLColor.fromColor(Color(seed));
    final s = c.saturation.clamp(0.55, 1.0);
    return _hsl(c.hue, s, escuro ? 0.68 : 0.42);
  }

  /// Fim do degradê (o começo é o destaque).
  static Color destaqueFim(int seed, bool escuro) {
    if (seed == marca) return escuro ? const Color(0xFF14B8A6) : const Color(0xFF0D8A7E);
    final c = HSLColor.fromColor(Color(seed));
    return _hsl(c.hue + 32, c.saturation.clamp(0.55, 1.0), escuro ? 0.52 : 0.36);
  }

  static ThemeData de(int seed, bool escuro) {
    // tons neutros (os mesmos tokens do style.css do web)
    final bg = escuro ? const Color(0xFF0D0E13) : const Color(0xFFF4F5F8);
    final painel = escuro ? const Color(0xFF14151C) : Colors.white;
    final cartao = escuro ? const Color(0xFF181A22) : Colors.white;
    final cartaoHi = escuro ? const Color(0xFF20222D) : const Color(0xFFF0F1F5);
    final chip = escuro ? const Color(0xFF20222D) : const Color(0xFFECEEF3);
    final linha = escuro ? const Color(0xFF252836) : const Color(0xFFE3E5EC);
    final linha2 = escuro ? const Color(0xFF323648) : const Color(0xFFD2D5DF);
    final campo = escuro ? const Color(0xFF0F1016) : Colors.white;
    final texto = escuro ? const Color(0xFFE9EAF1) : const Color(0xFF15161C);
    final apagado = escuro ? const Color(0xFF8B90A4) : const Color(0xFF5E6377);
    final erro = escuro ? const Color(0xFFFF5D6C) : const Color(0xFFD92D3E);

    final primary = destaque(seed, escuro);
    final onPrimary = escuro ? const Color(0xFF0B0C10) : Colors.white;
    final suave = Color.alphaBlend(primary.withValues(alpha: escuro ? 0.16 : 0.12), cartao);
    final textoDestaque = Color.lerp(primary, escuro ? Colors.white : Colors.black, 0.45)!;

    final scheme = ColorScheme(
      brightness: escuro ? Brightness.dark : Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: suave,
      onPrimaryContainer: textoDestaque,
      secondary: primary,
      onSecondary: onPrimary,
      secondaryContainer: chip,
      onSecondaryContainer: texto,
      tertiary: destaqueFim(seed, escuro),
      onTertiary: onPrimary,
      tertiaryContainer: suave,
      onTertiaryContainer: textoDestaque,
      error: erro,
      onError: Colors.white,
      surface: bg,
      onSurface: texto,
      onSurfaceVariant: apagado,
      surfaceContainerLowest: campo,
      surfaceContainerLow: painel,
      surfaceContainer: cartao,
      surfaceContainerHigh: cartaoHi,
      surfaceContainerHighest: chip,
      outline: linha2,
      outlineVariant: linha,
      inverseSurface: texto,
      onInverseSurface: bg,
      inversePrimary: primary,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );

    RoundedRectangleBorder caixa(double r, [Color? borda]) => RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r),
          side: borda == null ? BorderSide.none : BorderSide(color: borda),
        );
    final borda10 = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: linha2),
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Geist',
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(color: linha, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: painel,
        surfaceTintColor: Colors.transparent,
        foregroundColor: texto,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: linha)),
        titleTextStyle: TextStyle(
          fontFamily: 'Geist',
          color: texto,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: chip,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: linha2),
        ),
        labelColor: texto,
        unselectedLabelColor: apagado,
        labelStyle: const TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w500, fontSize: 14),
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: cartao,
        shape: caixa(12, linha),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: chip,
        selectedColor: suave,
        side: BorderSide(color: linha2),
        shape: caixa(8),
        labelStyle: TextStyle(fontFamily: 'Geist', color: texto, fontWeight: FontWeight.w500, fontSize: 13),
        checkmarkColor: textoDestaque,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: campo,
        hintStyle: TextStyle(color: escuro ? const Color(0xFF5C6176) : const Color(0xFF8D92A5)),
        border: borda10,
        enabledBorder: borda10,
        focusedBorder: borda10.copyWith(borderSide: BorderSide(color: primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: caixa(10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: texto,
          side: BorderSide(color: linha2),
          shape: caixa(10),
          textStyle: const TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: caixa(8),
          textStyle: const TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: caixa(9)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          side: BorderSide(color: linha2),
          selectedBackgroundColor: chip,
          selectedForegroundColor: texto,
          shape: caixa(10),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 3,
        shape: caixa(12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: painel,
        surfaceTintColor: Colors.transparent,
        shape: caixa(14, linha2),
        titleTextStyle: TextStyle(fontFamily: 'Geist', color: texto, fontSize: 17, fontWeight: FontWeight.w600),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: painel,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: linha2,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cartaoHi,
        contentTextStyle: TextStyle(fontFamily: 'Geist', color: texto),
        actionTextColor: primary,
        shape: caixa(10, linha2),
      ),
      listTileTheme: ListTileThemeData(shape: caixa(12), iconColor: apagado),
      popupMenuTheme: PopupMenuThemeData(
        color: painel,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: caixa(10, linha2),
        textStyle: TextStyle(fontFamily: 'Geist', color: texto, fontWeight: FontWeight.w500, fontSize: 14),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: escuro ? const Color(0xFF23252F) : const Color(0xFF15161C),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: linha2),
        ),
        textStyle: const TextStyle(fontFamily: 'Geist', color: Colors.white, fontSize: 12),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: linha2,
        thumbColor: escuro ? Colors.white : primary,
        overlayColor: primary.withValues(alpha: 0.15),
      ),
      badgeTheme: BadgeThemeData(backgroundColor: erro, textColor: Colors.white),
    );
  }
}
