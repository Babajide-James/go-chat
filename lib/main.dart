import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'app.dart';
import 'env/env.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/chat_list_viewmodel.dart';
import 'core/services/upload_queue_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  // Initialize the offline upload queue — drains pending uploads on connectivity
  UploadQueueService().startListening();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => ChatListViewModel()),
      ],
      child: const App(),
    ),
  );
}
