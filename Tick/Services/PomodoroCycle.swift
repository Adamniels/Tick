/// The pomodoro rhythm as pure functions: work, then a short break, with a long break after
/// every `longBreakEvery`-th completed work block.
nonisolated enum PomodoroCycle {
    static func breakPhase(afterCompletedWorkBlocks completed: Int, longBreakEvery: Int) -> PomodoroPhase {
        let every = max(1, longBreakEvery)
        return completed > 0 && completed % every == 0 ? .longBreak : .shortBreak
    }
}
