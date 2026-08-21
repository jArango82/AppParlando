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

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  List<Widget> get _pages => [
        HomePage(isActive: _selectedIndex == 0),
        const CoursesScreen(),
        const DiagnosticsScreen(),
        const GradesScreen(),
        ProfileScreen(
          key: _selectedIndex == 4 ? ValueKey(DateTime.now()) : null,
        ),
      ];

  Widget _buildRail(BuildContext context) {
    final isDark = context.isDarkMode;
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
            const SizedBox(height: 20),
            Image.asset(
              'assets/logo_001.webp',
              width: 48,
              height: 48,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.school_rounded,
                color: LimpioTokens.brand,
                size: 40,
              ),
            ),
            const Spacer(),
            ...List.generate(_tabs.length, (index) {
              final selected = _selectedIndex == index;
              final color =
                  selected ? LimpioTokens.brand : context.subtitleColor;
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
                          ? LimpioTokens.brand.withValues(alpha: 0.12)
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
            if (isDark)
              const SizedBox(height: 12)
            else
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 12,
      right: 12,
      bottom: bottom > 0 ? bottom : 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: context.cardColor.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: context.borderColor),
              boxShadow: [
                BoxShadow(
                  color: LimpioTokens.brand.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final selected = _selectedIndex == i;
                final color =
                    selected ? LimpioTokens.brand : context.subtitleColor;
                return Expanded(
                  child: InkWell(
                    onTap: () => _onItemTapped(i),
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: selected
                                ? LimpioTokens.brand.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_tabs[i].$1, size: 22, color: color),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tabs[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
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

    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: context.bgScaffold,
      body: Stack(
        children: [
          Positioned.fill(
            bottom: 72 + (bottom > 0 ? bottom : 10),
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
          _buildBottomNav(context),
        ],
      ),
    );
  }
}
