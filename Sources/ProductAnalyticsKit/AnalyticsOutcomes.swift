public enum AnalyticsStartRejection: Sendable, Equatable {
    case invalidProjectToken
    case differentProjectToken
}

public enum AnalyticsStartOutcome: Sendable, Equatable {
    case started
    case alreadyStarted
    case rejected(AnalyticsStartRejection)
}

public enum AnalyticsDropReason: Sendable, Equatable {
    case notStarted
    case collectionDisabled
}

public enum AnalyticsCaptureOutcome: Sendable, Equatable {
    case captured
    case dropped(AnalyticsDropReason)
}

public enum AnalyticsIdentityOutcome: Sendable, Equatable {
    case identified
    case deferred
    case rejected
}
