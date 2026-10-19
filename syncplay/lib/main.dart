
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

    final db = FirebaseFirestore.instance;
    final rooms = db.collection('rooms');

    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _generateRoomCode();
      final roomRef = rooms.doc(code);

      final created = await db.runTransaction((transaction) async {
        final existing = await transaction.get(roomRef);

        if (existing.exists) return false;

        transaction.set(roomRef, {
          'creatorUid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'active',
        });

        return true;
      });

      if (!created) continue;

      // Register the creator as the first member.
      await roomRef.collection('members').doc(user.uid).set({
        'uid': user.uid,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      return code;
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

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoomScreen(roomCode: code),
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

  Future<void> _handleJoinRoom(BuildContext context) async {
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Join a listening room'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: codeController,
            autofocus: true,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            style: const TextStyle(
              letterSpacing: 4,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              labelText: 'Room code',
              hintText: 'ABC123',
              counterText: '',
            ),
            validator: (value) {
              final normalized = (value ?? '').trim().toUpperCase();
              if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(normalized)) {
                return 'Enter a valid 6-character code.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(
                  dialogContext,
                  codeController.text.trim().toUpperCase(),
                );
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );

    codeController.dispose();

    if (code == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: accentColor),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You are not signed in. Restart the app.');
      }

      final db = FirebaseFirestore.instance;
      final roomRef = db.collection('rooms').doc(code);
      final roomSnapshot = await roomRef.get();

      if (!roomSnapshot.exists ||
          roomSnapshot.data()?['status'] != 'active') {
        throw Exception('Room not found or no longer active.');
      }

      final memberRef = roomRef.collection('members').doc(user.uid);
      final existingMember = await memberRef.get();

      if (!existingMember.exists) {
        await memberRef.set({
          'uid': user.uid,
          'joinedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoomScreen(roomCode: code),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not join room: $error'),
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
                  onPressed: () => _handleJoinRoom(context),
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

class RoomScreen extends StatelessWidget {
  final String roomCode;

  const RoomScreen({
    super.key,
    required this.roomCode,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser;
    final roomRef = db.collection('rooms').doc(roomCode);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listening room'),
        backgroundColor: bgColor,
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: roomRef.snapshots(),
          builder: (context, roomSnapshot) {
            if (roomSnapshot.hasError) {
              return const Center(
                child: Text('Could not load this room.'),
              );
            }

            if (!roomSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: accentColor),
              );
            }

            final roomData = roomSnapshot.data!.data();
            if (roomData == null) {
              return const Center(child: Text('This room no longer exists.'));
            }

            final creatorUid = roomData['creatorUid'] as String?;

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(
                  Icons.headphones_rounded,
                  color: accentColor,
                  size: 54,
                ),
                const SizedBox(height: 16),
                const Text(
                  'YOU ARE IN SYNC',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Share the code with your friends',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 16),
                Center(
                  child: SelectableText(
                    roomCode,
                    style: const TextStyle(
                      color: accentColor,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, color: accentColor),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'People in this room',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: roomRef.collection('members').snapshots(),
                  builder: (context, membersSnapshot) {
                    if (membersSnapshot.hasError) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Unable to load members. Check your Firestore rules.',
                          ),
                        ),
                      );
                    }

                    if (!membersSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: accentColor,
                        ),
                      );
                    }

                    final members = membersSnapshot.data!.docs;

                    return Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < members.length; i++)
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    accentColor.withValues(alpha: 0.15),
                                child: Icon(
                                  members[i].id == creatorUid
                                      ? Icons.star_rounded
                                      : Icons.person_rounded,
                                  color: accentColor,
                                ),
                              ),
                              title: Text(
                                members[i].id == user?.uid
                                    ? 'You'
                                    : 'Listener ${members[i].id.substring(0, min(6, members[i].id.length))}',
                              ),
                              subtitle: members[i].id == creatorUid
                                  ? const Text('Room host')
                                  : null,
                              trailing: members[i].id == user?.uid
                                  ? const Text(
                                      'YOU',
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                              dense: true,
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Member list updates automatically.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            );
          },
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
