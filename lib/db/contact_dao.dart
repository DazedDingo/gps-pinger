import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/emergency_contact.dart';

/// Emergency contact CRUD. Phase 1 only exposes read + upsert — full CRUD
/// screen lands in Phase 2 with the panic feature.
class ContactDao {
  final Database db;
  ContactDao(this.db);

  Future<List<EmergencyContact>> all() async {
    final rows = await db.query('emergency_contacts', orderBy: 'id ASC');
    return rows.map(EmergencyContact.fromMap).toList();
  }

  Future<int> insert(EmergencyContact c) async {
    final map = c.toMap()..remove('id');
    return db.insert('emergency_contacts', map);
  }

  Future<int> update(EmergencyContact c) async {
    return db.update(
      'emergency_contacts',
      c.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  Future<int> delete(int id) async {
    return db.delete('emergency_contacts', where: 'id = ?', whereArgs: [id]);
  }
}
