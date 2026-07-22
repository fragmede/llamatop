import XCTest
@testable import LlamaTopCore

final class RendererTests: XCTestCase {
    func testSummaryModeKeepsAggregateCPUAndGPUWithoutPerCoreDetail() {
        let output = DashboardRenderer(color: false, width: 100).render(
            .busyFixture(),
            mode: .summary
        )

        XCTAssertTrue(output.contains("CPU logical cores (system-wide · 12P + 4E)"))
        XCTAssertTrue(output.contains("Total"))
        XCTAssertFalse(output.contains("C00"))
        XCTAssertTrue(output.contains("Apple GPU (40 cores · system-wide)"))
        XCTAssertTrue(output.contains("Device"))
        XCTAssertFalse(output.contains("Renderer"))
        XCTAssertFalse(output.contains("Tiler"))
        XCTAssertFalse(output.contains("GPU cores (presence only"))
    }

    func testKeyboardDetailModesToggleIndependently() {
        var state = DashboardDisplayState(mode: .summary, showsMemoryDetails: false)

        XCTAssertTrue(state.handle(key: UInt8(ascii: "1")))
        XCTAssertEqual(state.mode, .detailed)
        XCTAssertFalse(state.showsMemoryDetails)

        XCTAssertTrue(state.handle(key: UInt8(ascii: "m")))
        XCTAssertEqual(state.mode, .detailed)
        XCTAssertTrue(state.showsMemoryDetails)

        XCTAssertTrue(state.handle(key: UInt8(ascii: "1")))
        XCTAssertEqual(state.mode, .summary)
        XCTAssertTrue(state.showsMemoryDetails)

        XCTAssertFalse(state.handle(key: UInt8(ascii: "x")))
    }

    func testMemoryDetailsRenderMeasuredLayoutAndHardwareLimitations() {
        let output = DashboardRenderer(color: false, width: 80).render(
            .busyFixture(),
            mode: .summary,
            showMemoryDetails: true
        )

        XCTAssertTrue(output.contains("Memory layout (system-wide · unified · LPDDR5)"))
        XCTAssertTrue(output.contains("Wired"))
        XCTAssertTrue(output.contains("Active"))
        XCTAssertTrue(output.contains("Inactive"))
        XCTAssertTrue(output.contains("Compressed"))
        XCTAssertTrue(output.contains("Free"))
        XCTAssertTrue(output.contains("Other"))
        XCTAssertTrue(output.contains("Swap"))
        XCTAssertTrue(output.contains("128.0 GiB LPDDR5 unified · Hynix"))
        XCTAssertTrue(output.contains("16.0 KiB pages · 128 B cache line"))
        XCTAssertTrue(output.contains("Banks/channels unavailable through macOS"))
    }

    func testMemoryDetailsFitMinimumWidth() {
        let output = DashboardRenderer(color: false, width: 60).render(
            .busyFixture(longText: true),
            mode: .detailed,
            showMemoryDetails: true
        )

        XCTAssertTrue(
            output.split(separator: "\n", omittingEmptySubsequences: false)
                .allSatisfy { $0.count <= 60 }
        )
    }

    func testRendersLlamaMetricsPerCoreGridAndDetailedGPUQualification() {
        let output = DashboardRenderer(color: false, width: 100).render(
            .busyFixture(),
            mode: .detailed
        )

        XCTAssertTrue(output.contains("BUSY"))
        XCTAssertTrue(output.contains("Llama workload (llama.cpp-only)"))
        XCTAssertTrue(output.contains("420.0%"))
        XCTAssertTrue(output.contains("≈ 4.2 / 16 cores"))
        XCTAssertTrue(output.contains("CPU logical cores (system-wide · 12P + 4E)"))
        XCTAssertTrue(output.contains("Total"))
        XCTAssertTrue(output.contains("C00"))
        XCTAssertTrue(output.contains("C15"))
        XCTAssertTrue(output.contains("Apple GPU (40 cores · system-wide)"))
        XCTAssertTrue(output.contains("Device"))
        XCTAssertTrue(output.contains("Renderer"))
        XCTAssertTrue(output.contains("Tiler"))
        XCTAssertTrue(output.contains("GPU Memory"))
        XCTAssertTrue(output.contains("GPU cores (presence only; no per-core telemetry)"))
        XCTAssertTrue(output.contains("40 detected · activity is aggregate"))
        XCTAssertEqual(output.filter { $0 == "◆" }.count, 40)
        XCTAssertTrue(output.contains("llama-cli -m model.gguf"))
        XCTAssertTrue(output.contains("GPU pipelines are not separate GPUs or additive"))
    }

    func testWidth60PacksThreeCoreCellsAndEveryLineFits() throws {
        let output = DashboardRenderer(color: false, width: 60).render(.busyFixture(longText: true))
        let firstCoreLine = try XCTUnwrap(output.split(separator: "\n").first { $0.hasPrefix("C00") })

        XCTAssertTrue(firstCoreLine.contains("C02"))
        XCTAssertFalse(firstCoreLine.contains("C03"))
        XCTAssertTrue(output.split(separator: "\n", omittingEmptySubsequences: false).allSatisfy { $0.count <= 60 })
    }

    func testWidth80PacksFourCoreCells() throws {
        let output = DashboardRenderer(color: false, width: 80).render(.busyFixture())
        let firstCoreLine = try XCTUnwrap(output.split(separator: "\n").first { $0.hasPrefix("C00") })

        XCTAssertTrue(firstCoreLine.contains("C03"))
        XCTAssertFalse(firstCoreLine.contains("C04"))
    }

    func testRendersWhicheverTopologyCountsAreAvailable() {
        let performanceOnly = DashboardRenderer(color: false, width: 80).render(
            .notFoundFixture(performanceCoreCount: 12)
        )
        let efficiencyOnly = DashboardRenderer(color: false, width: 80).render(
            .notFoundFixture(efficiencyCoreCount: 4)
        )

        XCTAssertTrue(performanceOnly.contains("CPU logical cores (system-wide · 12P)"))
        XCTAssertTrue(efficiencyOnly.contains("CPU logical cores (system-wide · 4E)"))
    }

    func testWidth100PacksFiveCoreCellsAndPreservesPartialLastRow() throws {
        let output = DashboardRenderer(color: false, width: 100).render(.busyFixture())
        let lines = output.split(separator: "\n")
        let firstCoreLine = try XCTUnwrap(lines.first { $0.hasPrefix("C00") })
        let lastCoreLine = try XCTUnwrap(lines.first { $0.hasPrefix("C15") })

        XCTAssertTrue(firstCoreLine.contains("C04"))
        XCTAssertFalse(firstCoreLine.contains("C05"))
        XCTAssertFalse(lastCoreLine.contains("C16"))
    }

    func testUnknownCoreAndMissingGPUPipelinesDoNotRenderAsZero() {
        var snapshot = SystemSnapshot.notFoundFixture()
        snapshot = SystemSnapshot(
            timestamp: snapshot.timestamp,
            machineName: snapshot.machineName,
            systemCPU: .init(
                cores: [.init(index: 0, percent: nil)],
                performanceCoreCount: nil,
                efficiencyCoreCount: nil
            ),
            physicalMemoryBytes: snapshot.physicalMemoryBytes,
            gpu: .init(
                model: nil,
                coreCount: nil,
                devicePercent: 25,
                rendererPercent: nil,
                tilerPercent: nil,
                allocatedSystemMemoryBytes: nil,
                inUseSystemMemoryBytes: nil
            ),
            processes: []
        )

        let output = DashboardRenderer(color: false, width: 80).render(snapshot)

        XCTAssertTrue(output.contains("C00 [·······]  --%"))
        XCTAssertTrue(output.contains("Device"))
        XCTAssertFalse(output.contains("Renderer"))
        XCTAssertFalse(output.contains("Tiler"))
    }

    func testRendersNotFoundHelpfullyWithinMinimumWidth() {
        let output = DashboardRenderer(color: false, width: 60).render(.notFoundFixture())

        XCTAssertTrue(output.contains("NOT FOUND"))
        XCTAssertTrue(output.contains("--match"))
        XCTAssertTrue(output.contains("unavailable"))
        XCTAssertTrue(output.split(separator: "\n", omittingEmptySubsequences: false).allSatisfy { $0.count <= 60 })
    }
}

private extension SystemSnapshot {
    static func busyFixture(longText: Bool = false) -> SystemSnapshot {
        let gib = UInt64(1_024 * 1_024 * 1_024)
        let memory = MemoryStatistics(
            activeBytes: 12 * gib,
            inactiveBytes: 10 * gib,
            wiredBytes: 8 * gib,
            compressedBytes: 6 * gib,
            freeBytes: 4 * gib,
            pageSizeBytes: 16 * 1_024,
            cacheLineBytes: 128,
            swapTotalBytes: 8 * gib,
            swapUsedBytes: 2 * gib,
            memoryType: "LPDDR5",
            manufacturer: "Hynix"
        )
        let gpu = GPUStatistics(
            model: "Apple M4 Max",
            coreCount: 40,
            devicePercent: 75,
            rendererPercent: 20,
            tilerPercent: 11,
            allocatedSystemMemoryBytes: 12 * gib,
            inUseSystemMemoryBytes: 8 * gib
        )
        let process = MonitoredProcess(
            pid: 123,
            parentPID: 1,
            cpuPercent: 420,
            residentBytes: 8 * gib,
            elapsedSeconds: 124,
            executable: "llama-cli",
            command: longText
                ? "llama-cli -m /a/very/long/path/to/a/model-that-must-be-truncated.gguf"
                : "llama-cli -m model.gguf"
        )
        return SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 0),
            machineName: longText ? "Apple M4 Max with an extremely long machine description" : "Apple M4 Max",
            systemCPU: .init(
                cores: (0..<16).map { .init(index: $0, percent: Double(($0 * 13) % 101)) },
                performanceCoreCount: 12,
                efficiencyCoreCount: 4
            ),
            physicalMemoryBytes: 128 * gib,
            memory: memory,
            gpu: gpu,
            processes: [process]
        )
    }

    static func notFoundFixture(
        performanceCoreCount: Int? = nil,
        efficiencyCoreCount: Int? = nil
    ) -> SystemSnapshot {
        .init(
            timestamp: Date(timeIntervalSince1970: 0),
            machineName: "Apple Silicon",
            systemCPU: .init(
                cores: (0..<8).map { .init(index: $0, percent: 0) },
                performanceCoreCount: performanceCoreCount,
                efficiencyCoreCount: efficiencyCoreCount
            ),
            physicalMemoryBytes: UInt64(16) * 1_024 * 1_024 * 1_024,
            gpu: nil,
            processes: []
        )
    }
}
