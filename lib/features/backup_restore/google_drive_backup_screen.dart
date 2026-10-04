import 'package:flutter/material.dart';

import '../../services/google_drive_service.dart';

class GoogleDriveBackupScreen extends StatefulWidget {
  const GoogleDriveBackupScreen({
    super.key,
  });

  @override
  State<GoogleDriveBackupScreen> createState() =>
      _GoogleDriveBackupScreenState();
}

class _GoogleDriveBackupScreenState
    extends State<GoogleDriveBackupScreen> {
  bool _isLoading = true;
  bool _isConnecting = false;
  bool _connected = false;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final connected =
    await GoogleDriveService.instance
        .restoreSavedSignIn();

    String? email;

    if (connected) {
      email =
      await GoogleDriveService.instance
          .getAccountEmail();
    }

    if (!mounted) return;

    setState(() {
      _connected = connected;
      _email = email;
      _isLoading = false;
    });
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      final success =
      await GoogleDriveService.instance.connect();

      if (!mounted) return;

      if (!success) {
        _showMessage(
          'Google ගිණුම සම්බන්ධ කිරීම අවලංගු කරන ලදී.',
        );
        return;
      }

      final email =
      await GoogleDriveService.instance
          .getAccountEmail();

      setState(() {
        _connected = true;
        _email = email;
      });

      _showMessage(
        'Google ගිණුම සාර්ථකව සම්බන්ධ කරන ලදී.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    await GoogleDriveService.instance.disconnect();

    if (!mounted) return;

    setState(() {
      _connected = false;
      _email = null;
    });

    _showMessage(
      'Google ගිණුම විසන්ධි කරන ලදී.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Drive Backup'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 600,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.cloud_outlined,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Google Drive Backup',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_connected) ...[
                      const Row(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Google ගිණුම සම්බන්ධයි',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _email ?? 'ගිණුම',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Backup ගොනු "TechNova POS Backups" '
                            'ගොනුව තුළ සුරැකේ.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed:
                        _isConnecting ? null : _disconnect,
                        icon: const Icon(
                          Icons.link_off,
                        ),
                        label: const Text(
                          'Google ගිණුම විසන්ධි කරන්න',
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'ඔබේ Google ගිණුම සම්බන්ධ කරලා '
                            'Backup ගොනු ඔබගේ Google Drive එකේ '
                            'සුරකින්න.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed:
                          _isConnecting ? null : _connect,
                          icon: const Icon(
                            Icons.login,
                          ),
                          label: _isConnecting
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                            CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                              : const Text(
                            'Google ගිණුම සම්බන්ධ කරන්න',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}