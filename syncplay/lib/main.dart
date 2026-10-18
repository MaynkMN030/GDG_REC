
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAuth.instance.signInAnonymously();

  runApp(const SyncPlayApp());
}

const Color bgColor = Color(0xFF0D0D12);
const Color cardColor = Color(0xFF191922);
const Color accentColor = Color(0xFFB8F35A);

class SyncPlayApp extends StatelessWidget {
  const SyncPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SyncPlay',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    return List.generate(
      6,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<String> _createRoom() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('You are not signed in. Please restart the app.');
    }

    final rooms = FirebaseFirestore.instance.collection('rooms');

    // Retry if a generated code is already in use.
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _generateRoomCode();
      final roomRef = rooms.doc(code);

      final created = await FirebaseFirestore.instance.runTransaction(
        (transaction) async {
          final existing = await transaction.get(roomRef);

          if (existing.exists) return false;

          transaction.set(roomRef, {
            'creatorUid': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });

          return true;
        },
      );

      if (created) return code;
    }

    throw Exception('Could not generate a room code. Try again.');
  }

  Future<void> _handleCreateRoom(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: accentColor),
      ),
    );

    try {
      final code = await _createRoom();

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: cardColor,
          title: const Text('Your listening room is ready!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Share this code with your friends:'),
              const SizedBox(height: 18),
              SelectableText(
                code,
                style: const TextStyle(
                  color: accentColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 5,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Done',
                style: TextStyle(color: accentColor),
              ),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create room: $error'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: bgColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'SyncPlay',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.headphones_rounded,
                    color: accentColor,
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(height: 42),
              const Text(
                'MUSIC IS BETTER',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Better together.',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Listen to the same music, at the same time, '
                'with your friends — wherever they are.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton.icon(
                  onPressed: () => _handleCreateRoom(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: bgColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text(
                    'Create a listening room',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Joining rooms is coming in the next step!',
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text(
                    'Join a room',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'THE EXPERIENCE',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              const FeatureCard(
                icon: Icons.music_note_rounded,
                title: 'Listen together',
                description: 'Enjoy music with friends in a shared room.',
              ),
              const SizedBox(height: 12),
              const FeatureCard(
                icon: Icons.sync_rounded,
                title: 'Stay in sync',
                description: 'Keep playback coordinated across the room.',
              ),
              const SizedBox(height: 12),
              const FeatureCard(
                icon: Icons.people_alt_rounded,
                title: 'Your people, your room',
                description: 'Create a room and invite friends to join.',
              ),
              const SizedBox(height: 28),
              const Center(
                child: Text(
                  'MADE FOR SHARED MOMENTS',
                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 25),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
