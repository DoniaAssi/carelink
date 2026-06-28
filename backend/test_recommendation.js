const { analyzeIntent } = require('./services/aiRecommendation/intentAnalyzer');
const { recommendProviders } = require('./services/aiRecommendation/engine');
const db = require('./db');

async function test() {
  const rawQuery = "My mother needs wound dressing after surgery";
  console.log("Testing intent analysis...");
  const intent = analyzeIntent(rawQuery, "");
  console.log("Intent:", intent);

  console.log("Testing endpoint...");
  // Simulate fetching patient and providers
  const patient = {
    id: "6697923c-3c1b-4fab-b4ff-114be1b68fdb",
    locationLatitude: 31.95,
    locationLongitude: 35.91,
    analysisTags: []
  };

  const providers = [
    {
      id: "ai-test-nurse-wound",
      userId: "ai-test-nurse-wound",
      fullName: "Nurse Fatima Woundcare",
      role: "nurse",
      specialization: "",
      serviceType: "Home Nursing, Wound Care, Injections",
      rating: 4.7,
      overallRating: 4.7,
      ratingsCount: 50,
      isAvailable: true,
      isActive: 1,
      approvalStatus: "approved",
      locationLatitude: 31.955,
      locationLongitude: 35.915,
      availableSlots: [
        { day: 'monday', startTime: '07:00:00', endTime: '15:00:00' }
      ]
    }
  ];

  const request = {
    rawQuery: rawQuery,
    requestedServiceKeyword: intent.possibleSpecialty || intent.serviceCategory,
    requestedDateTime: null,
    isUrgent: intent.urgency === 'urgent' || intent.urgency === 'emergency',
    isComplexCase: false,
    isEmergency: intent.isEmergency,
  };

  console.log("Running recommendProviders...");
  const ranked = recommendProviders(patient, request, providers, 10);
  console.log("Ranked:", JSON.stringify(ranked, null, 2));
  
  // Simulate endpoint map
  const response = ranked.map(r => ({
    providerId: r.providerId,
    confidenceScore: r.confidenceScore,
    recommendationReasons: r.recommendationReasons,
    // explicitly test for medicalTags bug
    matchedTags: r.matchedTags || [],
    medicalTags: undefined // to verify it doesn't crash
  }));

  console.log("Endpoint map successful.");
  process.exit(0);
}

test().catch(err => {
  console.error("Test failed:", err);
  process.exit(1);
});
