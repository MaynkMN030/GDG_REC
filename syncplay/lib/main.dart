
import 'package:flutter/material.dart';

void main() {
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

              // App branding
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

              // Create room button
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Room creation is coming in the next step!',
                        ),
                      ),
                    );
                  },
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

              // Join room button
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
                description:
                    'Enjoy music with friends in a shared room.',
              ),
              const SizedBox(height: 12),
              const FeatureCard(
                icon: Icons.sync_rounded,
                title: 'Stay in sync',
                description:
                    'Keep playback coordinated across the room.',
              ),
              const SizedBox(height: 12),
              const FeatureCard(
                icon: Icons.people_alt_rounded,
                title: 'Your people, your room',
                description:
                    'Create a room and invite friends to join.',
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
            child: Icon(
              icon,
              color: accentColor,
              size: 25,
            ),
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
