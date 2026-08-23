// 课表 App 基础 smoke test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kebiao_app/main.dart';

void main() {
  testWidgets('Should render the timetable home', (WidgetTester tester) async {
    // 构建 App 并触发一帧
    await tester.pumpWidget(const KebiaoApp());

    // 底部 Tab「课表」应存在
    expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    expect(find.byIcon(Icons.upload_file_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

  });
}