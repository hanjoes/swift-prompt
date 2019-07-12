import SwiftGitLib
import SwiftPawn
import SwiftPromptLib
import TerminaLib

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

// MARK: - Colors

public struct Colors {
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
    case updating

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
            // black bg, white fg
            return EscapeSequence.graphicsModeOn([40, 37]).description
        case .updating:
            return ""
        }
    }

    var glyph: String {
        switch self {
        case .noRepo:
            return Glyphs.Cross
        case .unknown:
            return Glyphs.Question
        case .upToDate:
            return Glyphs.Check
        case .newer:
            return Glyphs.Up
        case .older:
            return Glyphs.Cross
        case .updating:
            return Colors.Blink + Glyphs.Question
        }
    }
}

// mark: - constants

struct C {
    static let BufferSize = 4096
}

func getPrompt(_ login: String, _ host: String, _ branch: String,
               _ state: State, _ asterisk: String, _ link: String) -> String {
    return "\(Colors.Yellow)\(login)\(Colors.Reset)"
        + "@\(Colors.Red)\(host)\(Colors.Reset)"
        + " \(state.graphicsMode)(\(asterisk)\(branch)\(Colors.Reset)\(link)"
        + "\(state.glyph)\(state.graphicsMode))\(Colors.Reset)"
}

func renderPrompt(_: String, _: String,
                  _: String, _: Bool,
                  _: State) {}

func getHostName() throws -> String {
    var buffer = [Int8](repeating: 0, count: C.BufferSize)
    gethostname(&buffer, C.BufferSize)
    let hn = String(cString: &buffer)
    let he = gethostbyname(hn)
    if he != nil {
        let addrPtr = he!.pointee.h_addr_list[0]
        let addrSize = MemoryLayout<in_addr>.size
        while addrPtr != nil {
            let inaddr = addrPtr!.withMemoryRebound(to: in_addr.self,
                                                    capacity: addrSize) { $0 }
            return String(cString: inet_ntoa(inaddr.pointee))
        }
    }
    return hn
}

func getDiff(_ dir: String, _ isRepo: Bool, _ branch: String) -> State {
    if isRepo {
        let (ret, diff, _) = SwiftGit.compare("HEAD", "origin/\(branch)", at: dir)
        guard ret == 0 else {
            return .unknown
        }
        if diff > 0 {
            return .newer
        } else if diff < 0 {
            return .older
        } else {
            return .upToDate
        }
    }
    return .unknown
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

    // login, branch, modified state, host

    let login = String(cString: &buffer)

    var link = " "
    var branch = "no repository"
    let (isRepo, _) = SwiftGit.repository(at: cwd)
    if isRepo {
        let (branchName, _) = SwiftGit.branch(at: cwd)
        if let branchName = branchName {
            branch = branchName
            link = " "
        }
    }

    var state: State = .noRepo
    let lockf = getLockFileName()

    let host = try getHostName()
    let (modified, _) = SwiftGit.modified(at: cwd)
    let asterisk = isRepo && modified ? "*" : ""
    var prompt = getPrompt(login, host, branch, state, asterisk, link)

    // assemble the prompt.
    // each prompt script is executed once and
    var t = Termina(width: 100, height: 1)

    if isRepo {
        let (remote, _) = SwiftGit.tracked(at: cwd, branch: branch)
        link = remote != nil ? "~" : " "
        var lkfd = acquiredLock(lockf: lockf)
        if lkfd == -1 {
            state = .updating
            prompt = getPrompt(login, host, branch, state, asterisk, link)
            t.render(bitmap: [prompt], to: stdout)
            _ = try SwiftPawn.execute(command: "stty",
                                      arguments:
                                      ["stty", "-isig", "-echo", "-icanon"])
            defer { _ = try! SwiftPawn.execute(command: "stty",
                                               arguments: ["stty", "sane"]) }
            while true {
                let c = getchar()
                if c == 10 {
                    break
                }
            }

            lkfd = acquiredLock(lockf: lockf)
            if lkfd == -1 {
                state = .unknown
            } else {
                if remote != nil {
                    state = getDiff(cwd, isRepo, branch)
                }
            }
        } else {
            if remote != nil {
                state = getDiff(cwd, isRepo, branch)
            }
        }
        prompt = getPrompt(login, host, branch, state, asterisk, link)

        // release lock before running nanny
        releaseLock(lkfd)

        // run nanny for logistics

        let selfPath = CommandLine.arguments[0]
        let pathElems = selfPath.split(separator: "/")
        let selfPathDir = pathElems.count == 0 ? "./" : String(pathElems.dropLast()
            .joined(separator: "/"))
        var nannyPath = "\(selfPathDir)/swift_prompt_nanny"
        if selfPath.starts(with: "/") {
            nannyPath = "/" + nannyPath
        }

        _ = try SwiftPawn.execute(command: nannyPath,
                                  arguments: ["swift_prompt_nanny", lockf, cwd])
    }

    t.end(withBitmap: [prompt], terminator: "\n", to: stdout)
}

try main()
