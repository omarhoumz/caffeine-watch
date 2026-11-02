import Foundation

enum KeepAwake {
    /// Starts `caffeinate` in its own session, so it outlives this app or the terminal that ran the CLI.
    @discardableResult
    static func start(seconds: Int?, display: Bool) -> Int32? {
        var args = ["/usr/bin/caffeinate", display ? "-dims" : "-ims"]
        if let seconds { args += ["-t", String(seconds)] }

        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        defer { posix_spawnattr_destroy(&attr) }
        posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETSID))

        var files: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&files)
        defer { posix_spawn_file_actions_destroy(&files) }
        for fd in [STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO] {
            posix_spawn_file_actions_addopen(&files, fd, "/dev/null", fd == STDIN_FILENO ? O_RDONLY : O_WRONLY, 0)
        }

        let cArgs = args.map { strdup($0) } + [nil]
        defer { cArgs.forEach { free($0) } }
        var pid: pid_t = 0
        return posix_spawn(&pid, args[0], &files, &attr, cArgs, environ) == 0 ? pid : nil
    }

    /// SIGTERMs the given caffeinate processes; returns the ones signalled.
    static func stop(_ pids: [Int32]) -> [Int32] {
        pids.filter { kill($0, SIGTERM) == 0 }
    }
}
