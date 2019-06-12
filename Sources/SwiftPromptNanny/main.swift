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
  let (status, out, _) = try SwiftPawn.execute(command: "tty", arguments: ["tty"])
  if status != 0 {
    exit(EXIT_FAILURE)
  }

  let ttyName = out.trimmed()
  let lockFile = "SwiftPromptNanny_\(ttyName)"
  print(lockFile)

  SwiftDaemon.daemonize(inDir: "/tmp") {}
}

try main()