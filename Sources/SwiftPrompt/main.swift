import SwiftGitLib
import SwiftPawn
import Termbo

#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

// MARK: - Colors

struct Colors {
  static let Red = EscapeSequence.graphicsModeOn([31]).description
  static let Green = EscapeSequence.graphicsModeOn([32]).description
  static let Yellow = EscapeSequence.graphicsModeOn([33]).description
  static let Cyan = EscapeSequence.graphicsModeOn([36]).description
  static let Blink = EscapeSequence.graphicsModeOn([5]).description
  static let Reset = EscapeSequence.graphicsModeOn([0]).description
}

// MARK: - Glyphs

struct Glyphs {
  static let Up = Colors.Red + "^" + Colors.Reset
  static let Cross = Colors.Red + "x" + Colors.Reset
  static let Right = ">"
  static let Check = Colors.Green + "o" + Colors.Reset
  static let Question = Colors.Yellow + "?" + Colors.Reset
}

// MARK: - States

enum State {
  case noRepo
  case unknown
  case upToDate
  case newer
  case older

  var graphicsMode: String {
    switch self {
    case .noRepo:
      return ""
    case .unknown:
      return Colors.Yellow
    case .upToDate:
      return Colors.Green
    case .newer:
      return Colors.Cyan
    case .older:
      return EscapeSequence.graphicsModeOn([40, 37]).description // black bg, white fg
    }
  }

  var glyph: String {
    switch self {
    case .noRepo:
      return ""
    case .unknown:
      return " " + Glyphs.Question
    case .upToDate:
      return " " + Glyphs.Check
    case .newer:
      return " " + Glyphs.Up
    case .older:
      return " " + Glyphs.Cross
    }
  }
}

// mark: - constants

struct C {
  static let BufferSize = 4096
}

// MARK: - main

func main() throws {
  var buffer = [Int8](repeating: 0, count: C.BufferSize)
  let cwd = String(cString: getcwd(&buffer, C.BufferSize))

  memset(&buffer, 0, C.BufferSize)
  let ret = getlogin_r(&buffer, C.BufferSize)
  if ret != 0 {
    print("getlogin_r failed with status: \(ret)")
    return
  }

  // run nanny for logistics
  let selfPath = CommandLine.arguments[0]
  let pathElems = selfPath.split(separator: "/")
  let selfPathDir = pathElems.count == 0 ? "./" : String(pathElems.dropLast().joined(separator: "/"))
  let nannyPath = "\(selfPathDir)/swift_prompt_nanny"
  _ = try SwiftPawn.execute(command: nannyPath, arguments: [])

  // login, branch, modified state, host

  let login = String(cString: &buffer)

  var branch = "no repository"
  let isRepo = Git.isRepo(at: cwd)
  if isRepo {
    if let branchName = try Git.branchName(at: cwd) {
      branch = branchName
    }
  }

  let asterisk = try isRepo && Git.isModified(at: cwd) ? "*" : ""

  var state: State = .noRepo
  if isRepo {
    let diff = try Git.compare("HEAD", "origin/\(branch)", at: cwd)
    if diff > 0 {
      state = .newer
    } else if diff < 0 {
      state = .older
    } else {
      state = .upToDate
    }
  }

  let host = try getHostName()

  let PS1 = "\(Colors.Yellow)\(login)\(Colors.Reset)@\(Colors.Red)\(host)\(Colors.Reset)"
    + " \(state.graphicsMode)(\(asterisk)\(branch)\(Colors.Reset)\(state.glyph)\(state.graphicsMode))\(Colors.Reset) >"
  var t = Termbo(width: PS1.count, height: 1)
  t.render(bitmap: [PS1], to: stdout)
  t.end()
}

func getHostName() throws -> String {
  var buffer = [Int8](repeating: 0, count: C.BufferSize)
  gethostname(&buffer, C.BufferSize)
  let hn = String(cString: &buffer)
  let he = gethostbyname(hn)
  if he != nil {
    let addrPtr = he!.pointee.h_addr_list[0]
    while addrPtr != nil {
      let inaddr = addrPtr!.withMemoryRebound(to: in_addr.self, capacity: MemoryLayout<in_addr>.size) {
        $0
      }
      return String(cString: inet_ntoa(inaddr.pointee))
    }
  }
  return hn
}

try main()
