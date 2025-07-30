import 'package:finmanager/Screens/FirstPage.dart'; 
import 'package:finmanager/Screens/Home.dart';
import 'package:finmanager/Screens/Login.dart';    
import 'package:flutter/material.dart';
import 'package:finmanager/Screens/register.dart';      
void main() {
  runApp(FinManagerApp());
}

class FinManagerApp extends StatefulWidget {
  @override
  _FinManagerAppState createState() => _FinManagerAppState();
}

class _FinManagerAppState extends State<FinManagerApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinManager',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: Colors.white,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepOrange,
        scaffoldBackgroundColor: Colors.black,
      ),

      initialRoute: '/',

      routes: {
        '/': (context) => const FirstPageDesign(),
        '/login': (context) => const LoginPageDesign(),
        '/register': (context) => const RegisterPageDesign(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}