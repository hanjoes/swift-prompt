#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

import SwiftDaemonLib
import SwiftGitLib
import SwiftPromptLib

// MARK: -

func main() {
  var ttyName = LockFileUnknownTty
  if CommandLine.arguments.count >= 2 {
    ttyName = CommandLine.arguments[1]
  }
  var dir = "/tmp"
  if CommandLine.arguments.count == 3 {
    dir = CommandLine.arguments[2]
  }

  SwiftDaemon.daemonize(inDir: "/tmp", foreground: false) {
    let lkfd = acquiredLock(lockf: ttyName)
    if lkfd == -1 {
      exit(EXIT_FAILURE)
    }
    var buffer = [UInt8](repeating: 0, count: 4096)
    let n = read(lkfd, &buffer, buffer.count)
    // print(buffer)

    let strTime = String(decoding: buffer[0 ..< n], as: UTF8.self)
    var storedTime = 0
    if strTime.count != 0 {
      storedTime = Int(strTime)!
    }

    let currentTime = time(nil)

    // update every 5 seconds
    if currentTime - storedTime > 5 {
      for _ in 1 ... 5 {
        sleep(1)
      }
      // do { try SwiftGit.fetchRepo(at: dir) } catch {}
      let curTimeStr = "\(currentTime)"
      lseek(lkfd, 0, SEEK_SET)
      write(lkfd, curTimeStr, curTimeStr.count)
    }
    releaseLock(lkfd)
  }
}

main()
