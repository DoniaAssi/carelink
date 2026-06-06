class CareIntentResult {
  CareIntentResult({required this.specialtyChip, required this.restrictToAvailable});

  final String specialtyChip;
  final bool restrictToAvailable;
}

CareIntentResult parseCareIntent(String text, List<String> chips) {
  // Minimal placeholder: don't attempt real parsing; default to 'All'.
  return CareIntentResult(specialtyChip: 'All', restrictToAvailable: false);
}
