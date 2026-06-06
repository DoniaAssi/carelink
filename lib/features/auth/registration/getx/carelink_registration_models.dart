enum CarelinkRegistrationRole { patient, nurse, doctor }

extension CarelinkRegistrationRoleExt on CarelinkRegistrationRole {
  String get apiValue {
    switch (this) {
      case CarelinkRegistrationRole.nurse:
        return 'nurse';
      case CarelinkRegistrationRole.doctor:
        return 'doctor';
      case CarelinkRegistrationRole.patient:
        return 'patient';
    }
  }
}
