import Foundation
import Observation
#if canImport(HealthKit)
import HealthKit
#endif

// Local-only HealthKit body-mass read. HealthKit is optional: if it is unavailable
// or permission is not granted, the rest of the app works unchanged. We never write
// to HealthKit here, and AI integrations never touch Apple Health (see CLAUDE.md).
@MainActor
@Observable
final class HealthKitManager {
    // HealthKit intentionally does NOT report whether a *read* request was granted
    // (to avoid leaking whether data exists), so we only track whether we've asked.
    // The real signal of success is whether latestBodyMassLb() returns a value.
    enum Status: String {
        case unavailable      // device/simulator has no HealthKit
        case notDetermined    // we have not asked yet
        case requested        // we have asked; iOS won't confirm read access
    }

    private(set) var status: Status = .notDetermined

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    private var bodyMassType: HKQuantityType? { HKQuantityType.quantityType(forIdentifier: .bodyMass) }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func refreshStatus() {
        guard isAvailable else { status = .unavailable; return }
        if status == .unavailable { status = .notDetermined }
    }

    func requestReadAccess() async {
        guard isAvailable, let bodyMassType else { status = .unavailable; return }
        do {
            // Read-only request; we ask to share nothing.
            try await store.requestAuthorization(toShare: [], read: [bodyMassType])
        } catch {
            // Leave status as-is; the read attempt will surface any real failure.
        }
        status = .requested
    }

    /// Most recent body-mass sample in pounds, or nil if none / unavailable.
    func latestBodyMassLb() async -> Double? {
        guard isAvailable, let bodyMassType else { return nil }
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: bodyMassType, predicate: nil, limit: 1, sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil); return
                }
                let lb = sample.quantity.doubleValue(for: .pound())
                continuation.resume(returning: lb)
            }
            store.execute(query)
        }
    }
    #else
    var isAvailable: Bool { false }
    func refreshStatus() { status = .unavailable }
    func requestReadAccess() async { status = .unavailable }
    func latestBodyMassLb() async -> Double? { nil }
    #endif
}
