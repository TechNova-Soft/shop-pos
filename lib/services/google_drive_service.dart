import 'dart:convert';
import 'dart:io';
// import 'dart:typed_data';

import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:sqflite_common/sqlite_api.dart';

import '../core/config/google_config.dart';
import '../database/database_service.dart';
import 'package:flutter/foundation.dart';

class GoogleDriveService {
  GoogleDriveService._();

  static final GoogleDriveService instance = GoogleDriveService._();

  static const String _driveScope =
      'https://www.googleapis.com/auth/drive.file';

  static const String _emailScope =
      'https://www.googleapis.com/auth/userinfo.email';

  static const String _backupFolderName = 'TechNova POS Backups';
  static const int _maxGoogleDriveBackups = 20;

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    params: GoogleSignInParams(
      clientId: Platform.isWindows ? GoogleConfig.windowsClientId : null,
      clientSecret: Platform.isWindows
          ? GoogleConfig.windowsClientSecret
          : null,
      redirectPort: 8000,
      scopes: <String>['openid', 'profile', 'email', _driveScope, _emailScope],
    ),
  );

  // ---------------------------------------------------------------------------
  // Restore previously saved Google sign-in session
  // ---------------------------------------------------------------------------

  Future<bool> restoreSavedSignIn() async {
    try {
      final credentials = await _googleSignIn.silentSignIn();

      if (credentials == null) {
        return false;
      }

      await _saveSetting('google_drive_connected', 'true');

      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Connect Google account
  // ---------------------------------------------------------------------------

  Future<bool> connect() async {
    try {
      final credentials = await _googleSignIn.signIn();

      if (credentials == null) {
        return false;
      }

      final email = await getAccountEmail();

      if (email != null && email.isNotEmpty) {
        await _saveSetting('google_drive_email', email);
      }

      await _saveSetting('google_drive_connected', 'true');

      final folderId = await ensureBackupFolder();

      await _saveSetting('google_drive_folder_id', folderId);

      return true;
    } catch (e) {
      await _saveSetting('google_drive_connected', 'false');

      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Disconnect Google account
  // ---------------------------------------------------------------------------

  Future<void> disconnect() async {
    try {
      await _googleSignIn.signOut();
    } finally {
      await _deleteSetting('google_drive_email');

      await _deleteSetting('google_drive_folder_id');

      await _saveSetting('google_drive_connected', 'false');
    }
  }

  // ---------------------------------------------------------------------------
  // Check connection
  // ---------------------------------------------------------------------------

  Future<bool> isConnected() async {
    final connected = await _getSetting('google_drive_connected');

    if (connected != 'true') {
      return false;
    }

    try {
      final client = await _googleSignIn.authenticatedClient;
      return client != null;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Get Google account email
  // ---------------------------------------------------------------------------

  Future<String?> getAccountEmail() async {
    final client = await _googleSignIn.authenticatedClient;

    if (client == null) {
      return null;
    }

    final response = await client.get(
      Uri.parse('https://openidconnect.googleapis.com/v1/userinfo'),
    );

    if (response.statusCode != 200) {
      throw Exception('Google ගිණුමේ තොරතුරු ලබා ගැනීමට නොහැකි විය.');
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Google ගිණුමේ තොරතුරු වල ආකෘතිය වැරදියි.');
    }

    final email = data['email'];

    if (email is! String || email.isEmpty) {
      return null;
    }

    return email;
  }

  // ---------------------------------------------------------------------------
  // Create / find backup folder
  // ---------------------------------------------------------------------------

  Future<String> ensureBackupFolder() async {
    debugPrint('=== Google Drive: ensureBackupFolder START ===');

    final savedFolderId = await _getSetting(
      'google_drive_folder_id',
    );

    debugPrint(
      'Saved Google Drive folder ID: $savedFolderId',
    );

    final api = await _driveApi();

    // -------------------------------------------------------------------------
    // 1. Check previously saved folder
    // -------------------------------------------------------------------------

    if (savedFolderId != null && savedFolderId.isNotEmpty) {
      try {
        debugPrint(
          'Checking saved folder ID: $savedFolderId',
        );

        final response = await api.files.get(
          savedFolderId,
          $fields: 'id,name,mimeType,trashed,parents',
        );

        if (response is drive.File) {
          final existing = response;

          debugPrint(
            'Saved folder response: '
                'id=${existing.id}, '
                'name=${existing.name}, '
                'mimeType=${existing.mimeType}, '
                'trashed=${existing.trashed}',
          );

          if (existing.id != null &&
              existing.trashed != true &&
              existing.mimeType ==
                  'application/vnd.google-apps.folder') {
            debugPrint(
              'Using existing Google Drive folder: ${existing.id}',
            );

            return existing.id!;
          }
        }
      } catch (e) {
        debugPrint(
          'Saved folder not available: $e',
        );
      }
    }

    // -------------------------------------------------------------------------
    // 2. Search existing folder in My Drive root
    // -------------------------------------------------------------------------

    debugPrint(
      'Searching for "$_backupFolderName"...',
    );

    final result = await api.files.list(
      q: "'root' in parents "
          "and name = '$_backupFolderName' "
          "and mimeType = "
          "'application/vnd.google-apps.folder' "
          "and trashed = false",
      spaces: 'drive',
      $fields: 'files(id,name,mimeType,trashed,parents)',
      pageSize: 20,
    );

    final files = result.files ?? <drive.File>[];

    debugPrint(
      'Folder search returned ${files.length} result(s).',
    );

    for (final file in files) {
      debugPrint(
        'Found folder: '
            'id=${file.id}, '
            'name=${file.name}, '
            'mimeType=${file.mimeType}, '
            'trashed=${file.trashed}',
      );

      if (file.id != null &&
          file.trashed != true &&
          file.mimeType ==
              'application/vnd.google-apps.folder') {
        final folderId = file.id!;

        await _saveSetting(
          'google_drive_folder_id',
          folderId,
        );

        debugPrint(
          'Using found folder: $folderId',
        );

        return folderId;
      }
    }

    // -------------------------------------------------------------------------
    // 3. Create new folder in My Drive root
    // -------------------------------------------------------------------------

    debugPrint(
      'Folder not found. Creating "$_backupFolderName"...',
    );

    final folder = drive.File()
      ..name = _backupFolderName
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = <String>['root'];

    final created = await api.files.create(
      folder,
      $fields: 'id,name,mimeType,trashed,parents,webViewLink',
    );

    debugPrint(
      'Create response: '
          'id=${created.id}, '
          'name=${created.name}, '
          'mimeType=${created.mimeType}, '
          'trashed=${created.trashed}, '
          'parents=${created.parents}, '
          'webViewLink=${created.webViewLink}',
    );

    final folderId = created.id;

    if (folderId == null || folderId.isEmpty) {
      throw Exception(
        'Google Drive backup folder එක සාදාගැනීමට නොහැකි විය.',
      );
    }

    await _saveSetting(
      'google_drive_folder_id',
      folderId,
    );

    debugPrint(
      'Google Drive folder successfully created: $folderId',
    );

    debugPrint(
      '=== Google Drive: ensureBackupFolder END ===',
    );

    return folderId;
  }

  // ---------------------------------------------------------------------------
  // Upload encrypted backup
  // ---------------------------------------------------------------------------

  Future<String> uploadBackup({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final api = await _driveApi();

    final folderId = await ensureBackupFolder();

    final metadata = drive.File()
      ..name = fileName
      ..parents = <String>[folderId]
      ..mimeType = 'application/octet-stream';

    final media = drive.Media(Stream<List<int>>.value(bytes), bytes.length);

    final uploaded = await api.files.create(
      metadata,
      uploadMedia: media,
      $fields: 'id,name,mimeType,webViewLink',
    );

    final fileId = uploaded.id;

    if (fileId == null || fileId.isEmpty) {
      throw Exception('Backup ගොනුව Google Drive වෙත යැවීමට නොහැකි විය.');
    }

    await _saveSetting(
      'google_drive_last_backup',
      DateTime.now().toIso8601String(),
    );

// Keep only the latest 20 backup files in Google Drive.
    await cleanupOldBackups();

    return fileId;
  }

  // ---------------------------------------------------------------------------
  // Get Drive API instance
  // ---------------------------------------------------------------------------

  Future<drive.DriveApi> _driveApi() async {
    final client = await _googleSignIn.authenticatedClient;

    if (client == null) {
      throw Exception('Google ගිණුම සම්බන්ධ කරලා නැහැ.');
    }

    return drive.DriveApi(client);
  }

  Future<void> cleanupOldBackups() async {
    try {
      debugPrint(
        'Checking Google Drive backup retention...',
      );

      final api = await _driveApi();
      final folderId = await ensureBackupFolder();

      final result = await api.files.list(
        q: "'$folderId' in parents "
            "and name contains '.tnbackup' "
            "and trashed = false",
        spaces: 'drive',
        $fields: 'files(id,name,mimeType,createdTime,modifiedTime)',
        pageSize: 100,
        orderBy: 'createdTime asc',
      );

      final backups = result.files ?? <drive.File>[];

      debugPrint(
        'Google Drive backup count: ${backups.length}',
      );

      if (backups.length <= _maxGoogleDriveBackups) {
        debugPrint(
          'Backup count is within the limit of $_maxGoogleDriveBackups.',
        );
        return;
      }

      final deleteCount =
          backups.length - _maxGoogleDriveBackups;

      debugPrint(
        'Deleting $deleteCount old backup(s)...',
      );

      for (int i = 0; i < deleteCount; i++) {
        final oldBackup = backups[i];

        final fileId = oldBackup.id;

        if (fileId == null || fileId.isEmpty) {
          continue;
        }

        try {
          await api.files.delete(fileId);

          debugPrint(
            'Old backup deleted: ${oldBackup.name} '
                '| ID: $fileId',
          );
        } catch (error) {
          // Retention failure should not break the successful backup.
          debugPrint(
            'Failed to delete old backup '
                '${oldBackup.name}: $error',
          );
        }
      }

      debugPrint(
        'Google Drive backup retention cleanup completed.',
      );
    } catch (error, stackTrace) {
      // Backup itself should remain successful even if cleanup fails.
      debugPrint(
        'Google Drive backup cleanup failed: $error',
      );
      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Save setting
  // ---------------------------------------------------------------------------

  Future<void> _saveSetting(String key, String value) async {
    final db = await DatabaseService.instance.database;

    await db.insert('settings', <String, Object?>{
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------------------------------------------------------------------------
  // Get setting
  // ---------------------------------------------------------------------------

  Future<String?> _getSetting(String key) async {
    final db = await DatabaseService.instance.database;

    final rows = await db.query(
      'settings',
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final value = rows.first['value'];

    if (value is String) {
      return value;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Delete setting
  // ---------------------------------------------------------------------------

  Future<void> _deleteSetting(String key) async {
    final db = await DatabaseService.instance.database;

    await db.delete('settings', where: 'key = ?', whereArgs: <Object?>[key]);
  }
}
