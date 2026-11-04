import 'package:flutter/material.dart';

/// Paleta de la pantalla de ingreso de Gexi: verde, azul y azul marino.
class AppColors {
  static const primario = Color(0xFF1A56F0);
  static const limaBrillo = Color(0xFFE7FBF6);
  static const lima = Color(0xFF16C96A);
  static const verde = Color(0xFF16A34A);
  static const teal = Color(0xFF14B8A6);
  static const tealFuerte = Color(0xFF1A56F0);
  static const azulClaro = Color(0xFF5B8CFF);
  static const azul = Color(0xFF1A56F0);
  static const azulProfundo = Color(0xFF08345C);

  static const fondoClaro = Color(0xFFF5FBFA);
  static const navClaro = Color(0xFFFFFFFF);
  static const texto = Color(0xFF0E3154);
  static const textoSuave = Color(0xFF6B7280);
  static const linea = Color(0xFFE4E8EE);
  static const pendiente = Color(0xFFCA8A04);
  static const enCurso = Color(0xFF2563EB);
  static const completado = Color(0xFF16A34A);
  static const alerta = Color(0xFFDC2626);

  static const fondoOscuro = Color(0xFF071410);
  static const tarjetaOscura = Color(0xFF12261C);
  static const navOscuro = Color(0xFF0C1C16);
  static const textoOscuro = Color(0xFFE7F6EC);
  static const textoSuaveOscuro = Color(0xFF9BB8A8);

  static const degradadoBarra = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF3DDE6E), Color(0xFF1A56F0)],
  );

  static const sombraTarjeta = [
    BoxShadow(
      color: Color(0x140F3A5A),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];

  static final tarjeta = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: sombraTarjeta,
  );
}

ThemeData buildLightTheme() {
  const borde = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
    borderSide: BorderSide(color: AppColors.linea),
  );
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primario,
    brightness: Brightness.light,
    primary: AppColors.primario,
    onPrimary: Colors.white,
    secondary: AppColors.lima,
    onSecondary: Colors.white,
    tertiary: AppColors.teal,
    onTertiary: Colors.white,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.fondoClaro,
    cardColor: Colors.white,
    primaryColor: AppColors.primario,
    dividerColor: AppColors.linea,
    splashColor: AppColors.limaBrillo,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.fondoClaro,
      foregroundColor: AppColors.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.texto,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      iconTheme: IconThemeData(color: AppColors.primario),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 8,
      backgroundColor: AppColors.navClaro,
      indicatorColor: AppColors.limaBrillo,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x140F3A5A),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.primario : AppColors.textoSuave,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.texto : AppColors.textoSuave,
        );
      }),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: AppColors.texto,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      titleLarge: TextStyle(
        color: AppColors.texto,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: AppColors.texto,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: AppColors.texto),
      bodyMedium: TextStyle(color: AppColors.textoSuave),
      bodySmall: TextStyle(color: AppColors.textoSuave),
    ),
    iconTheme: const IconThemeData(color: AppColors.primario),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: TextStyle(color: Color(0xFF9AA3B3), fontWeight: FontWeight.w500),
      labelStyle: TextStyle(color: AppColors.textoSuave),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: borde,
      enabledBorder: borde,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppColors.primario, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primario,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primario,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.texto,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.linea),
        shape: const StadiumBorder(),
        minimumSize: const Size.fromHeight(48),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primario,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primario,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.limaBrillo,
      side: BorderSide.none,
      labelStyle: TextStyle(color: AppColors.texto, fontWeight: FontWeight.w600),
      shape: StadiumBorder(),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.azulProfundo,
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.primario,
      textColor: AppColors.texto,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primario,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.linea, thickness: 1),
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primario,
    brightness: Brightness.dark,
    primary: AppColors.azulClaro,
    onPrimary: AppColors.fondoOscuro,
    secondary: AppColors.lima,
    onSecondary: AppColors.fondoOscuro,
    surface: AppColors.tarjetaOscura,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.fondoOscuro,
    cardColor: AppColors.tarjetaOscura,
    primaryColor: AppColors.azulClaro,
    dividerColor: const Color(0xFF1C3A2C),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.fondoOscuro,
      foregroundColor: AppColors.textoOscuro,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: AppColors.lima),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.navOscuro,
      indicatorColor: AppColors.lima.withValues(alpha: 0.25),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.lima : AppColors.textoSuaveOscuro,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.lima : AppColors.textoSuaveOscuro,
        );
      }),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textoOscuro),
      bodyMedium: TextStyle(color: AppColors.textoSuaveOscuro),
      titleLarge: TextStyle(
        color: AppColors.textoOscuro,
        fontWeight: FontWeight.bold,
      ),
    ),
    iconTheme: const IconThemeData(color: AppColors.lima),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.lima,
      foregroundColor: AppColors.fondoOscuro,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.lima,
        foregroundColor: AppColors.fondoOscuro,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.lima,
    ),
  );
}
