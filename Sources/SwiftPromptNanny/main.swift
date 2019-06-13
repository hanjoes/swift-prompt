#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

import SwiftDaemonLib
import SwiftPromptLib

// MARK: -

func main() {
  var ttyName = LockFileUnknownTty
  if CommandLine.arguments.count >= 2 {
    ttyName = CommandLine.arguments[1]
  }
  SwiftDaemon.daemonize(inDir: "/tmp", foreground: false) {
    let lkfd = acquiredLock(lockf: ttyName)
    if lkfd == -1 {
      exit(EXIT_FAILURE)
    }
    for _ in 1 ... 5 {
      sleep(2)
    }
    releaseLock(lkfd)

    // lock will be released when lfd got closed
  }
}

main()
