#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

import SwiftPawn

public let LockFileUnknownTty = "SwiftPromptNanny_unknown_tty"

public func acquiredLock(lockf: String) -> Int32 {
  let lkfd = open("/tmp/\(lockf)", O_RDWR | O_CREAT, 0o644)
  if lkfd == -1 {
    return -1
  }
  let flags = fcntl(lkfd, F_GETFL, 0)

  var ret = fcntl(lkfd, F_SETFL, flags | O_NONBLOCK)
  if ret != 0 {
    return -1
  }

  var fl = flock()
  fl.l_len = 0
  fl.l_start = 0
  fl.l_whence = Int16(SEEK_SET)
  fl.l_type = Int16(F_WRLCK)
  fl.l_pid = getpid()
  ret = fcntl(lkfd, F_SETLK, &fl)
  if ret != 0 {
    return -1
  }
  return lkfd
}

public func releaseLock(_ fd: Int32) {
  close(fd)
}

public func getLockFileName() -> String {
  guard let (status, out, _) = try? SwiftPawn.execute(command: "tty",
                                                      arguments: ["tty"]) else {
    return LockFileUnknownTty
  }

  guard status == 0 else {
    return LockFileUnknownTty
  }

  let ttyName = out.trimmed()
  let converted = ttyName.split(separator: "/").joined(separator: "_")
  let lockFile = "SwiftPromptNanny_\(converted)"
  return lockFile
}

// MARK: - String Extension

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
