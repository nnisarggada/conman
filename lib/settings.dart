// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _appVersion = 'Unknown';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_download),
                  title: const Text('Import Contacts'),
                  subtitle: const Text('Import contacts from a .vcf file'),
                  onTap: _importContacts,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.file_upload),
                  title: const Text('Export Contacts'),
                  subtitle: const Text('Export your contacts to a .vcf file'),
                  onTap: _exportContacts,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Sync with PACMAN'),
                  subtitle: const Text('Sync your data with PACMAN'),
                  onTap: _syncWithPacman,
                ),
                const Divider(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _appVersion,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onTertiaryContainer
                      .withValues(
                        alpha: 0.5,
                      ),
                  fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _exportContacts() async {
    await _requestStoragePermission();

    try {
      Uint8List stringToUint8List(String data) {
        // Convert string to bytes (List<int>)
        List<int> encoded = utf8.encode(data);

        // Convert List<int> to Uint8List
        Uint8List uint8List = Uint8List.fromList(encoded);

        return uint8List;
      }

      List<Contact>? contacts = await FlutterContacts.getContacts();

      final vcfData = contacts.map((contact) => contact.toVCard()).join('\n');

      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Contacts File',
        fileName: 'contacts.vcf',
        type: FileType.custom,
        allowedExtensions: ['vcf'],
        bytes: stringToUint8List(vcfData),
      );

      if (outputPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Export canceled', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contacts exported to $outputPath'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export contacts: $e',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importContacts() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['vcf'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final file = File(filePath);

        if (!await file.exists()) {
          throw Exception('Selected file does not exist');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Importing contacts...'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );

        final vcfData = await file.readAsString();

        final vCards = vcfData
            .split('END:VCARD')
            .where((vcard) => vcard.trim().isNotEmpty)
            .toList();

        for (var vCard in vCards) {
          final contact = Contact.fromVCard(vCard);
          await FlutterContacts.insertContact(contact);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${vCards.length} contacts imported successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('No file selected', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import contacts: $e',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion =
          'Version ${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }

  Future<void> _requestStoragePermission() async {
    PermissionStatus status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      return;
    } else if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Storage permission denied :/',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red),
      );
    } else if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Allow Storage permission in app settings',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red),
      );
      openAppSettings();
    }
  }

  Future<void> _syncWithPacman() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coming soon...'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
