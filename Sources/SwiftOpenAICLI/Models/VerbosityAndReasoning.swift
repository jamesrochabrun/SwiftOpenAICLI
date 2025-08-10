import ArgumentParser

public enum VerbosityLevel: String, ExpressibleByArgument, Codable, CaseIterable {
    case low
    case medium
    case high
}

public enum ReasoningEffort: String, ExpressibleByArgument, Codable, CaseIterable {
    case minimal
    case low
    case medium
    case high
}