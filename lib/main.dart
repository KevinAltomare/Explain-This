import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';   
import 'screens/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();       

  await Hive.initFlutter();                        
  await Hive.openBox('history');
  await Hive.openBox('settings');                   

  runApp(const ExplainThisApp());
}

class ExplainThisApp extends StatelessWidget {
  const ExplainThisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Explain This',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}