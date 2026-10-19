import 'dart:math';

import 'package:flutter/material.dart';

import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAuth.instance.signInAnonymously();

  runApp(const SyncPlayApp());
}

const Color bgColor = Color(0xFF0D0D12);
const Color cardColor = Color(0xFF191922);
const Color accentColor = Color(0xFFB8F35A);

class Song {
  final String id;
  final String title;
  final String artist;
  final String assetPath;
  final String? artworkAsset;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.assetPath,
    this.artworkAsset,
  });
}

// Add more Song entries here after placing their audio files in assets/audio/.
const List<Song> musicLibrary = [
  Song(
    id: 'demo_track',
    title: 'Demo Track',
    artist: 'SyncPlay demo audio',
    assetPath: 'assets/audio/demo.mp3',
  ),
  Song(
    id: 'track_1',
    title: 'Track 1',
    artist: 'Unknown Artist',
    assetPath: 'assets/audio/track_1.mp3',
  ),
  Song(
    id: 'track_2',
    title: 'Track 2',
    artist: 'Unknown Artist',
    assetPath: 'assets/audio/track_2.mp3',
  ),
  Song(
    id: 'track_3',
    title: 'Track 3',
    artist: 'Unknown Artist',
    assetPath: 'assets/audio/track_3.mp3',
  ),
];

final Set<String> favouriteSongIds = <String>{};

Song songById(String? id) {
  for (final song in musicLibrary) {
    if (song.id == id) return song;
  }
  return musicLibrary.first;
}

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

// Favourites are kept in memory for the current app session.

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _openFavourites() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FavouritesScreen()));
    if (mounted) setState(() {});
  }

  Future<void> _openLibrary() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MusicLibraryScreen(
          onSongSelected: (song) async {
            Navigator.of(context).pop();
            await _handleCreateRoom(context, song: song);
          },
        ),
      ),
    );
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<String> _createRoom({Song? initialSong}) async {
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
          'roomName': 'Listening room',
        });

        return true;
      });

      if (!created) continue;

      // Register the creator as the first member.
      await roomRef.collection('members').doc(user.uid).set({
        'uid': user.uid,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      final selectedSong = initialSong ?? musicLibrary.first;
      debugPrint(
        'Creating room playback state: songId=${selectedSong.id}, '
        'asset=${selectedSong.assetPath}',
      );
      await roomRef.collection('playback').doc('state').set({
        'songId': selectedSong.id,
        'isPlaying': false,
        'positionMs': 0,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });

      return code;
    }

    throw Exception('Could not generate a room code. Try again.');
  }

  Future<void> _handleCreateRoom(BuildContext context, {Song? song}) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: accentColor)),
    );

    try {
      final code = await _createRoom(initialSong: song);

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoomScreen(
            roomCode: code,
            initialSongId: (song ?? musicLibrary.first).id,
          ),
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
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: accentColor)),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You are not signed in. Restart the app.');
      }

      final db = FirebaseFirestore.instance;
      final roomRef = db.collection('rooms').doc(code);
      final roomSnapshot = await roomRef.get();

      if (!roomSnapshot.exists || roomSnapshot.data()?['status'] != 'active') {
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

      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => RoomScreen(roomCode: code)));
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
                  IconButton(
                    tooltip: 'Favourites',
                    onPressed: _openFavourites,
                    icon: const Icon(
                      Icons.favorite_rounded,
                      color: accentColor,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Music library',
                    onPressed: _openLibrary,
                    icon: const Icon(
                      Icons.library_music_rounded,
                      color: accentColor,
                    ),
                  ),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

class MusicLibraryScreen extends StatefulWidget {
  final Future<void> Function(Song song) onSongSelected;
  final bool favouritesOnly;

  const MusicLibraryScreen({
    super.key,
    required this.onSongSelected,
    this.favouritesOnly = false,
  });

  @override
  State<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends State<MusicLibraryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final songs = musicLibrary.where((song) {
      final matchesQuery = ('${song.title} ${song.artist}')
          .toLowerCase()
          .contains(_query.toLowerCase());
      final matchesFavourites =
          !widget.favouritesOnly || favouriteSongIds.contains(song.id);
      return matchesQuery && matchesFavourites;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.favouritesOnly ? 'Favourites' : 'Music library'),
        backgroundColor: bgColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search songs or artists',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: songs.isEmpty
                  ? Center(
                      child: Text(
                        widget.favouritesOnly
                            ? 'No favourites yet'
                            : 'No songs found',
                        style: const TextStyle(color: Colors.white60),
                      ),
                    )
                  : ListView.separated(
                      itemCount: songs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        final isFavourite = favouriteSongIds.contains(song.id);
                        return Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0x2219F35A),
                              child: Icon(
                                Icons.music_note_rounded,
                                color: accentColor,
                              ),
                            ),
                            title: Text(
                              song.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(song.artist),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: isFavourite
                                      ? 'Remove from favourites'
                                      : 'Add to favourites',
                                  onPressed: () => setState(() {
                                    if (isFavourite) {
                                      favouriteSongIds.remove(song.id);
                                    } else {
                                      favouriteSongIds.add(song.id);
                                    }
                                  }),
                                  icon: Icon(
                                    isFavourite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: accentColor,
                                  ),
                                ),
                                const Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: accentColor,
                                  size: 30,
                                ),
                              ],
                            ),
                            onTap: () => widget.onSongSelected(song),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MusicLibraryScreen(
      favouritesOnly: true,
      onSongSelected: (song) async {
        Navigator.of(context).pop();
      },
    );
  }
}

class RoomScreen extends StatefulWidget {
  final String roomCode;
  final String initialSongId;

  const RoomScreen({
    super.key,
    required this.roomCode,
    this.initialSongId = 'demo_track',
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final AudioPlayer _player = AudioPlayer();
  late String _currentSongId;
  late String _requestedSongId;

  // Serialize asset changes. Two setAsset calls running at the same time can
  // otherwise finish out of order (for example, demo.mp3 replacing track_1).
  Future<void> _songLoadQueue = Future<void>.value();
  int _assetLoadGeneration = 0;

  late final DocumentReference<Map<String, dynamic>> _roomRef;
  late final DocumentReference<Map<String, dynamic>> _playbackRef;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _playbackSubscription;

  bool _audioReady = false;
  bool _isApplyingRemoteChange = false;
  bool _isWritingPlayback = false;
  String? _pendingLocalSongId;
  int _localSongSelectionGeneration = 0;
  String? _audioError;

  Timer? _syncTimer;
  int _sharedPositionMs = 0;
  bool _sharedIsPlaying = false;
  DateTime? _sharedUpdatedAt;
  bool _hasSharedState = false;
  bool _isSeeking = false;

  @override
  void initState() {
    super.initState();
    _currentSongId = widget.initialSongId;
    _requestedSongId = widget.initialSongId;

    _roomRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode);
    _playbackRef = _roomRef.collection('playback').doc('state');

    _loadAudio();
    _listenForRemotePlayback();

    // Each client corrects its own player against the latest shared timeline.
    _syncTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _correctPlaybackDrift(),
    );
  }

  Future<void> _loadAudio() async {
    final loaded = await _loadSongAsset(_requestedSongId);
    if (loaded) {
      // A Firestore snapshot may arrive before the first asset finishes
      // loading. Apply the latest shared timeline after audio becomes ready.
      await _applyLatestSharedState();
    }
  }

  
Future<bool> _loadSongAsset(String songId) {
  final song = songById(songId);
  final generation = ++_assetLoadGeneration;
  _requestedSongId = song.id;

  debugPrint(
    'REQUESTED SONG: ${song.id} | FILE: ${song.assetPath} '
    '| GENERATION: $generation',
  );

  if (mounted) {
    setState(() {
      _audioReady = false;
      _audioError = null;
    });
  }

  final completer = Completer<bool>();

  _songLoadQueue = _songLoadQueue.catchError((Object _) {}).then((_) async {
    if (!mounted || generation != _assetLoadGeneration) {
      debugPrint('SKIPPED STALE LOAD: ${song.id}');
      completer.complete(false);
      return;
    }

    try {
      // Stop the previous track before replacing its source.
      await _player.stop();

      if (!mounted || generation != _assetLoadGeneration) {
        completer.complete(false);
        return;
      }

      debugPrint('LOADING EXACT FILE: ${song.assetPath}');

      // Explicitly construct a new asset source for the selected song.
      final duration = await _player.setAudioSource(
        AudioSource.asset(song.assetPath),
        preload: true,
      );

      if (!mounted || generation != _assetLoadGeneration) {
        debugPrint('DISCARDED STALE RESULT: ${song.id}');
        completer.complete(false);
        return;
      }

      await _player.seek(Duration.zero);

      if (!mounted || generation != _assetLoadGeneration) {
        completer.complete(false);
        return;
      }

      setState(() {
        _currentSongId = song.id;
        _audioReady = true;
        _audioError = null;
      });

      debugPrint(
        'LOADED SUCCESSFULLY: ${song.id} | ${song.assetPath} '
        '| DURATION: $duration | PLAYER DURATION: ${_player.duration}',
      );

      completer.complete(true);
    } catch (error, stackTrace) {
      debugPrint('FAILED TO LOAD: ${song.assetPath}');
      debugPrint('ERROR: $error');
      debugPrint('$stackTrace');

      if (mounted && generation == _assetLoadGeneration) {
        setState(() {
          _audioReady = false;
          _audioError =
              'Failed to load ${song.title}: ${song.assetPath}\n$error';
        });
      }

      completer.complete(false);
    }
  });

  return completer.future;
}


  void _listenForRemotePlayback() {
    _playbackSubscription = _playbackRef.snapshots().listen(
      (snapshot) async {
        if (!snapshot.exists) return;

        final data = snapshot.data();
        if (data == null) return;

        final positionMs = data['positionMs'];
        if (positionMs is! int) return;

        final isPlaying = data['isPlaying'] == true;
        final incomingSongId = data['songId'] as String?;
        debugPrint('Firestore playback received songId=$incomingSongId');
        final currentUser = FirebaseAuth.instance.currentUser;
        if (data['updatedBy'] == currentUser?.uid) {
          debugPrint(
            'Ignoring own Firestore snapshot before audio loading: '
            'songId=$incomingSongId',
          );
          return;
        }
        if (_pendingLocalSongId != null &&
            incomingSongId != _pendingLocalSongId) {
          debugPrint(
            'Ignored stale Firestore songId=$incomingSongId while local '
            'songId=$_pendingLocalSongId is loading',
          );
          return;
        }
        if (incomingSongId != null &&
            incomingSongId != _requestedSongId &&
            musicLibrary.any((song) => song.id == incomingSongId)) {
          final loaded = await _loadSongAsset(incomingSongId);
          if (!loaded) return;
        }
        final updatedAtValue = data['updatedAt'];
        DateTime? updatedAt;
        if (updatedAtValue is Timestamp) {
          updatedAt = updatedAtValue.toDate();
        }

        _sharedPositionMs = positionMs;
        _sharedIsPlaying = isPlaying;
        _sharedUpdatedAt = updatedAt;
        _hasSharedState = true;

        // Keep the latest state even if the audio is still loading. The
        // audio-ready callback will apply it after setAsset completes.
        if (!_audioReady) return;

        await _applyLatestSharedState();
      },
      onError: (Object error) {
        debugPrint('Playback listener error: $error');
      },
    );
  }

  Future<void> _applyLatestSharedState() async {
    if (!_audioReady || !_hasSharedState) return;

    var targetMs = _sharedPositionMs;
    if (_sharedIsPlaying && _sharedUpdatedAt != null) {
      final elapsedMs = DateTime.now()
          .difference(_sharedUpdatedAt!)
          .inMilliseconds;
      if (elapsedMs > 0) targetMs += elapsedMs;
    }

    final durationMs = _player.duration?.inMilliseconds;
    if (durationMs != null) {
      targetMs = targetMs.clamp(0, durationMs).toInt();
    } else {
      targetMs = targetMs < 0 ? 0 : targetMs;
    }

    await _applySharedState(positionMs: targetMs, isPlaying: _sharedIsPlaying);
  }

  Future<void> _applySharedState({
    required int positionMs,
    required bool isPlaying,
  }) async {
    if (!_audioReady || _isApplyingRemoteChange) return;

    try {
      _isApplyingRemoteChange = true;
      await _player.seek(Duration(milliseconds: positionMs));

      if (isPlaying) {
        await _player.play();
      } else {
        await _player.pause();
      }
    } catch (error) {
      debugPrint('Could not apply remote playback: $error');
    } finally {
      _isApplyingRemoteChange = false;
    }
  }

  Future<void> _correctPlaybackDrift() async {
    if (!_audioReady ||
        !_hasSharedState ||
        !_sharedIsPlaying ||
        _isApplyingRemoteChange ||
        _isSeeking ||
        _sharedUpdatedAt == null) {
      return;
    }

    // Advance the shared position by the time elapsed since the last update.
    final elapsed = DateTime.now().difference(_sharedUpdatedAt!);
    final expectedMs = _sharedPositionMs + elapsed.inMilliseconds;
    final actualMs = _player.position.inMilliseconds;

    // Avoid unnecessary seeks for tiny differences, which can cause audible
    // glitches. Larger drift is corrected once per timer tick.
    if ((expectedMs - actualMs).abs() > 1200) {
      final durationMs = _player.duration?.inMilliseconds;
      final targetMs = durationMs == null
          ? expectedMs
          : expectedMs.clamp(0, durationMs);

      try {
        _isApplyingRemoteChange = true;
        await _player.seek(Duration(milliseconds: targetMs));
      } catch (error) {
        debugPrint('Drift correction failed: $error');
      } finally {
        _isApplyingRemoteChange = false;
      }
    }
  }

  Future<void> _togglePlayback(bool currentlyPlaying) async {
    if (!_audioReady || _isWritingPlayback || _isApplyingRemoteChange) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('You are not signed in.');
      return;
    }

    _isWritingPlayback = true;

    try {
      final positionMs = _player.position.inMilliseconds.clamp(0, 1 << 31);
      final nextIsPlaying = !currentlyPlaying;

      // Update our local timeline immediately, then publish it for the room.
      _sharedPositionMs = positionMs;
      _sharedIsPlaying = nextIsPlaying;
      _sharedUpdatedAt = DateTime.now();
      _hasSharedState = true;

      debugPrint(
        'Writing playback state: songId=$_currentSongId, '
        'isPlaying=$nextIsPlaying, positionMs=$positionMs',
      );
      await _playbackRef.set({
        'songId': _currentSongId,
        'isPlaying': nextIsPlaying,
        'positionMs': positionMs,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });

      if (nextIsPlaying) {
        await _player.play();
      } else {
        await _player.pause();
      }
    } catch (error) {
      _showMessage('Playback failed: $error');
    } finally {
      _isWritingPlayback = false;
    }
  }

  Future<void> _publishSeek(Duration position) async {
    if (!_audioReady) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final positionMs = position.inMilliseconds.clamp(0, 1 << 31);
    _sharedPositionMs = positionMs;
    _sharedUpdatedAt = DateTime.now();
    _hasSharedState = true;

    try {
      debugPrint(
        'Writing seek state: songId=$_currentSongId, positionMs=$positionMs',
      );
      await _playbackRef.set({
        'songId': _currentSongId,
        'isPlaying': _player.playing,
        'positionMs': positionMs,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
    } catch (error) {
      _showMessage('Could not sync seek: $error');
    }
  }

  Future<void> _changeSong(Song song) async {
    if (song.id == _requestedSongId && _audioReady) return;
    final selectionGeneration = ++_localSongSelectionGeneration;
    _pendingLocalSongId = song.id;
    debugPrint(
      'Local song selected: songId=${song.id}, asset=${song.assetPath}, '
      'selectionGeneration=$selectionGeneration',
    );
    final wasPlaying = _player.playing;

    try {
      final loaded = await _loadSongAsset(song.id);
      if (!loaded) {
        if (_audioError != null) _showMessage(_audioError!);
        return;
      }
      if (selectionGeneration != _localSongSelectionGeneration) {
        debugPrint(
          'Ignored stale local song selection: songId=${song.id}, '
          'selectionGeneration=$selectionGeneration, '
          'latestSelectionGeneration=$_localSongSelectionGeneration',
        );
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      debugPrint(
        'Writing selected song to Firestore: songId=${song.id}, '
        'asset=${song.assetPath}, selectionGeneration=$selectionGeneration',
      );
      await _playbackRef.set({
        'songId': song.id,
        'isPlaying': wasPlaying,
        'positionMs': 0,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user?.uid,
      });
      _sharedPositionMs = 0;
      _sharedIsPlaying = wasPlaying;
      _sharedUpdatedAt = DateTime.now();
      _hasSharedState = true;
      if (wasPlaying) await _player.play();
      if (mounted) setState(() {});
    } catch (error) {
      _showMessage('Could not sync the selected song: $error');
    } finally {
      if (selectionGeneration == _localSongSelectionGeneration) {
        _pendingLocalSongId = null;
      }
    }
  }

  Future<void> _openRoomLibrary() async {
    final song = await Navigator.of(context).push<Song>(
      MaterialPageRoute(
        builder: (libraryContext) => MusicLibraryScreen(
          onSongSelected: (selected) async =>
              Navigator.of(libraryContext).pop(selected),
        ),
      ),
    );
    if (song != null) await _changeSong(song);
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _playbackSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listening room'),
        backgroundColor: bgColor,
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _roomRef.snapshots(),
          builder: (context, roomSnapshot) {
            if (roomSnapshot.hasError) {
              return const Center(child: Text('Could not load this room.'));
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
                    widget.roomCode,
                    style: const TextStyle(
                      color: accentColor,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Actual audio player and shared playback controls.
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, playerSnapshot) {
                    final isPlaying = playerSnapshot.data?.playing ?? false;

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.graphic_eq_rounded,
                            color: accentColor,
                            size: 34,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'ROOM PLAYBACK',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  songById(_currentSongId).title,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip:
                                    favouriteSongIds.contains(_currentSongId)
                                    ? 'Remove from favourites'
                                    : 'Add to favourites',
                                onPressed: () {
                                  setState(() {
                                    if (favouriteSongIds.contains(
                                      _currentSongId,
                                    )) {
                                      favouriteSongIds.remove(_currentSongId);
                                    } else {
                                      favouriteSongIds.add(_currentSongId);
                                    }
                                  });
                                  _showMessage(
                                    favouriteSongIds.contains(_currentSongId)
                                        ? 'Added to favourites'
                                        : 'Removed from favourites',
                                  );
                                },
                                icon: Icon(
                                  favouriteSongIds.contains(_currentSongId)
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: accentColor,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Change song',
                                onPressed: _openRoomLibrary,
                                icon: const Icon(
                                  Icons.queue_music_rounded,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            songById(_currentSongId).artist,
                            style: const TextStyle(color: Colors.white60),
                          ),
                          const SizedBox(height: 8),
                          if (_audioError != null)
                            Text(
                              _audioError!,
                              style: const TextStyle(color: Colors.redAccent),
                            )
                          else if (!_audioReady)
                            const CircularProgressIndicator(color: accentColor)
                          else
                            Text(
                              isPlaying ? 'Playing' : 'Paused',
                              style: const TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(height: 20),
                          StreamBuilder<Duration>(
                            stream: _player.positionStream,
                            builder: (context, positionSnapshot) {
                              final position =
                                  positionSnapshot.data ?? Duration.zero;
                              final duration =
                                  _player.duration ?? Duration.zero;

                              final maxMs = duration.inMilliseconds;
                              final valueMs = position.inMilliseconds;

                              return Column(
                                children: [
                                  Slider(
                                    value: maxMs > 0
                                        ? valueMs.clamp(0, maxMs).toDouble()
                                        : 0,
                                    max: maxMs > 0 ? maxMs.toDouble() : 1,
                                    activeColor: accentColor,
                                    onChangeStart: !_audioReady || maxMs <= 0
                                        ? null
                                        : (_) => _isSeeking = true,
                                    onChanged: !_audioReady || maxMs <= 0
                                        ? null
                                        : (value) {
                                            _player.seek(
                                              Duration(
                                                milliseconds: value.round(),
                                              ),
                                            );
                                          },
                                    onChangeEnd: !_audioReady || maxMs <= 0
                                        ? null
                                        : (value) async {
                                            final position = Duration(
                                              milliseconds: value.round(),
                                            );
                                            await _player.seek(position);
                                            _isSeeking = false;
                                            await _publishSeek(position);
                                          },
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(position),
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(duration),
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: _audioReady
                                  ? () => _togglePlayback(isPlaying)
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: bgColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: Icon(
                                isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              label: Text(
                                isPlaying ? 'Pause' : 'Play',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Everyone in the room can control playback.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 28),
                const Row(
                  children: [
                    Icon(Icons.people_alt_rounded, color: accentColor),
                    SizedBox(width: 10),
                    Expanded(
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
                  stream: _roomRef.collection('members').snapshots(),
                  builder: (context, membersSnapshot) {
                    if (membersSnapshot.hasError) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Unable to load room members.'),
                        ),
                      );
                    }

                    if (!membersSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: accentColor),
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
                          for (final member in members)
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: accentColor.withValues(
                                  alpha: 0.15,
                                ),
                                child: Icon(
                                  member.id == creatorUid
                                      ? Icons.star_rounded
                                      : Icons.person_rounded,
                                  color: accentColor,
                                ),
                              ),
                              title: Text(
                                member.id == user?.uid
                                    ? 'You'
                                    : 'Listener ${member.id.substring(0, min(6, member.id.length))}',
                              ),
                              subtitle: member.id == creatorUid
                                  ? const Text('Room host')
                                  : null,
                              trailing: member.id == user?.uid
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
