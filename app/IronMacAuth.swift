import Foundation
import LocalAuthentication

let args = CommandLine.arguments

var reason = "Authorize IronMac Vault Operation"
var ticketPath: String? = nil
var checkOnly = false
var gracePeriodSeconds: Double = 600 // 10 minutes default grace period

var i = 1
while i < args.count {
    let arg = args[i]
    if arg == "--check" {
        checkOnly = true
    } else if arg == "--ticket" && i + 1 < args.count {
        ticketPath = args[i + 1]
        i += 1
    } else if arg == "--ttl" && i + 1 < args.count {
        if let ttl = Double(args[i + 1]) {
            gracePeriodSeconds = ttl
        }
        i += 1
    } else if !arg.hasPrefix("--") {
        reason = arg
    }
    i += 1
}

// 1. Check existing session ticket if specified
if let path = ticketPath, FileManager.default.fileExists(atPath: path) {
    if let content = try? String(contentsOfFile: path, encoding: .utf8),
       let timestamp = Double(content.trimmingCharacters(in: .whitespacesAndNewlines)) {
        let age = Date().timeIntervalSince1970 - timestamp
        if age >= 0 && age < gracePeriodSeconds {
            // Ticket is still valid within grace period!
            print("AUTH_OK: SESSION_TICKET_VALID")
            exit(0)
        }
    }
}

let context = LAContext()
context.localizedCancelTitle = "Cancel"

var error: NSError?
guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
    fputs("AUTH_ERROR: \(error?.localizedDescription ?? "Biometric/Device authentication unavailable")\n", stderr)
    exit(2)
}

if checkOnly {
    print("BIOMETRICS_AVAILABLE: true")
    exit(0)
}

let semaphore = DispatchSemaphore(value: 0)
var authSuccess = false
var authErrorMsg: String?

context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evalError in
    authSuccess = success
    if let err = evalError {
        authErrorMsg = err.localizedDescription
    }
    semaphore.signal()
}

semaphore.wait()

if authSuccess {
    if let path = ticketPath {
        let nowStr = String(Date().timeIntervalSince1970)
        try? nowStr.write(toFile: path, atomically: true, encoding: .utf8)
    }
    print("AUTH_OK: TOUCH_ID_CONFIRMED")
    exit(0)
} else {
    fputs("AUTH_CANCELLED: \(authErrorMsg ?? "User cancelled authentication")\n", stderr)
    exit(1)
}
