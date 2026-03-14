import 'package:firebase_core/firebase_core.dart';
import 'package:final_project/frontend/loginScreen.dart';
import 'package:final_project/services/syncService.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await SyncService.instance.init();
  runApp(const LoginScreen());
}