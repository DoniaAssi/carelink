const { analyzeIntent } = require('./services/aiRecommendation/intentAnalyzer');
const { recommendProviders } = require('./services/aiRecommendation/engine');

async function testQueries() {
  const patient = {
    id: "test-patient",
    locationLatitude: 31.95,
    locationLongitude: 35.91,
    analysisTags: []
  };

  const providers = [
    {
      id: "doc-cardio",
      userId: "doc-cardio",
      fullName: "Dr. Ahmed Cardio",
      role: "doctor",
      specialization: "Cardiology",
      serviceType: "Consultation",
      rating: 4.8,
      isAvailable: true,
      locationLatitude: 31.950,
      locationLongitude: 35.910,
    },
    {
      id: "doc-family",
      userId: "doc-family",
      fullName: "Dr. Sara General",
      role: "doctor",
      specialization: "Family Medicine",
      serviceType: "Consultation",
      rating: 4.5,
      isAvailable: true,
      locationLatitude: 31.960,
      locationLongitude: 35.900,
    },
    {
      id: "nurse-wound",
      userId: "nurse-wound",
      fullName: "Nurse Fatima Woundcare",
      role: "nurse",
      specialization: "",
      serviceType: "Home Nursing, Wound Care, Injections",
      rating: 4.7,
      isAvailable: true,
      locationLatitude: 31.955,
      locationLongitude: 35.915,
    },
    {
      id: "nurse-elderly",
      userId: "nurse-elderly",
      fullName: "Nurse Ali Elderly",
      role: "nurse",
      specialization: "",
      serviceType: "Elderly Care, Medication Administration",
      rating: 4.6,
      isAvailable: true,
      locationLatitude: 31.965,
      locationLongitude: 35.905,
    }
  ];

  const queries = [
    "My mother needs wound dressing after surgery",
    "My father needs insulin injection at home",
    "I have fever",
    "I have chest pain and cannot breathe"
  ];

  for (const q of queries) {
    console.log(`\n======================================================`);
    console.log(`QUERY: "${q}"`);
    console.log(`======================================================`);
    const intent = analyzeIntent(q, "");
    console.log("INTENT:", JSON.stringify(intent, null, 2));

    const request = {
      rawQuery: q,
      requestedServiceKeyword: intent.possibleSpecialty || intent.serviceCategory,
      requestedDateTime: null,
      isUrgent: intent.urgency === 'urgent' || intent.urgency === 'emergency',
      isComplexCase: false,
      isEmergency: intent.isEmergency,
    };

    const ranked = recommendProviders(patient, request, providers, 10);
    console.log("\nRANKING RESULTS:");
    ranked.forEach((r, idx) => {
      console.log(`${idx + 1}. [${r.provider.role.toUpperCase()}] ${r.provider.fullName}`);
      console.log(`   Specialty/Services: ${r.provider.specialization || r.provider.serviceType}`);
      console.log(`   Score: ${r.matchPercentage}% (Med: ${r.scoreBreakdown.medicalCompatibility.toFixed(2)}, Spec: ${r.scoreBreakdown.specialization.toFixed(2)})`);
      console.log(`   Reasons: ${r.recommendationReasons.join(' | ')}`);
    });
  }
}

testQueries().catch(console.error);
