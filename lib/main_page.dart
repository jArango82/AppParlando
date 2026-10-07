import 'dart:ui';

import 'package:flutter/material.dart';
import 'screens/home_page.dart';
import 'screens/courses_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/grades_screen.dart';
import 'screens/profile_screen.dart';
import 'services/notification_service.dart';
import 'theme_provider.dart';
import 'widgets/limpio_card.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  static const _tabs = [
    (Icons.home_rounded, 'Inicio'),
    (Icons.school_rounded, 'Cursos'),
    (Icons.description_rounded, 'Diagnósticos'),
    (Icons.format_list_bulleted_rounded, 'Notas'),
    (Icons.person_rounded, 'Perfil'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().checkAndShowContractNotification();
    });
  }

  // Cambia cada vez que se entra a Perfil para que recargue sus datos, pero no en
  // cualquier otro rebuild (p. ej. cambiar el tema desde el propio perfil).
  int _profileVisits = 0;

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      if (index == 4) _profileVisits++;
    });
  }

  List<Widget> get _pages => [
        HomePage(isActive: _selectedIndex == 0),
        const CoursesScreen(),
        const DiagnosticsScreen(),
        const GradesScreen(),
        ProfileScreen(key: ValueKey(_profileVisits)),
      ];

  Widget _buildRail(BuildContext context) {
    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(right: BorderSide(color: context.borderColor)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 28),
            ...List.generate(_tabs.length, (index) {
              final selected = _selectedIndex == index;
              final color =
                  selected ? context.brandColor : context.subtitleColor;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: InkWell(
                  onTap: () => _onItemTapped(index),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 64,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? context.brandSoft
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(_tabs[index].$1, color: color, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          _tabs[index].$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const Spacer(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: context.isDarkMode
                    ? LimpioTokens.darkElevated.withValues(alpha: 0.96)
                    : context.cardColor.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: context.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: context.isDarkMode
                        ? Colors.black.withValues(alpha: 0.45)
                        : LimpioTokens.brand.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final selected = _selectedIndex == i;
                  final color =
                      selected ? context.brandColor : context.subtitleColor;
                  return Expanded(
                    child: InkWell(
                      onTap: () => _onItemTapped(i),
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? context.brandSoft
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child:
                                    Icon(_tabs[i].$1, size: 22, color: color),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _tabs[i].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  height: 1.1,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = context.isWideScreen;

    if (isWide) {
      return Scaffold(
        backgroundColor: context.bgScaffold,
        body: Row(
          children: [
            _buildRail(context),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.bgScaffold,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }
}
