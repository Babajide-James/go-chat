import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'views/auth/login_view.dart';
import 'views/chat_list/chat_list_view.dart';
import 'core/widgets/loading_indicator.dart';
import 'core/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Go Chat',
      theme: AppTheme.lightTheme,
      routes: {
        '/login': (_) => const LoginView(),
        '/chats': (_) => const ChatListView(),
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: LoadingIndicator());
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const ChatListView();
          }
          return const LoginView();
        },
      ),
    );
  }
}
