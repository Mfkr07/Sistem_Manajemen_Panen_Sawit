import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  

  await Supabase.initialize(
    url: 'https://vjeccgtrqqwbsrovmqnk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZqZWNjZ3RycXF3YnNyb3ZtcW5rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3ODgzODksImV4cCI6MjA5MDM2NDM4OX0.tBSvCht3IqhYo3ZNI8aqbPl5DwowrDrviq3yIiH4IX0',
  );
 

  runApp(
    const ProviderScope(
      child: PalmHarvestApp(),
    ),
  );
}

class PalmHarvestApp extends ConsumerWidget {
  const PalmHarvestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'Palm Harvest Management',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
