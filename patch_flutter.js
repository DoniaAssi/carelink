const fs = require('fs');

const filesToPatch = [
  'lib/features/patient/screens/appointments_screen.dart',
  'lib/features/patient/screens/booking_details_screen.dart',
  'lib/features/patient/screens/schedule_screen.dart'
];

for (const file of filesToPatch) {
  if (fs.existsSync(file)) {
    let code = fs.readFileSync(file, 'utf8');
    
    // For appointment.subStatus.toLowerCase().trim() == 'reschedule_requested'
    code = code.replace(
      /appointment\.subStatus\.toLowerCase\(\)\.trim\(\) == 'reschedule_requested'/g,
      "appointment.subStatus.toLowerCase().trim() == 'reschedule_requested' || appointment.status.toLowerCase().trim() == 'pending_reschedule'"
    );

    // For subStatus == 'reschedule_requested'
    code = code.replace(
      /if \(subStatus == 'reschedule_requested'\)/g,
      "if (subStatus == 'reschedule_requested' || status == 'pending_reschedule')"
    );

    fs.writeFileSync(file, code);
    console.log(`Patched ${file}`);
  }
}
