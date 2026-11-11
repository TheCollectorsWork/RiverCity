import Foundation

struct Card: Codable, Equatable {
    let rank: Int
    let suit: Int
    var label: String { (rank < 11 ? String(rank) : ["J","Q","K","A"][rank-11]) + ["♠","♥","♣","♦"][suit] }
    static func score(_ cards: [Card]) -> Int {
        var best = 0
        for a in 0..<(cards.count-4) {
            for b in (a+1)..<(cards.count-3) {
                for c in (b+1)..<(cards.count-2) {
                    for d in (c+1)..<(cards.count-1) {
                        for e in (d+1)..<cards.count {
                            best = max(best, five([cards[a],cards[b],cards[c],cards[d],cards[e]]))
                        }
                    }
                }
            }
        }
        return best
    }

    private static func five(_ cards: [Card]) -> Int {
        let ranks = cards.map(\.rank).sorted(by: >)
        let groups = Dictionary(grouping: ranks, by: { $0 }).values
            .sorted { $0.count == $1.count ? $0[0] > $1[0] : $0.count > $1.count }
        let flush = Set(cards.map(\.suit)).count == 1
        let straight = ranks == [14,5,4,3,2] ? 5 :
            (groups.count == 5 && ranks[0] - ranks[4] == 4 ? ranks[0] : 0)
        let value: [Int]
        switch (flush, straight, groups.map(\.count)) {
        case (true, 1..., _): value = [8, straight]
        case (_, _, [4,1]): value = [7] + groups.map { $0[0] }
        case (_, _, [3,2]): value = [6] + groups.map { $0[0] }
        case (true, _, _): value = [5] + ranks
        case (_, 1..., _): value = [4, straight]
        case (_, _, [3,1,1]): value = [3] + groups.map { $0[0] }
        case (_, _, [2,2,1]): value = [2] + groups.map { $0[0] }
        case (_, _, [2,1,1,1]): value = [1] + groups.map { $0[0] }
        default: value = [0] + ranks
        }
        return (value + Array(repeating: 0, count: 6-value.count)).reduce(0) { $0 * 15 + $1 }
    }
}

struct Seat: Codable, Equatable {
    var name: String
    var chips = 400
    var cards: [Card] = []
    var folded = true
    var street = 0
    var total = 0
    var action = ""
}

struct Poker: Codable, Equatable {
    var seats = ["You","Mira","Leo","Dana","Max","Nika"].map { Seat(name: $0) }
    var board: [Card] = []
    var deck: [Card] = []
    var hand = 0
    var button = -1
    var turn: Int?
    var price = 0
    var minRaise = 20
    var pending: Set<Int> = []
    var actedAt: [Int: Int] = [:]
    var result = ""
    var showdown = false
    var finished: Bool { hand > 0 && !result.isEmpty && (seats[0].chips == 0 || seats[0].chips == 2400) }
    var blindBase = 20
    var bigBlind: Int { blindBase * (1 << min(max(0, hand-1)/3, 7)) }
    var pot: Int { seats.map(\.total).reduce(0,+) }
    var active: [Int] { seats.indices.filter { !seats[$0].folded } }
    var able: [Int] { active.filter { seats[$0].chips > 0 } }

    func after(_ index: Int) -> [Int] { (1...seats.count).map { (index+$0) % seats.count } }
    func owed(_ i: Int) -> Int { max(0, price-seats[i].street) }
    func canRaise(_ i: Int) -> Bool {
        able.count > 1 && seats[i].chips > owed(i) && (actedAt[i].map { price-$0 >= minRaise } ?? true)
    }
    mutating func pay(_ amount: Int, _ i: Int) {
        let paid = min(amount, seats[i].chips)
        seats[i].chips -= paid
        seats[i].street += paid
        seats[i].total += paid
    }
    mutating func deal() {
        guard !finished else { return }
        hand += 1
        result = ""
        showdown = false
        board = []
        deck = (0..<4).flatMap { suit in (2...14).map { Card(rank: $0, suit: suit) } }.shuffled()
        for i in seats.indices {
            seats[i].folded = seats[i].chips == 0
            seats[i].cards = []
            seats[i].street = 0
            seats[i].total = 0
            seats[i].action = ""
        }
        button = after(button).first { active.contains($0) }!
        let sb = active.count == 2 ? button : after(button).first { active.contains($0) }!
        let bb = after(sb).first { active.contains($0) }!
        for _ in 0..<2 {
            for i in after(button) where active.contains(i) { seats[i].cards.append(deck.removeLast()) }
        }
        pay(bigBlind/2,sb)
        pay(bigBlind,bb)
        price = bigBlind
        minRaise = bigBlind
        pending = Set(able)
        actedAt = [:]
        advance(after: bb)
    }
    mutating func move(_ move: String, target: Int = 0) {
        guard let i = turn else { return }
        if move == "raise" {
            guard canRaise(i) else { return }
            let ceiling = seats[i].street + seats[i].chips
            let amount = min(target, ceiling)
            guard amount > price && (amount >= price + minRaise || amount == ceiling) else { return }
            let increase = amount-price
            pay(amount-seats[i].street,i)
            price = amount
            if increase >= minRaise { minRaise = increase }
            pending.formUnion(able.filter { $0 != i && owed($0) > 0 })
            seats[i].action = "Raise \(amount)"
        } else if move == "fold" {
            seats[i].folded = true
            seats[i].action = "Fold"
        } else {
            let due = owed(i)
            pay(due,i)
            seats[i].action = due == 0 ? "Check" : seats[i].chips == 0 ? "All-in" : "Call"
        }
        actedAt[i] = price
        pending.remove(i)
        advance(after: i)
    }

    mutating func bot() {
        guard let i = turn, i != 0 else { return }
        let cards = seats[i].cards
        let strength = board.isEmpty
            ? Double(cards.map(\.rank).reduce(0,+))/32 + (cards[0].rank == cards[1].rank ? 0.32 : 0)
            : Double(Card.score(cards+board))/Double(15*15*15*15*15)/4 + 0.3
        let mood = strength + Double.random(in: -0.22...0.22) + Double(i-3)*0.035
        let cost = Double(owed(i))/Double(max(1,pot))
        if owed(i) > 0 && mood < 0.23 + min(0.46,cost) { move("fold") }
        else if canRaise(i) && mood > 0.81 && Bool.random() { move("raise",target: price + minRaise) }
        else { move("call") }
    }

    private mutating func advance(after i: Int) {
        turn = nil
        if active.count == 1 { settle(); return }
        pending.formIntersection(able)
        if able.count == 1, let only = able.first {
            let actualPrice = active.filter { $0 != only }.map { seats[$0].street }.max() ?? 0
            price = actualPrice
            pending = owed(only) > 0 ? [only] : []
        }
        if let next = after(i).first(where: { pending.contains($0) }) { turn = next; return }
        if board.count == 5 { settle(); return }
        _ = deck.removeLast()
        let count = board.isEmpty ? 3 : 1
        for _ in 0..<count { board.append(deck.removeLast()) }
        for j in seats.indices { seats[j].street = 0; seats[j].action = "" }
        price = 0
        minRaise = bigBlind
        actedAt = [:]
        pending = able.count > 1 ? Set(able) : []
        advance(after: button)
    }

    private mutating func settle() {
        showdown = active.count > 1
        let scores = showdown ? Dictionary(uniqueKeysWithValues: active.map { ($0, Card.score(seats[$0].cards+board)) }) : [:]
        let levels = Set(seats.map(\.total)).filter { $0 > 0 }.sorted()
        var previous = 0
        var prizes: [Int: Int] = [:]
        for level in levels {
            let contributors = seats.indices.filter { seats[$0].total >= level }
            let amount = (level-previous)*contributors.count
            previous = level
            let eligible = contributors.filter { !seats[$0].folded }
            if contributors.count == 1 || eligible.isEmpty {
                for j in contributors { seats[j].chips += amount/contributors.count }
                continue
            }
            let high = eligible.map { scores[$0] ?? 0 }.max()!
            let winners = after(button).filter { eligible.contains($0) && (scores[$0] ?? 0) == high }
            for (index,j) in winners.enumerated() {
                let award = amount/winners.count + (index < amount%winners.count ? 1 : 0)
                prizes[j, default: 0] += award
                seats[j].chips += award
            }
        }
        result = prizes.sorted { $0.key < $1.key }.map { "\(seats[$0.key].name) +\($0.value)" }.joined(separator: " · ")
        if result.isEmpty { result = "Chips returned" }
        turn = nil
    }
}
