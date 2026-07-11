const fs = require('fs');
const file = 'lib/features/doctors/doctor/request_details_screen.dart';

let code = fs.readFileSync(file, 'utf8');

// Add requestedRescheduleAt to the UI
const uiAddition = `
                          if (scheduledAt != null)
                            _buildInfoRow(
                              'Scheduled',
                              _formatDate(scheduledAt),
                            ),
                          if (_request['requestedRescheduleAt'] != null)
                            _buildInfoRow(
                              'Requested New Time',
                              _formatDate(_request['requestedRescheduleAt']),
                            ),`;

code = code.replace(
  /if \(scheduledAt != null\)\s*_buildInfoRow\(\s*'Scheduled',\s*_formatDate\(scheduledAt\),\s*\),/,
  uiAddition
);

// Update status check for buttons
code = code.replace(
  /if \(status == 'pending'\) \.\.\.\[/g,
  `if (status == 'pending' || status == 'pending_reschedule') ...[`
);

// Add pending_reschedule to status badge
const badgeAddition = `
      case 'pending':
        color = AppColors.warning;
        break;
      case 'pending_reschedule':
        color = AppColors.warning;
        break;`;

code = code.replace(
  /case 'pending':\s*color = AppColors\.warning;\s*break;/,
  badgeAddition
);

fs.writeFileSync(file, code);
console.log('doctor request_details_screen.dart patched successfully');
