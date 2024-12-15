// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:conman/contact.dart';
import 'package:conman/settings.dart';
import 'package:conman/theme.dart';
import 'package:conman/addcontact.dart';
import 'package:flutter/cupertino.dart';
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
              const Text(
                'Permission denied :/',
                style: TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _openSettings,
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    if (_contacts == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return SafeArea(
      child: Scaffold(
        floatingActionButton: Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: 64,
            height: 64,
            child: FittedBox(
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddContactPage()),
                  );
                },
                tooltip: 'Add New Contact',
                elevation: 10,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, size: 36),
              ),
            ),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                  const SizedBox(height: 6),
                  _buildSearchBar(),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: CupertinoScrollbar(
                  thumbVisibility: true,
                  thicknessWhileDragging: 12,
                  thickness: 8,
                  radius: const Radius.circular(8),
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filteredContacts?.length ?? 0,
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts![index];
                      return _buildContactTile(contact);
                    },
                  ),
                ),
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      title: Text(
        contact.displayName,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
        radius: 22,
        backgroundImage: contact.photo != null
            ? MemoryImage(contact.photo!)
            : contact.thumbnail != null
                ? MemoryImage(contact.thumbnail!)
                : null,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: contact.photo == null && contact.thumbnail == null
            ? Text(
                contact.name.first.isEmpty
                    ? '?'
                    : contact.name.last.isEmpty
                        ? contact.name.first[0]
                        : contact.name.first[0] + contact.name.last[0],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            hintText: 'Search Contacts',
            prefixIcon: const Icon(Icons.search, size: 18),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            suffixIcon: IconButton(
              icon: const Icon(Icons.settings, size: 18),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
            )),
      ),
    );
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

  Future<void> _openSettings() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Opening app settings...'),
          backgroundColor: Theme.of(context).colorScheme.primary),
    );
    sleep(const Duration(seconds: 2));
    openAppSettings();
  }
}
