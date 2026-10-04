import 'package:flutter/material.dart';

import '../../services/backup_service.dart';
import '../../services/auto_backup_service.dart';
import 'google_drive_backup_screen.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final _backupPasswordController = TextEditingController();

  final _backupConfirmController = TextEditingController();

  final _restorePasswordController = TextEditingController();

  bool _hideBackupPassword = true;
  bool _hideBackupConfirm = true;
  bool _hideRestorePassword = true;

  bool _isBackingUp = false;
  bool _isRestoring = false;

  @override
  void dispose() {
    _backupPasswordController.dispose();
    _backupConfirmController.dispose();
    _restorePasswordController.dispose();
    super.dispose();
  }

  Future<void> _createBackup() async {
    final password = _backupPasswordController.text;

    final confirm = _backupConfirmController.text;

    if (password.length < 8) {
      _showMessage('Backup මුරපදය අවම වශයෙන් අකුරු 8ක් විය යුතුයි.');
      return;
    }

    if (password != confirm) {
      _showMessage('Backup මුරපද දෙක එක සමාන නැහැ.');
      return;
    }

    setState(() {
      _isBackingUp = true;
    });

    try {
      await AutoBackupService.instance.savePassword(password);

      final savedPath = await BackupService.instance.createBackup(
        password: password,
      );

      if (!mounted) return;

      if (savedPath != null) {
        _showMessage('Backup සාර්ථකව සුරකින ලදී.');
        _backupPasswordController.clear();
        _backupConfirmController.clear();
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  Future<void> _restoreBackup() async {
    final password = _restorePasswordController.text;

    if (password.isEmpty) {
      _showMessage('Backup මුරපදය ඇතුළත් කරන්න.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('දත්ත නැවත ලබාගන්නද?'),
          content: const Text(
            'Backup එක restore කළාම දැනට මෙම device එකේ '
            'තිබෙන දත්ත Backup එකේ දත්ත වලින් ප්‍රතිස්ථාපනය වේ.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('අවලංගු කරන්න'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('නැවත ලබාගන්න'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isRestoring = true;
    });

    try {
      await BackupService.instance.restoreBackup(password: password);

      if (!mounted) return;

      _restorePasswordController.clear();

      _showMessage(
        'දත්ත සාර්ථකව නැවත ලබාගන්නා ලදී. '
        'යෙදුම නැවත ආරම්භ කරන්න.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('දත්ත සුරැකීම')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.backup_outlined, size: 56),
              const SizedBox(height: 16),
              const Text(
                'දත්ත සුරැකීම සහ නැවත ලබාගැනීම',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'ඔබේ භාණ්ඩ, විකුණුම්, තොග, '
                'පාරිභෝගිකයින් සහ නය තොරතුරු Backup එකකට '
                'සුරැකිය හැක.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Backup එකක් සාදන්න',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Backup file එක ආරක්ෂිතව තබාගැනීමට '
                        'මුරපදයක් යොදන්න.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _backupPasswordController,
                        obscureText: _hideBackupPassword,
                        decoration: _passwordDecoration(
                          'Backup මුරපදය',
                          _hideBackupPassword,
                          () {
                            setState(() {
                              _hideBackupPassword = !_hideBackupPassword;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _backupConfirmController,
                        obscureText: _hideBackupConfirm,
                        decoration: _passwordDecoration(
                          'Backup මුරපදය නැවත ඇතුළත් කරන්න',
                          _hideBackupConfirm,
                          () {
                            setState(() {
                              _hideBackupConfirm = !_hideBackupConfirm;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '⚠ මෙම Backup මුරපදය අමතක වුණොත් '
                        'Backup එක නැවත ලබාගැනීමට නොහැක.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _isBackingUp ? null : _createBackup,
                          icon: const Icon(Icons.save_alt),
                          label: _isBackingUp
                              ? const CircularProgressIndicator()
                              : const Text('Backup එක සුරකින්න'),
                        ),
                      ),
                      SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                const GoogleDriveBackupScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.cloud_outlined),
                          label: const Text(
                            'Google Drive සම්බන්ධ කරන්න',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Backup එකෙන් දත්ත නැවත ලබාගන්න',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'පරණ device එකේ Backup file එක '
                        'අලුත් device එකට ගෙනවිත් මෙතැනින් තෝරන්න.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _restorePasswordController,
                        obscureText: _hideRestorePassword,
                        decoration: _passwordDecoration(
                          'Backup මුරපදය',
                          _hideRestorePassword,
                          () {
                            setState(() {
                              _hideRestorePassword = !_hideRestorePassword;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _isRestoring ? null : _restoreBackup,
                          icon: const Icon(Icons.restore),
                          label: _isRestoring
                              ? const CircularProgressIndicator()
                              : const Text('දත්ත නැවත ලබාගන්න'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Backup file එක USB, Google Drive, '
                'OneDrive හෝ වෙනත් ආරක්ෂිත තැනක තබාගන්න.',
                textAlign: TextAlign.center,
              ),
            ],

          ),
        ),
      ),
    );
  }



  InputDecoration _passwordDecoration(
    String label,
    bool hidden,
    VoidCallback onToggle,
  ) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(hidden ? Icons.visibility : Icons.visibility_off),
      ),
    );
  }
}
