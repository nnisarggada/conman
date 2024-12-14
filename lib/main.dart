import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:conman/contact.dart';
import 'package:conman/theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const Contacts());
}

class Contacts extends StatelessWidget {
  const Contacts({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Contacts',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: MaterialTheme.lightScheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: MaterialTheme.darkScheme(),
      ),
      home: const HomePage(title: 'Contacts'),
    );
  }
}

class HomePage extends StatefulWidget {
  final String title;
  const HomePage({super.key, required this.title});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Contact>? _contacts;
  List<Contact>? _filteredContacts;
  bool _permissionDenied = false;
  TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Permission denied :/',
                style: TextStyle(color: Colors.red, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              Text(
                'Please allow contacts access in your device settings.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _openSettings,
                child: Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    if (_contacts == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return SafeArea(
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_contacts?.length ?? 0} contacts',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w200,
                    ),
                  ),
                  SizedBox(height: 10),
                  _buildSearchBar(),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                physics: BouncingScrollPhysics(),
                itemCount: _filteredContacts?.length ?? 0,
                itemBuilder: (context, index) {
                  final contact = _filteredContacts![index];
                  return _buildContactTile(contact);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchContacts();
    searchController.addListener(() {
      _filterContacts();
    });
  }

  Widget _buildContactTile(Contact contact) {
    Color bgColor = _getRandomColor();

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Text(
          contact.displayName,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        onTap: () async {
          final fullContact = await FlutterContacts.getContact(contact.id);
          if (fullContact != null) {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ContactPage(fullContact)),
            );
          }
        },
        leading: CircleAvatar(
          radius: 30,
          backgroundImage: contact.photo != null
              ? MemoryImage(contact.photo!)
              : contact.thumbnail != null
                  ? MemoryImage(contact.thumbnail!)
                  : null,
          backgroundColor: bgColor,
          child: contact.photo == null && contact.thumbnail == null
              ? Text(
                  contact.name.first.isEmpty
                      ? '?'
                      : contact.name.last.isEmpty
                          ? contact.name.first[0]
                          : contact.name.first[0] + contact.name.last[0],
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color:
                          _isColorLight(bgColor) ? Colors.black : Colors.white),
                )
              : null,
        ),
        trailing: Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        hintText: 'Search Contacts',
        prefixIcon: Icon(Icons.search),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert),
          onSelected: (value) async {
            switch (value) {
              case 'import':
                _importContacts();
                break;
              case 'export':
                await _exportContacts();
                break;
              case 'settings':
                _openSettings();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'import',
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Import Contacts'),
              ),
            ),
            PopupMenuItem<String>(
              value: 'export',
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Export Contacts'),
              ),
            ),
            PopupMenuItem<String>(
              value: 'settings',
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Settings'),
              ),
            ),
          ],
        ),
      ),
    );
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

      final vcfData = _contacts!.map((contact) => contact.toVCard()).join('\n');

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

  Future<void> _fetchContacts() async {
    if (!await FlutterContacts.requestPermission(readonly: false)) {
      setState(() {
        _permissionDenied = true;
      });
      return;
    }

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: true,
    );

    setState(() {
      _contacts = contacts;
      _filteredContacts = List.from(_contacts!);
    });
  }

  void _filterContacts() {
    if (searchController.text.isEmpty) {
      setState(() {
        _filteredContacts = List.from(_contacts!);
      });
      return;
    }

    final query = searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = _contacts!.where((contact) {
        final nameMatch = contact.displayName.toLowerCase().contains(query);
        final phoneMatch = contact.phones.any((phone) =>
            phone.number.replaceAll(RegExp(r'\D'), '').contains(query));
        final emailMatch = contact.emails
            .any((email) => email.address.toLowerCase().contains(query));
        return nameMatch || phoneMatch || emailMatch;
      }).toList();
    });
  }

  Color _getRandomColor() {
    final random = Random();
    return Colors.primaries[random.nextInt(Colors.primaries.length)];
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

        await _fetchContacts();

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

  bool _isColorLight(Color color) {
    final brightness = 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
    return brightness > 0.775;
  }

  Future<void> _openSettings() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Opening app settings...'),
          backgroundColor: Theme.of(context).colorScheme.primary),
    );
    sleep(const Duration(seconds: 2));
    openAppSettings();
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
}
