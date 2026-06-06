/**
 * @typedef {object} AvailabilitySlot
 * @property {string} day
 * @property {string} startTime
 * @property {string} endTime
 */

/**
 * @typedef {object} Provider
 * @property {string} id
 * @property {string} fullName
 * @property {'doctor'|'nurse'} role
 * @property {string} specialization
 * @property {number} rating
 * @property {number} [experienceYears]
 * @property {number} [locationLatitude]
 * @property {number} [locationLongitude]
 * @property {AvailabilitySlot[]} [availableSlots]
 * @property {string} [serviceType]
 */

/**
 * @typedef {object} PatientProfile
 * @property {string} id
 * @property {string} fullName
 * @property {number} [age]
 * @property {string} [gender]
 * @property {number} [locationLatitude]
 * @property {number} [locationLongitude]
 * @property {string[]} [chronicDiseases]
 * @property {string[]} [allergies]
 * @property {string[]} [medications]
 * @property {string[]} [previousSurgeries]
 * @property {string} [careSummaryText]
 * @property {Record<string, number>} [previousProviderRatings]
 * @property {string[]} [successfulVisitProviderIds]
 * @property {string[]} [visitReportTexts]
 * @property {string[]} [followUpHints]
 * @property {boolean} [hasHistoryForWeighting]
 */

/**
 * @typedef {object} RecommendationRequest
 * @property {string} [rawQuery]
 * @property {string} [categoryKey]
 * @property {Date|null} [requestedDateTime]
 * @property {boolean} [isUrgent]
 * @property {boolean} [isComplexCase]
 * @property {string} [requestedServiceKeyword]
 */

/**
 * @typedef {object} ScoreBreakdown
 * @property {number} location
 * @property {number} specialization
 * @property {number} availability
 * @property {number} rating
 * @property {number} experience
 * @property {number} medicalCompatibility
 * @property {number} history
 */

/**
 * @typedef {object} RecommendationWeights
 * @property {number} locationWeight
 * @property {number} specializationWeight
 * @property {number} availabilityWeight
 * @property {number} ratingWeight
 * @property {number} experienceWeight
 * @property {number} medicalCompatibilityWeight
 * @property {number} historyWeight
 */

/**
 * @typedef {object} AIRecommendationResult
 * @property {string} providerId
 * @property {Provider} provider
 * @property {number} finalScore
 * @property {number} matchPercentage
 * @property {ScoreBreakdown} scoreBreakdown
 * @property {RecommendationWeights} weights
 * @property {string[]} recommendationReasons
 */

/**
 * @typedef {object} Appointment
 * @property {string} id
 * @property {string} patientId
 * @property {string} providerId
 * @property {string} date
 * @property {string} time
 * @property {string} reason
 * @property {'pending'|'confirmed'|'completed'|'cancelled'} status
 * @property {'unpaid'|'paid'} paymentStatus
 * @property {number} price
 * @property {'home'|'clinic'|'hospital'} locationType
 * @property {string} createdAt
 */

/**
 * @typedef {object} MedicalRecordEntry
 * @property {string} id
 * @property {string} patientId
 * @property {string} [appointmentId]
 * @property {'patient'|'doctor'|'nurse'|'admin'} uploadedBy
 * @property {'old_report'|'visit_report'|'lab_result'|'prescription'|'diagnosis'|'note'} type
 * @property {string} title
 * @property {string} [description]
 * @property {string} [diagnosis]
 * @property {string} [notes]
 * @property {string} [prescription]
 * @property {string[]} [attachments]
 * @property {string} createdAt
 * @property {boolean} [usedByAi]
 * @property {boolean} [privateLabel]
 * @property {boolean} [uploadedAfterVisit]
 */

export {};
