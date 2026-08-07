struct LatestRequestGate {
    typealias Token = UInt64

    private var generation: UInt64 = 0

    mutating func begin() -> Token {
        generation &+= 1
        return generation
    }

    mutating func invalidate() {
        generation &+= 1
    }

    func isCurrent(_ token: Token) -> Bool {
        token == generation
    }
}
