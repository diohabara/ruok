import Foundation

@MainActor
final class MonitorController {
    private let service: MonitorService
    private let config: AppConfig
    private let logger: AppLogger
    private var loopTask: Task<Void, Never>?
    private var oneShotTask: Task<Void, Never>?
    private(set) var isChecking = false
    private(set) var lastResultText = "まだ実行していません"
    var onStatusChange: (() -> Void)?

    init(service: MonitorService, config: AppConfig, logger: AppLogger) {
        self.service = service
        self.config = config
        self.logger = logger
    }

    var isRunning: Bool {
        loopTask != nil
    }

    var statusText: String {
        if isChecking {
            return isRunning ? "確認中（継続実行）" : "確認中"
        }
        return isRunning ? "実行中" : "停止中"
    }

    func start() {
        guard loopTask == nil, !isChecking else {
            return
        }
        logger.write("Starting Swift monitor loop")
        loopTask = Task { [weak self] in
            await self?.runLoop()
        }
        onStatusChange?()
    }

    func stop() {
        logger.write("Stopping Swift monitor loop")
        loopTask?.cancel()
        loopTask = nil
        onStatusChange?()
    }

    func stopAll() {
        stop()
        oneShotTask?.cancel()
        oneShotTask = nil
        onStatusChange?()
    }

    func runOnce() {
        guard !isChecking, oneShotTask == nil else {
            return
        }
        logger.write("Starting one-shot Swift check")
        oneShotTask = Task { [weak self] in
            await self?.runSingleCheck(clearOneShotWhenDone: true)
        }
        onStatusChange?()
    }

    private func runLoop() async {
        await runSingleCheck(clearOneShotWhenDone: false)
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: UInt64(config.intervalSeconds * 1_000_000_000))
            } catch {
                break
            }
            if Task.isCancelled {
                break
            }
            await runSingleCheck(clearOneShotWhenDone: false)
        }
        if loopTask?.isCancelled == true {
            loopTask = nil
            onStatusChange?()
        }
    }

    private func runSingleCheck(clearOneShotWhenDone: Bool) async {
        if isChecking {
            if clearOneShotWhenDone {
                oneShotTask = nil
                onStatusChange?()
            }
            return
        }
        isChecking = true
        onStatusChange?()

        do {
            let record = try await service.runOnce()
            let message = AdviceFormatter.notificationMessage(from: record)
            lastResultText = message.title
            logger.write("Completed check \(record.id): \(message.title)")
        } catch is CancellationError {
            logger.write("Swift check cancelled")
        } catch {
            lastResultText = "エラー: \(error.localizedDescription)"
            logger.write("Swift check failed: \(error.localizedDescription)")
        }

        isChecking = false
        if clearOneShotWhenDone {
            oneShotTask = nil
        }
        onStatusChange?()
    }
}
