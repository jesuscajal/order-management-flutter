class Phone {
  const Phone(this.number);

  final String number;
}

class Email {
  const Email(this.address);

  final String address;
}

class Contact {
  const Contact({
    this.displayName = '',
    this.phones = const [],
    this.emails = const [],
  });

  final String displayName;
  final List<Phone> phones;
  final List<Email> emails;
}

class FlutterContacts {
  static Future<bool> requestPermission() async => false;

  static Future<List<Contact>> getContacts({
    bool withProperties = false,
    bool withPhoto = false,
  }) async {
    return const [];
  }
}
