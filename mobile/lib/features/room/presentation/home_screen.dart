import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/server_config_provider.dart';
import '../providers/room_provider.dart';
import 'room_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _usernameController = TextEditingController();
  final _roomIdController = TextEditingController();
  final _serverUrlController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final url = ref.read(serverUrlProvider);
      if (_serverUrlController.text.isEmpty) {
        _serverUrlController.text = url;
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _roomIdController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveServerUrl() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) {
      _showError('Enter server URL (e.g. https://your-server.com)');
      return;
    }
    await ref.read(serverConfigProvider.notifier).setServerUrl(url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server URL saved')),
      );
    }
  }

  Future<void> _createRoom() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _showError('Enter a username');
      return;
    }

    await _saveServerUrl();

    setState(() => _isLoading = true);
    try {
      final response = await ref.read(roomSessionProvider.notifier).createRoom(username);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoomScreen(
            roomId: response.roomId,
            username: username,
            participantId: response.hostId,
          ),
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinRoom() async {
    final username = _usernameController.text.trim();
    final roomId = _roomIdController.text.trim().toUpperCase();

    if (username.isEmpty || roomId.isEmpty) {
      _showError('Enter username and room ID');
      return;
    }

    await _saveServerUrl();

    setState(() => _isLoading = true);
    try {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoomScreen(roomId: roomId, username: username),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serverConfig = ref.watch(serverConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rave')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Watch together',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Works on any network — share the APK and room ID with friends.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _serverUrlController,
                readOnly: true,
                // decoration: InputDecoration(
                //   labelText: 'Server URL',
                //   hintText: serverConfig.maybeWhen(
                //     data: (url) => url,
                //     orElse: () => 'https://your-server.com',
                //   ),
                //   helperText: 'Same for everyone using the app',
                //   suffixIcon: IconButton(
                //     icon: const Icon(Icons.save),
                //     onPressed: _saveServerUrl,
                //     tooltip: 'Save server URL',
                //   ),
                // ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Your display name',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _roomIdController,
                decoration: const InputDecoration(
                  labelText: 'Room ID (to join)',
                  hintText: 'e.g. A1B2C3D4',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _isLoading ? null : _createRoom,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Room'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isLoading ? null : _joinRoom,
                child: const Text('Join Room'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
