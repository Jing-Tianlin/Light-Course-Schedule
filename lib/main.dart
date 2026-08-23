import 'package:flutter/material.dart';

import 'data/kebiao_data.dart';
import 'screens/home_screen.dart';
import 'screens/import_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 先加载本地数据再构建界面，避免 notifyListeners 在首帧构建期间触发 setState
  await KebiaoData.instance.loadFromStorage();
  runApp(const KebiaoApp());
}

class KebiaoApp extends StatelessWidget {
  const KebiaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '轻课表',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'PingFang SC',
        colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.brand),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const RootTabs(),
    );
  }
}

/// 底部 Tab 导航
class RootTabs extends StatefulWidget {
  const RootTabs({super.key});

  @override
  State<RootTabs> createState() => _RootTabsState();
}

class _RootTabsState extends State<RootTabs> {
  int _index = 0;

  static const _pages = [HomeScreen(), ImportScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            height: 56,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            indicatorColor: AppTheme.brand.withValues(alpha: 0.12),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today, color: AppTheme.brand),
                label: '课表',
              ),
              NavigationDestination(
                icon: Icon(Icons.upload_file_outlined),
                selectedIcon: Icon(Icons.upload_file, color: AppTheme.brand),
                label: '导入',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings, color: AppTheme.brand),
                label: '设置',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
