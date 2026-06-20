class InitialDiagnosisReport {
  constructor(row = {}) {
    this.reportId = row.reportId;
    this.serviceRequestId = row.serviceRequestId;
    this.doctorUserId = row.doctorUserId;
    this.chiefComplaint = row.chiefComplaint || '';
    this.symptoms = row.symptoms || '';
    this.diagnosis = row.diagnosis || '';
    this.treatmentPlan = row.treatmentPlan || '';
    this.nursingInstructions = row.nursingInstructions || '';
    this.requiredVisits = row.requiredVisits ?? 1;
    this.createdAt = row.createdAt;
    this.updatedAt = row.updatedAt;
  }

  static fromRow(row) {
    return row ? new InitialDiagnosisReport(row) : null;
  }

  toJSON() {
    return {
      reportId: this.reportId,
      serviceRequestId: this.serviceRequestId,
      doctorUserId: this.doctorUserId,
      chiefComplaint: this.chiefComplaint,
      symptoms: this.symptoms,
      diagnosis: this.diagnosis,
      treatmentPlan: this.treatmentPlan,
      nursingInstructions: this.nursingInstructions,
      requiredVisits: this.requiredVisits,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt,
    };
  }
}

module.exports = InitialDiagnosisReport;
