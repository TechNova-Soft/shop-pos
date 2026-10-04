import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite_ffi/sqflite_ffi.dart';

import '../database/database_service.dart';

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  static const List<int> _magic = [84, 78, 80, 79, 83, 66, 75, 49];

  static const int _formatVersion = 1;
  static const int _saltLength = 16;

  final AesGcm _encryption = AesGcm.with256bits();

  final Argon2id _keyDerivation = Argon2id(
    memory: 19 * 1024,
    parallelism: 1,
    iterations: 2,
    hashLength: 32,
  );

  String createAutomaticFileName() {
    final now = DateTime.now();

    String two(int value) => value.toString().padLeft(2, '0');

    return 'TechNovaPOS_Auto_'
        '${now.year}-'
        '${two(now.month)}-'
        '${two(now.day)}_'
        '${two(now.hour)}-'
        '${two(now.minute)}-'
        '${two(now.second)}.tnbackup';
  }

  Future<Uint8List> createEncryptedBackupBytes({
    required String password,
  }) async {
    if (password.length < 8) {
      throw Exception('Backup මුරපදය අවම වශයෙන් අකුරු 8ක් විය යුතුයි.');
    }

    final databasePath = await DatabaseService.instance.getDatabasePath();

    final databaseFile = File(databasePath);

    if (!await databaseFile.exists()) {
      throw Exception('සුරැකීමට දත්ත ගබඩාව හමු නොවීය.');
    }

    await DatabaseService.instance.close();

    final databaseBytes = await databaseFile.readAsBytes();

    final random = Random.secure();

    final salt = List<int>.generate(_saltLength, (_) => random.nextInt(256));

    final secretKey = await _keyDerivation.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    final secretBox = await _encryption.encrypt(
      databaseBytes,
      secretKey: secretKey,
    );

    return Uint8List.fromList([
      ..._magic,
      _formatVersion,
      ...salt,
      ...secretBox.concatenation(),
    ]);
  }

  Future<Uri?> createBackup({required String password}) async {
    if (password.length < 8) {
      throw Exception('Backup මුරපදය අවම වශයෙන් අකුරු 8ක් විය යුතුයි.');
    }

    final databasePath = await DatabaseService.instance.getDatabasePath();

    final databaseFile = File(databasePath);

    if (!await databaseFile.exists()) {
      throw Exception('සුරැකීමට දත්ත ගබඩාව හමු නොවීය.');
    }

    // Close SQLite before copying its file.
    await DatabaseService.instance.close();

    try {
      final databaseBytes = await databaseFile.readAsBytes();

      final random = Random.secure();

      final salt = List<int>.generate(_saltLength, (_) => random.nextInt(256));

      final secretKey = await _keyDerivation.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );

      final secretBox = await _encryption.encrypt(
        databaseBytes,
        secretKey: secretKey,
      );

      final backupBytes = Uint8List.fromList([
        ..._magic,
        _formatVersion,
        ...salt,
        ...secretBox.concatenation(),
      ]);

      final fileName = _createBackupFileName();

      return await FilePicker.saveFile(
        dialogTitle: 'දත්ත Backup එක සුරකින්න',
        fileName: fileName,
        bytes: backupBytes,
        mimeType: 'application/octet-stream',
        allowedExtensions: ['tnbackup'],
      );
    } finally {
      // Re-open the database on the next database request.
    }
  }

  Future<void> restoreBackup({required String password}) async {
    if (password.isEmpty) {
      throw Exception('Backup මුරපදය ඇතුළත් කරන්න.');
    }

    final selectedFile = await FilePicker.pickFile(
      dialogTitle: 'Backup ගොනුව තෝරන්න',
      allowedExtensions: ['tnbackup'],
    );

    if (selectedFile == null) {
      return;
    }

    final backupBytes = await selectedFile.readAsBytes();

    final minimumLength = _magic.length + 1 + _saltLength + 28;

    if (backupBytes.length < minimumLength) {
      throw Exception('Backup ගොනුව වලංගු නැහැ.');
    }

    for (var i = 0; i < _magic.length; i++) {
      if (backupBytes[i] != _magic[i]) {
        throw Exception('මෙය TechNova Shop POS Backup ගොනුවක් නොවේ.');
      }
    }

    final version = backupBytes[_magic.length];

    if (version != _formatVersion) {
      throw Exception(
        'මෙම Backup version එක සහ app version එක ගැළපෙන්නේ නැහැ.',
      );
    }

    final saltStart = _magic.length + 1;
    final saltEnd = saltStart + _saltLength;

    final salt = backupBytes.sublist(saltStart, saltEnd);

    final encryptedBytes = backupBytes.sublist(saltEnd);

    try {
      final secretKey = await _keyDerivation.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );

      final secretBox = SecretBox.fromConcatenation(
        encryptedBytes,
        nonceLength: _encryption.nonceLength,
        macLength: _encryption.macAlgorithm.macLength,
      );

      final databaseBytes = await _encryption.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      await _validateDatabase(databaseBytes);

      await _replaceDatabase(databaseBytes);
    } on SecretBoxAuthenticationError {
      throw Exception('Backup මුරපදය වැරදියි හෝ Backup ගොනුව වෙනස් වී ඇත.');
    }
  }

  Future<void> _validateDatabase(List<int> databaseBytes) async {
    final databasePath = await DatabaseService.instance.getDatabasePath();

    final directory = Directory(File(databasePath).parent.path);

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final tempPath = '$databasePath.restore_check';

    final tempFile = File(tempPath);

    try {
      await tempFile.writeAsBytes(databaseBytes, flush: true);

      final testDatabase = await databaseFactory.openDatabase(
        tempPath,
        options: OpenDatabaseOptions(readOnly: true),
      );

      try {
        final requiredTables = [
          'shop_profile',
          'users',
          'categories',
          'customers',
          'products',
          'quick_quantities',
          'stock_movements',
          'sales',
          'sale_items',
          'credit_payments',
          'settings',
        ];

        final placeholders = List.filled(requiredTables.length, '?').join(', ');

        final result = await testDatabase.rawQuery('''
          SELECT name
          FROM sqlite_master
          WHERE type = 'table'
          AND name IN ($placeholders)
          ''', requiredTables);

        final foundTables = result.map((row) => row['name'] as String).toSet();

        final isValid = requiredTables.every(foundTables.contains);

        if (!isValid) {
          throw Exception('Backup database structure එක වලංගු නැහැ.');
        }
      } finally {
        await testDatabase.close();
      }
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> _replaceDatabase(List<int> databaseBytes) async {
    final databasePath = await DatabaseService.instance.getDatabasePath();

    final databaseFile = File(databasePath);

    final tempPath = '$databasePath.restore';

    final oldPath = '$databasePath.before_restore';

    final tempFile = File(tempPath);
    final oldFile = File(oldPath);

    await tempFile.writeAsBytes(databaseBytes, flush: true);

    await DatabaseService.instance.close();

    try {
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      if (await databaseFile.exists()) {
        await databaseFile.rename(oldPath);
      }

      await tempFile.rename(databasePath);

      if (await oldFile.exists()) {
        await oldFile.delete();
      }
    } catch (_) {
      if (await databaseFile.exists()) {
        await databaseFile.delete();
      }

      if (await oldFile.exists()) {
        await oldFile.rename(databasePath);
      }

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      rethrow;
    }
  }

  String _createBackupFileName() {
    final now = DateTime.now();

    String two(int value) => value.toString().padLeft(2, '0');

    return 'TechNovaPOS_Backup_'
        '${now.year}-'
        '${two(now.month)}-'
        '${two(now.day)}_'
        '${two(now.hour)}-'
        '${two(now.minute)}-'
        '${two(now.second)}.tnbackup';
  }
}
