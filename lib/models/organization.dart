/// An organization that groups multiple user accounts under a single admin.
class Organization {
  final String id;
  final String name;
  final String ownerId; // admin's user id
  final String inviteCode; // 8-char alphanumeric code for joining
  final DateTime createdAt;

  Organization({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.inviteCode,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Organization copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? inviteCode,
    DateTime? createdAt,
  }) {
    return Organization(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// A member of an [Organization], with denormalized user fields for display.
class OrgMember {
  final String id; // organization_members row id
  final String organizationId;
  final String userId;
  final String role; // 'admin' | 'member'
  final String status; // 'active' | 'suspended'
  final DateTime joinedAt;
  // Denormalized user info (populated at load time).
  final String firstName;
  final String lastName;
  final String email;
  final String? photoPath;
  final int contactCount;
  final bool canEdit;          // may edit any org contact (admin always true)
  final bool canCreate;        // may create new contacts (admin always true)
  final bool canViewReminders; // may view reminders on shared contacts (admin always true)
  final bool canViewHistory;   // may view history records authored by other members (admin always true)

  OrgMember({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.role,
    this.status = 'active',
    DateTime? joinedAt,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.photoPath,
    this.contactCount = 0,
    this.canEdit = false,
    this.canCreate = true,
    this.canViewReminders = false,
    this.canViewHistory = false,
  }) : joinedAt = joinedAt ?? DateTime.now();

  String get fullName => '$firstName $lastName'.trim();

  OrgMember copyWith({
    String? id,
    String? organizationId,
    String? userId,
    String? role,
    String? status,
    DateTime? joinedAt,
    String? firstName,
    String? lastName,
    String? email,
    String? photoPath,
    int? contactCount,
    bool? canEdit,
    bool? canCreate,
    bool? canViewReminders,
    bool? canViewHistory,
  }) {
    return OrgMember(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      photoPath: photoPath ?? this.photoPath,
      contactCount: contactCount ?? this.contactCount,
      canEdit: canEdit ?? this.canEdit,
      canCreate: canCreate ?? this.canCreate,
      canViewReminders: canViewReminders ?? this.canViewReminders,
      canViewHistory: canViewHistory ?? this.canViewHistory,
    );
  }
}
