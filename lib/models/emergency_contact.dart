/// Phase 2 will wire contacts into the panic-share builder. Phase 1 only
/// stores the table so the schema is stable from v1 and no migration is
/// needed later.
class EmergencyContact {
  final int? id;
  final String name;
  final String phoneE164;

  const EmergencyContact({
    this.id,
    required this.name,
    required this.phoneE164,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone_e164': phoneE164,
      };

  factory EmergencyContact.fromMap(Map<String, Object?> m) => EmergencyContact(
        id: m['id'] as int?,
        name: m['name'] as String,
        phoneE164: m['phone_e164'] as String,
      );
}
