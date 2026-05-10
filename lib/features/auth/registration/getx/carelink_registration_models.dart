/// Role sent to Laravel `POST /api/register` as `role`.
enum CarelinkRegistrationRole {
  patient,
  nurse,
  doctor;

  String get apiValue => name;

  String get label => switch (this) {
        CarelinkRegistrationRole.patient => 'Patient',
        CarelinkRegistrationRole.nurse => 'Nurse',
        CarelinkRegistrationRole.doctor => 'Doctor',
      };

  bool get needsProfileCompletion =>
      this == CarelinkRegistrationRole.nurse ||
      this == CarelinkRegistrationRole.doctor;
}
