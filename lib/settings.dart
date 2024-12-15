// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        child: const Text('Settings Page'),
      ),
    );
  }

  Future<void> _exportContacts(BuildContext context) async {
    await _requestStoragePermission();

    try {
      // Fetch contacts from device
      List<Contact> contacts = await FlutterContacts.getContacts();

      // Convert contacts to VCard format
      String vcfData = contacts.map((contact) => contact.toVCard()).join('\n');

      // Save the VCF data to a file
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Contacts File',
        fileName: 'contacts.vcf',
        type: FileType.custom,
        allowedExtensions: ['vcf'],
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

      // Write the vcf data to the file
      final file = File(outputPath);
      await file.writeAsString(vcfData);

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

  Future<void> _importContacts(BuildContext context) async {
    await _requestStoragePermission();

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

  Future<void> _requestStoragePermission() async {
    PermissionStatus status = await Permission.storage.request();

    if (status.isGranted) {
      return;
    } else if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Allow Storage permission in app settings',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
    } else if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Allow Storage permission in app settings',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
      openAppSettings();
    }
  }
}
