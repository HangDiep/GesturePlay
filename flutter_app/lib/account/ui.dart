import 'package:flutter/material.dart';

const night = Color(0xff0b171d),
    cream = Color(0xffeee7d6),
    gold = Color(0xffdeb779),
    muted = Color(0xffa3b1af),
    teal = Color(0xff72c7bc),
    panel = Color(0xf010222b);

ThemeData portalTheme() => ThemeData(
  brightness: Brightness.dark,
  fontFamily: 'Segoe UI',
  scaffoldBackgroundColor: night,
  colorScheme: const ColorScheme.dark(
    primary: gold,
    secondary: teal,
    surface: panel,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xff142a33),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xff36505a)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xff36505a)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: gold),
  ),
);

Widget surface(
  Widget child, {
  EdgeInsetsGeometry padding = const EdgeInsets.all(22),
}) => Material(
  color: panel,
  shape: RoundedRectangleBorder(
    side: const BorderSide(color: Color(0xff304954)),
    borderRadius: BorderRadius.circular(18),
  ),
  child: Padding(padding: padding, child: child),
);

Widget note(
  String text, {
  IconData icon = Icons.info_outline,
  Color color = teal,
}) => Container(
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .08),
    border: Border.all(color: color.withValues(alpha: .3)),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 19),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 12, height: 1.6),
        ),
      ),
    ],
  ),
);

Widget statTile(String label, String value, IconData icon) => SizedBox(
  width: 180,
  child: surface(
    padding: const EdgeInsets.all(14),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: gold),
        const SizedBox(height: 14),
        Text(
          value,
          style: const TextStyle(
            color: cream,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: muted, fontSize: 12)),
      ],
    ),
  ),
);

class PortalPage extends StatelessWidget {
  const PortalPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), backgroundColor: night),
    body: Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff15313b), night, Color(0xff172322)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1020),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(color: muted, height: 1.6),
                ),
                const SizedBox(height: 22),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
