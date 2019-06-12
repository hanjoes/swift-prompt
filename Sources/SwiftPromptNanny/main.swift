#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

import SwiftDaemonLib
import SwiftPawn

// MARK: -

private extension String {
  func trimmed() -> String {
    var result = self
    while result.last?.isWhitespace == true {
      result = String(result.dropLast())
    }

    while result.first?.isWhitespace == true {
      result = String(result.dropFirst())
    }

    return result
  }
}

// MARK: -

func main() throws {
  let (status, out, _) = try SwiftPawn.execute(command: "tty",
                                               arguments: ["tty"])
  if status != 0 {
    exit(EXIT_FAILURE)
  }

  let ttyName = out.trimmed()
  let lockFile = "SwiftPromptNanny_\(ttyName)"

  SwiftDaemon.daemonize(inDir: "/tmp") {
    var fl = flock()
    fl.l_len = 0
    fl.l_start = 0
    fl.l_whence = Int16(SEEK_SET)
    fl.l_type = Int16(F_WRLCK)
    fl.l_pid = getpid()

    let lkfd = open(lockFile, O_WRONLY)
    defer { close(lkfd) }
    var ret = fcntl(lkfd, F_SETLK, &fl)
    if ret != 0 {
      exit(EXIT_FAILURE)
    }

    for _ in 1...10 {
      sleep(2)
    }

    // lock will be release when lfd got closed
  }
}

try main()