const fs = require('fs');
let code = fs.readFileSync('routes/nurse.js', 'utf8');

// Replace accept route logic
code = code.replace(
  /if \(!\['pending', 'pending_provider_approval'\]\.includes\(currentStatus\)\) \{\s*return res\.status\(400\)\.json\(\{ error: `Cannot accept request with status: \$\{request\.status\}` \}\);\s*\}/,
  `if (!['pending', 'pending_provider_approval', 'pending_reschedule'].includes(currentStatus)) {
      return res.status(400).json({ error: \`Cannot accept request with status: \${request.status}\` });
    }

    if (currentStatus === 'pending_reschedule') {
      await db.query(
        \`UPDATE servicerequest 
         SET status = 'confirmed', 
             scheduledAt = IFNULL(requestedRescheduleAt, scheduledAt),
             requestedRescheduleAt = NULL
         WHERE requestId = ?\`,
        [requestId]
      );

      await db.query(
        \`INSERT INTO appointmentstatushistory (statusHistoryId, requestId, patientUserId, providerUserId, statusCode, sourceRole, note)
         VALUES (?, ?, ?, ?, 'confirmed', 'nurse', 'Reschedule accepted')\`,
        [randomUUID(), requestId, request.patientUserId, nurseId]
      );

      try {
        await insertNurseNotificationIfEnabled({
          nurseId,
          preferenceKey: 'assignmentUpdates',
          type: 'appointment_change',
          title: 'Reschedule accepted',
          body: 'You accepted the patient reschedule request.',
          relatedRequestId: requestId,
        });
        await insertNotification({
          userId: request.patientUserId,
          type: 'appointment_change',
          title: 'Reschedule confirmed',
          body: 'Your nurse accepted the reschedule request. Your new appointment time is confirmed.',
          relatedRequestId: requestId,
        });
      } catch (_) {}

      return res.json({
        success: true,
        status: 'confirmed',
        message: 'Reschedule request accepted',
      });
    }`
);

// Replace reject route logic
code = code.replace(
  /if \(!\['pending', 'pending_provider_approval'\]\.includes\(currentStatus\)\) \{\s*return res\.status\(400\)\.json\(\{ error: `Cannot reject request with status: \$\{request\.status\}` \}\);\s*\}/,
  `if (!['pending', 'pending_provider_approval', 'pending_reschedule'].includes(currentStatus)) {
      return res.status(400).json({ error: \`Cannot reject request with status: \${request.status}\` });
    }

    if (currentStatus === 'pending_reschedule') {
      await db.query(
        \`UPDATE servicerequest 
         SET status = 'confirmed', 
             requestedRescheduleAt = NULL
         WHERE requestId = ?\`,
        [requestId]
      );

      await db.query(
        \`INSERT INTO appointmentstatushistory (statusHistoryId, requestId, patientUserId, providerUserId, statusCode, sourceRole, note)
         VALUES (?, ?, ?, ?, 'confirmed', 'nurse', 'Reschedule rejected')\`,
        [randomUUID(), requestId, request.patientUserId, nurseId]
      );

      try {
        await insertNurseNotificationIfEnabled({
          nurseId,
          preferenceKey: 'assignmentUpdates',
          type: 'appointment_change',
          title: 'Reschedule rejected',
          body: 'You declined the patient reschedule request. Original time kept.',
          relatedRequestId: requestId,
        });
        await insertNotification({
          userId: request.patientUserId,
          type: 'appointment_change',
          title: 'Reschedule declined',
          body: 'Your nurse declined the reschedule request. Your original appointment time is kept.',
          relatedRequestId: requestId,
        });
      } catch (_) {}

      return res.json({ 
        success: true, 
        message: 'Reschedule request rejected, original appointment kept' 
      });
    }`
);

fs.writeFileSync('routes/nurse.js', code);
console.log('nurse.js updated successfully');
