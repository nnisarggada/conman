import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactPage extends StatefulWidget {
  final Contact contact;
  const ContactPage(this.contact, {super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.contact.displayName)),
      body: Column(children: [
        Text('First name: ${widget.contact.name.first}'),
        Text('Last name: ${widget.contact.name.last}'),
        Text(
            'Phone number: ${widget.contact.phones.isNotEmpty ? widget.contact.phones.first.number : '(none)'}'),
        Text(
            'Email address: ${widget.contact.emails.isNotEmpty ? widget.contact.emails.first.address : '(none)'}'),
      ]));
}
