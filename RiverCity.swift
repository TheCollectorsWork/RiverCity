import SwiftUI
import SceneKit

@main
struct RiverCityApp: App {
    @AppStorage("riverCityPlaytest") private var playtest = true
    private static let previewSave: UserDefaults = {
        let store = UserDefaults(suiteName: "com.rivercity.playtest") ?? .standard
        store.register(defaults: ["cash": 2500, "rep": 0, "tickets": 3, "introSeen": true])
        return store
    }()

    var body: some Scene {
        WindowGroup {
            CityView(playtest: playtest) { playtest.toggle() }
                .id(playtest)
                .defaultAppStorage(playtest ? Self.previewSave : .standard)
                .preferredColorScheme(.dark)
                .fontDesign(.default)
                .environment(\.locale, Locale(identifier: "en_US"))
        }
    }
}

private final class CitySession: ObservableObject {
    @Published var profileOpen = false
    @Published var confirmEntry = false
    @Published var rewardSummary: String?
    @Published var venue: District?
    @Published var district: District = .river
    @Published var districtOpen = false
    @Published var note = ""
    @Published var wheel: Int?
    @Published var reels: [String] = []
    @Published var introPage = 0
}

private enum District: String, CaseIterable, Identifiable, Codable {
    case river, oldQuarter, marina, heights, crown, casino, lounge
    var id: Self { self }
    var title: String {
        switch self {
        case .river: "The Underground"
        case .oldQuarter: "The Velvet Room"
        case .marina: "Marina Poker Club"
        case .heights: "The Heights"
        case .crown: "The Crown"
        case .casino: "The Tide Casino"
        case .lounge: "The Lantern"
        }
    }
    var mapName: String {
        switch self {
        case .river: "RIVERSIDE"
        case .oldQuarter: "OLD QUARTER"
        case .marina: "MARINA"
        case .heights: "SKYLINE"
        case .crown: "CROWN HEIGHTS"
        case .casino: "THE TIDE"
        case .lounge: "LANTERN"
        }
    }
    var artwork: String {
        switch self {
        case .river: "club"
        case .oldQuarter: "club"
        case .marina: "heights"
        case .heights: "heights"
        case .casino: "casino"
        case .crown: "city"
        case .lounge: "woman"
        }
    }

    var subtitle: String {
        switch self {
        case .river: "01   /   RIVERSIDE"
        case .oldQuarter: "02 / OLD QUARTER"
        case .marina: "03 / MARINA"
        case .heights: "02   /   UPTOWN"
        case .crown: "03   /   PRIVATE CLUB"
        case .casino: "04   /   THE DOCKS"
        case .lounge: "05   /   THE WATERFRONT"
        }
    }

    var teaser: String {
        switch self {
        case .river: "A door without a sign. A seat with your name on it. Your story starts here."
        case .oldQuarter: "Behind the jazz lounge, a new circle of players awaits."
        case .marina: "Yachts, late nights and a table overlooking the water."
        case .heights: "Above the city, reputation opens doors. The stakes rise faster here."
        case .crown: "One table above the city. One name they will remember."
        case .casino: "Red, black, or three crowns. Chase a fortune and a seat at the final."
        case .lounge: "Leya saved you a seat by the window. Discover why she needs The Crown."
        }
    }

    var icon: String {
        switch self {
        case .river: "suit.spade.fill"
        case .oldQuarter: "suit.spade.fill"
        case .marina: "suit.diamond.fill"
        case .heights: "building.2"
        case .crown: "crown.fill"
        case .casino: "dice.fill"
        case .lounge: "heart.fill"
        }
    }
    var pin: CGPoint {
        switch self {
        case .river: .init(x: 0.19, y: 0.69)
        case .oldQuarter: .init(x: 0.15, y: 0.39)
        case .marina: .init(x: 0.60, y: 0.80)
        case .heights: .init(x: 0.43, y: 0.28)
        case .crown: .init(x: 0.80, y: 0.20)
        case .casino: .init(x: 0.77, y: 0.67)
        case .lounge: .init(x: 0.36, y: 0.49)
        }
    }
    var fee: Int { switch self { case .river: 100; case .oldQuarter: 150; case .marina: 200; case .heights: 250; default: 450 } }
    var prize: Int { fee * 6 }
    var prestige: Int { switch self { case .river: 30; case .oldQuarter: 35; case .marina: 40; case .heights: 50; default: 90 } }
    var field: [String] {
        switch self {
        case .heights: ["You", "Agatha", "Boris", "Sev", "Vera", "Emil"]
        case .crown: ["You", "Leya", "Rain", "Grant", "Sophia", "Roman"]
        default: ["You", "Mira", "Leo", "Dana", "Max", "Nika"]
        }
    }
}

private struct TournamentSave: Codable {
    let venue: District
    let poker: Poker
}

struct CityView: View {
    let playtest: Bool
    let changeMode: () -> Void
    @AppStorage("cash") private var cash = 500
    @AppStorage("rep") private var rep = 0
    @AppStorage("tickets") private var tickets = 0
    @AppStorage("debt") private var debt = 180
    @AppStorage("debtNextHand") private var debtNextHand = 2
    @AppStorage("relationship") private var relationship = 0
    @AppStorage("gift") private var gift = false
    @AppStorage("tournamentSave") private var tournamentData = Data()
    @AppStorage("collectorDeadline") private var collectorDeadline = 0.0
    @AppStorage("riverWon") private var riverWon = false
    @AppStorage("heightsWon") private var heightsWon = false
    @AppStorage("leyaFinale") private var leyaFinale = ""
    @AppStorage("crownWon") private var crownWon = false
    @AppStorage("introSeen") private var introSeen = false
    @AppStorage("velvetAccess") private var velvetAccess = false
    @AppStorage("bonusPoints") private var bonusPoints = 0
    @AppStorage("tournamentsPlayed") private var tournamentsPlayed = 0
    @AppStorage("tournamentsWon") private var tournamentsWon = 0
    @StateObject private var session = CitySession()
    private var savedTournament: TournamentSave? {
        guard let record = try? JSONDecoder().decode(TournamentSave.self, from: tournamentData) else { return nil }
        var poker = record.poker
        for index in poker.seats.indices {
            poker.seats[index].name = EnglishSave.text(poker.seats[index].name)
            poker.seats[index].action = EnglishSave.text(poker.seats[index].action)
        }
        poker.result = EnglishSave.text(poker.result)
        return TournamentSave(venue: record.venue, poker: poker)
    }
    private var debtNotice: Bool { collectorDeadline > 0 }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.11, green: 0.15, blue: 0.17), Noir.ink, Color(red: 0.025, green: 0.06, blue: 0.075)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            if let venue = session.venue, let saved = savedTournament {
                TournamentView(venue: venue, initialPoker: saved.poker, afterHand: collectorCall,
                               save: { storeTournament($0, in: venue) }, pause: { session.venue = nil }) { won in
                    guard !tournamentData.isEmpty else { return }
                    let earned = 20 + (won ? 100 : 0)
                    bonusPoints += earned
                    tournamentsPlayed += 1
                    if won { tournamentsWon += 1 }
                    session.rewardSummary = "Participation: +20 bonus points\nPlacement: +\(won ? 100 : 0) bonus points\nCash: +\(won ? venue.prize : 0)\nReputation: +\(won ? venue.prestige : 0)\nTotal bonus points earned: \(earned)"
                    if won {
                        cash += venue.prize
                        rep += venue.prestige
                        switch venue {
                        case .river: riverWon = true
                        case .heights: heightsWon = true
                        case .crown: crownWon = true
                        default: break
                        }
                    }
                    session.note = won
                        ? "Victory: +\(venue.prize) cash and +\(venue.prestige) reputation."
                        : "You are out. Your next chance is waiting."
                    tournamentData = Data()
                    collectorDeadline = 0
                    session.venue = nil
                }
                .allowsHitTesting(!debtNotice)
                .accessibilityHidden(debtNotice)
                if debtNotice { collectorOverlay }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ledger
                        cityMasthead
                        if playtest && introSeen {
                            Text("All districts unlocked · separate save")
                                .font(.caption).foregroundStyle(Noir.paper.opacity(0.66))
                        }
                        if !introSeen {
                            NoirScene(page: session.introPage)
                                .frame(height: 270)
                                .clipShape(.rect(cornerRadius: 14))
                                .accessibilityHidden(true)
                            Text(["01 / RIVERSIDE", "02 / THE STRANGER", "03 / THE CHALLENGE"][session.introPage])
                                .font(.system(.caption, design: .default)).tracking(2).foregroundStyle(Noir.gold)
                            Text([
                                "A limousine stops beneath a solitary streetlight.",
                                "A woman in an ivory coat offers you a card. An address on Riverside.",
                                "Want to reach the top? Riverside. Tonight. Win, and we will talk."
                            ][session.introPage]).font(.title2.weight(.medium))
                            Button(session.introPage == 2 ? "Accept the challenge" : "Continue") {
                                if session.introPage == 2 { introSeen = true }
                                else { session.introPage += 1 }
                            }.buttonStyle(.borderedProminent)
                        } else {
                            if let saved = savedTournament {
                                Button {
                                    session.venue = saved.venue
                                } label: {
                                    GameLabel("Resume · hand \(saved.poker.hand)", icon: "play.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(Noir.gold)
                                .controlSize(.large)
                            }
                            if !session.note.isEmpty {
                                GameLabel(session.note, icon: "envelope")
                                    .font(.footnote).foregroundStyle(Noir.gold)
                            }
                            cityMap { session.districtOpen = true }
                            leyaFeature { session.districtOpen = true }
                            chapter
                            Divider()
                            if playtest && cash < 1000 {
                                Button("Refill test funds") {
                                    cash = 2500
                                    session.note = "Test funds replenished."
                                }.font(.footnote)
                            }
                            HStack {
                                Button("Replay introduction") {
                                    session.introPage = 0
                                    introSeen = false
                                }
                                Spacer()
                                Button(playtest ? "Story mode" : "Test mode", action: changeMode)
                            }.font(.footnote)
                        }
                    }
                    .frame(maxWidth: 470, alignment: .leading)
                    .padding(24)
                    .frame(maxWidth: .infinity)
                }
                .sheet(isPresented: $session.districtOpen) {
                    districtSheet
                }
            }
        }.tint(Noir.gold)
        .sheet(isPresented: $session.profileOpen) { PlayerHub() }
        .alert("Tournament Complete", isPresented: Binding(get: { session.rewardSummary != nil }, set: { if !$0 { session.rewardSummary = nil } })) {
            Button("Back to City") { session.rewardSummary = nil }
        } message: { Text(session.rewardSummary ?? "") }
    }
    private var cityMasthead: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("POKER / AFTER DARK").font(.system(size: 9, weight: .semibold, design: .default))
                    .tracking(2).foregroundStyle(Noir.gold)
                Text("RIVER CITY").font(.custom("AvenirNextCondensed-DemiBold", size: 38)).tracking(3)
                    .foregroundStyle(Noir.paper).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 5)
            Button { session.profileOpen = true } label: {
                Image(systemName: "person.crop.circle").font(.title).frame(width: 44, height: 44)
            }.accessibilityLabel("Profile")
            if playtest {
                Text("TEST").font(.system(.caption2, design: .default).bold()).tracking(1)
                    .foregroundStyle(Noir.gold)
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(Noir.brass.opacity(0.35), in: .capsule)
                    .accessibilityLabel("Test mode. All districts unlocked.")
            }
        }
    }

    private func leyaFeature(open: @escaping () -> Void) -> some View {
        Button {
            session.district = .lounge
            session.note = ""
            open()
        } label: {
            ZStack(alignment: .bottomLeading) {
                NoirArtwork("woman", alignment: .top)
                LinearGradient(colors: [.clear, .black.opacity(0.12), .black.opacity(0.92)],
                               startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 4) {
                    Text("AFTER DARK STORIES").font(.system(size: 9, weight: .semibold, design: .default))
                        .tracking(2).foregroundStyle(Noir.gold)
                    Text("Leya is waiting")
                        .font(.custom("AvenirNext-DemiBold", size: 23)).foregroundStyle(Noir.paper)
                    GameLabel("Meet her at The Lantern", icon: "arrow.down.right").font(.caption).foregroundStyle(Noir.paper)
                }.padding(15)
            }
            .frame(height: 206)
            .clipShape(.rect(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(Noir.gold.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Open The Lantern")
    }

    private var ledger: some View {
        HStack(spacing: 0) {
            resource("CASH", value: cash, icon: "coin")
            Rectangle().fill(Noir.gold.opacity(0.22)).frame(width: 1, height: 34)
            resource("REPUTATION", value: rep, icon: "reputation")
            Rectangle().fill(Noir.gold.opacity(0.22)).frame(width: 1, height: 34)
            resource("VIP PASSES", value: tickets, icon: "ticket")
        }
        .padding(.vertical, 13)
        .background(LinearGradient(colors: [Color(red: 0.14, green: 0.19, blue: 0.20), Color(red: 0.055, green: 0.09, blue: 0.105)], startPoint: .top, endPoint: .bottom), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Noir.gold.opacity(0.32)))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
    }

    private func resource(_ title: String, value: Int, icon: String) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 7) {
                GameGlyph(icon).frame(width: 17, height: 17)
                Text(value.formatted()).font(.custom("AvenirNext-DemiBold", size: 21))
                    .monospacedDigit().foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            Text(title).font(.system(size: 8, weight: .semibold)).tracking(1.1)
                .foregroundStyle(Color(red: 0.76, green: 0.80, blue: 0.79))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func badge(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(.caption2, design: .default)).foregroundStyle(.secondary)
            Text(value.formatted()).font(.headline.monospacedDigit()).foregroundStyle(Noir.gold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10).background(.white.opacity(0.05), in: .rect(cornerRadius: 8))
    }

    private func cityMap(open: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("EXPLORE THE CITY").font(.system(.caption, design: .default)).tracking(3).foregroundStyle(Noir.gold)
            GeometryReader { geo in
                ZStack {
                    NoirArtwork("city")
                        .overlay(.black.opacity(0.18))
                    ForEach(District.allCases) { district in
                        Button {
                            session.district = district
                            session.note = ""
                            open()
                        } label: {
                            VStack(spacing: 4) {
                                GameGlyph(lockReason(district) == nil ? district.icon : "lock.fill")
                                    .frame(width: 21, height: 21)
                                    .frame(width: 44, height: 44)
                                    .background(LinearGradient(colors: [Color(red: 0.19, green: 0.24, blue: 0.24), Noir.ink], startPoint: .topLeading, endPoint: .bottomTrailing), in: .rect(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Noir.gold.opacity(session.district == district ? 1 : 0.6), lineWidth: 1))
                                Text(district.mapName).font(.system(size: 8, weight: .bold)).tracking(0.5)
                                    .foregroundStyle(Noir.paper)
                                    .padding(.horizontal, 5).padding(.vertical, 3)
                                    .background(Noir.ink.opacity(0.90), in: .capsule)
                            }.shadow(color: .black.opacity(0.8), radius: 5, y: 3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(district.title)
                        .accessibilityHint(lockReason(district) ?? "Explore district")
                        .position(x: geo.size.width * district.pin.x, y: geo.size.height * district.pin.y)
                    }
                }
            }.frame(height: 270).clipShape(.rect(cornerRadius: 15))
        }
    }

    private var chapter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(crownWon ? "EPILOGUE / WATERFRONT" : "CHAPTER I / THE PRICE OF ENTRY")
                .font(.system(.caption2, design: .default).bold()).tracking(2).foregroundStyle(Noir.gold)
            Text(crownWon ? "The city knows your name" : "The road to The Crown")
                .font(.system(.title3, design: .default).bold()).foregroundStyle(Noir.paper)
            milestone("Win at The Underground", done: riverWon)
            milestone("Win at The Heights", done: heightsWon)
            milestone("Win The Crown", done: crownWon)
            Divider()
            milestone(debt == 0 ? "Debt settled" : "Debt outstanding · \(debt)", done: debt == 0)
            milestone("Arrange a meeting with Leya", done: relationship >= 3)
            if tickets > 0 && !crownWon {
                Text("A VIP ticket unlocks a seat at The Crown.").font(.caption)
                    .foregroundStyle(Noir.gold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Noir.brass.opacity(0.15), in: .rect(cornerRadius: 12))
    }

    private func milestone(_ label: String, done: Bool) -> some View {
        GameLabel(label, icon: done ? "checkmark.circle.fill" : "circle")
            .font(.caption).foregroundStyle(done ? Noir.gold : Noir.paper.opacity(0.76))
    }

    private func storeTournament(_ poker: Poker, in venue: District) {
        guard let data = try? JSONEncoder().encode(TournamentSave(venue: venue, poker: poker)) else { return }
        tournamentData = data
    }

    private func startTournament(_ venue: District, fee: Int, useTicket: Bool) {
        guard savedTournament == nil, cash >= fee, !useTicket || tickets > 0 else { return }
        var poker = Poker()
        poker.seats = venue.field.map { Seat(name: $0) }
        poker.blindBase = venue == .river ? 20 : venue == .heights ? 30 : 40
        poker.deal()
        storeTournament(poker, in: venue)
        if useTicket { tickets -= 1 }
        cash -= fee
        debtNextHand = 2
        collectorDeadline = 0
        session.districtOpen = false
        session.venue = venue
    }

    private var districtSheet: some View {
        ScrollView {
            districtPanel
                .frame(maxWidth: 490)
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.fraction(0.64), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Noir.ink)
        .preferredColorScheme(.dark)
    }

    private var districtPanel: some View {
        let district = session.district
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DISTRICT GUIDE").font(.system(.caption2, design: .default).bold())
                    .tracking(2).foregroundStyle(Noir.gold)
                Spacer()
                Button {
                    session.districtOpen = false
                } label: {
                    GameGlyph( "xmark").font(.system(size: 14, weight: .semibold))
                        .frame(width: 44, height: 44)
                }.buttonStyle(.plain)
                    .foregroundStyle(Noir.paper)
                    .accessibilityLabel("Close district")
            }
            ZStack(alignment: .bottomLeading) {
                NoirArtwork(district.artwork, zoom: district == .lounge ? 1 : 1.12, alignment: .top)
                LinearGradient(colors: [.clear, .black.opacity(0.93)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 5) {
                    Text(district.subtitle).font(.system(size: 9, weight: .semibold, design: .default))
                        .tracking(1.4).foregroundStyle(Noir.gold)
                    Text(district.title).font(.system(.title2, design: .default).bold()).foregroundStyle(Noir.paper)
                }.padding(12)
            }
            .frame(height: 148)
            .clipShape(.rect(cornerRadius: 10))
            Text(district.teaser).font(.subheadline).foregroundStyle(Noir.paper.opacity(0.8))
            if let reason = lockReason(district) {
                GameLabel(reason, icon: "lock").foregroundStyle(Noir.gold)
            }
            switch district {
            case .river, .oldQuarter, .marina, .heights, .crown:
                HStack(spacing: 8) {
                    if !playtest && district == .crown && rep < 80 && tickets > 0 {
                        badge("VIP PASS", 1)
                    } else {
                        badge("BUY-IN", entryFee(district))
                    }
                    badge("PRIZE", district.prize)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BLINDS").font(.system(.caption2, design: .default)).foregroundStyle(.secondary)
                        Text(district == .river ? "10/20" : district == .heights ? "15/30" : "20/40")
                            .font(.headline.monospacedDigit()).foregroundStyle(Noir.gold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10).background(.white.opacity(0.05), in: .rect(cornerRadius: 8))
                }
            default: EmptyView()
            }
            if lockReason(district) == nil {
                switch district {
                case .casino: casinoPanel
                case .lounge: loungePanel
                default:
                    Text("Participation Reward · 20 bonus points").foregroundStyle(Noir.gold)
                    Text("Awarded when you finish or are eliminated. Winner earns an additional 100 bonus points.").font(.caption)
                    Text("No-limit Hold'em · 6 seats")
                        .foregroundStyle(.secondary)
                    if crownWon && district == .crown {
                        GameLabel("You won the city's final tournament", icon: "trophy.fill")
                            .foregroundStyle(Noir.gold)
                    }
                    let useTicket = !playtest && district == .crown && rep < 80
                    let fee = entryFee(district)
                    if useTicket { Text("Entry consumes one VIP pass.").font(.footnote).foregroundStyle(Noir.gold) }
                    Button(useTicket ? "Use VIP pass" : fee == 0 ? "Play free" : "Take a seat · \(fee)") {
                        session.confirmEntry = true
                    }.buttonStyle(.borderedProminent)
                        .disabled(cash < fee || savedTournament != nil)
                        .confirmationDialog("Enter \(district.title)?", isPresented: $session.confirmEntry, titleVisibility: .visible) {
                            Button("Confirm & Play · \(fee) cash\(useTicket ? " + 1 VIP pass" : "")") {
                                startTournament(district, fee: fee, useTicket: useTicket)
                            }
                        } message: { Text("Tournament chips are separate from cash. Participation reward: 20 bonus points.") }
                    if let saved = savedTournament {
                        Button("Resume: \(saved.venue.title)") {
                            session.districtOpen = false
                            session.venue = saved.venue
                        }
                            .buttonStyle(.bordered)
                    }
                    if cash < fee { Text("Not enough cash for the buy-in").font(.footnote) }
                }
            }
            if !session.note.isEmpty {
                GameLabel(session.note, icon: "envelope")
                    .font(.footnote).foregroundStyle(Noir.gold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func lockReason(_ district: District) -> String? {
        if playtest { return nil }
        return switch district {
        case .oldQuarter where !velvetAccess && (!riverWon || rep < 20): "Win Riverside and earn 20 reputation"
        case .marina where rep < 40: "Requires 40 reputation"
        case .heights where rep < 60: "Requires 60 reputation"
        case .crown where rep < 80 && tickets == 0: "Requires 80 reputation or a VIP pass"
        case .lounge where rep < 10: "Make a name for yourself. Requires 10 reputation."
        default: nil
        }
    }

    private func entryFee(_ district: District) -> Int {
        if playtest { return 0 }
        if district == .crown && rep < 80 && tickets > 0 { return 0 }
        if district == .river && cash < district.fee { return 0 }
        return district.fee
    }

    private var casinoPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Roulette · 25").font(.headline)
                Spacer()
                GameLabel("Virtual stakes", icon: "circle.dashed")
                    .font(.caption2).foregroundStyle(Noir.gold)
            }
            Text("Red and black pay 2×. Zero awards a VIP pass on either bet.")
                .font(.footnote).foregroundStyle(.secondary)
            HStack {
                Button("Red") { spinWheel(red: true) }.tint(.red)
                Button("Black") { spinWheel(red: false) }
                if let wheel = session.wheel { Text(wheel.formatted()).font(.title3.monospacedDigit()) }
            }.buttonStyle(.bordered).disabled(cash < 25 || savedTournament != nil)
            Divider()
            Text("Slots · 15").font(.headline)
            Text("Three matching symbols pay 8×. Three crowns also award a VIP pass.")
                .font(.footnote).foregroundStyle(.secondary)
            HStack {
                ForEach(0..<3) { index in
                    GameGlyph( session.reels.isEmpty ? "questionmark" : session.reels[index])
                        .frame(width: 32, height: 36)
                        .foregroundStyle(Noir.gold)
                        .background(.black.opacity(0.5), in: .rect(cornerRadius: 6))
                }
                Button("Spin") { spinSlots() }.buttonStyle(.borderedProminent).disabled(cash < 15 || savedTournament != nil)
            }
        }
    }

    private func spinWheel(red: Bool) {
        guard savedTournament == nil, cash >= 25 else { return }
        let result = Int.random(in: 0...36)
        session.wheel = result
        cash -= 25
        if result == 0 {
            tickets += 1
            session.note = "Zero. You won a VIP pass."
        } else {
            let reds: Set<Int> = [1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36]
            let isRed = reds.contains(result)
            let color = isRed ? "red" : "black"
            if isRed == red {
                cash += 50
                session.note = "Result \(result), \(color). Payout: 50."
            } else {
                session.note = "Result \(result), \(color). Bet lost."
            }
        }
    }

    private func spinSlots() {
        guard savedTournament == nil, cash >= 15 else { return }
        cash -= 15
        let symbols = ["suit.spade.fill", "suit.diamond.fill", "moon.stars.fill", "crown.fill"]
        session.reels = (0..<3).map { _ in symbols[Int.random(in: symbols.indices)] }
        guard Set(session.reels).count == 1 else { session.note = "No match this time."; return }
        cash += 120
        if session.reels[0] == "crown.fill" { tickets += 1; session.note = "Three crowns. Payout: 120 and a VIP pass." }
        else { session.note = "Three matching symbols. Payout: 120." }
    }

    private var loungePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LEYA").font(.system(.caption, design: .default)).tracking(3).foregroundStyle(Noir.gold)
            switch relationship {
            case 0:
                Text("I have my own reasons for wanting a seat at The Crown. What are yours?")
                Button("Tell her about the debt") {
                    relationship = 2
                    session.note = "Leya appreciated your honesty. She wants to see you again."
                }.buttonStyle(.borderedProminent)
                Button("Tell her you want to win") {
                    relationship = 1
                    session.note = "Leya smiled. Let's see if you keep your word."
                }.buttonStyle(.bordered)
            case 1, 2:
                Text(relationship == 2 ? "Leya saved you a seat by the window." : "Leya is waiting to see if you keep your promise.")
                if !gift {
                    Button("Give her a record · 75") {
                        guard cash >= 75 else { return }
                        cash -= 75
                        gift = true
                        session.note = "The record brought back a childhood memory."
                    }.buttonStyle(.bordered).disabled(cash < 75)
                }
                if playtest || rep >= 30 {
                    Button("Ask to meet after the game") {
                        relationship = 3
                        session.note = gift ? "Leya agreed. Then we will play our record." : "Leya agreed to meet you by the river."
                    }.buttonStyle(.borderedProminent)
                } else {
                    Text("The next meeting unlocks at 30 reputation.").font(.footnote).foregroundStyle(.secondary)
                }
            default:
                if !crownWon {
                    Text("I will be waiting by the river after the final.")
                } else if leyaFinale.isEmpty {
                    Text("Leya waits by the water. I wanted my family name back in the club. Now I can choose what comes next. And you?")
                    Button("Stay with Leya by the river") { leyaFinale = "river" }.buttonStyle(.borderedProminent)
                    Button("Suggest opening a club together") { leyaFinale = "club" }.buttonStyle(.bordered)
                } else {
                    Text(leyaFinale == "river"
                         ? "You stayed by the river until dawn. \(gift ? "Leya played your record." : "For once, there was nowhere you needed to be.")"
                         : "Leya offered her hand. Deal. And I get to choose the dealer." )
                        .foregroundStyle(Noir.gold)
                }
            }
        }
    }

    private func collectorCall(_ hand: Int) {
        guard debt > 0, hand >= debtNextHand, !debtNotice else { return }
        collectorDeadline = Date().addingTimeInterval(18).timeIntervalSince1970
    }

    private var collectorOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                GameLabel("UNKNOWN CALLER", icon: "phone.fill").font(.system(.caption, design: .default)).foregroundStyle(.red)
                Text("Debt: \(debt). Time to settle up.").font(.title3.bold())
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let remaining = max(0, Int(ceil(collectorDeadline - timeline.date.timeIntervalSince1970)))
                    Text("Time left: \(remaining) s").font(.footnote.monospacedDigit()).foregroundStyle(.red)
                        .onChange(of: remaining, initial: true) { _, value in if value == 0 { resolveDebt(2) } }
                }
                Button("Settle debt · \(debt)") { resolveDebt(0) }.buttonStyle(.borderedProminent).disabled(cash < debt)
                Button("Ask for time · +40 debt") { resolveDebt(1) }.buttonStyle(.bordered)
                Button("Decline · lose 50 cash and 10 rep") { resolveDebt(2) }.buttonStyle(.bordered)
            }
            .padding(22)
            .background {
                NoirArtwork("street", alignment: .top)
                    .overlay(Noir.ink.opacity(0.88))
                    .clipShape(.rect(cornerRadius: 16))
            }
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Noir.gold.opacity(0.35), lineWidth: 1))
            .accessibilityAddTraits(.isModal)
            .padding(24)
        }
    }

    private func resolveDebt(_ choice: Int) {
        guard debtNotice else { return }
        switch choice {
        case 0:
            guard cash >= debt else { return }
            cash -= debt
            debt = 0
            rep += 10
        case 1: debt += 40
        default:
            cash = max(0, cash - 50)
            rep = max(0, rep - 10)
        }
        debtNextHand += 4
        collectorDeadline = 0
    }

}

private final class TournamentSession: ObservableObject {
    @Published var poker: Poker
    @Published var raiseTo = 0

    init(poker: Poker) { self.poker = poker }
}

private struct TournamentView: View {
    let venue: District
    let afterHand: (Int) -> Void
    let save: (Poker) -> Void
    let pause: () -> Void
    let leave: (Bool) -> Void
    @StateObject private var session: TournamentSession

    init(venue: District, initialPoker: Poker, afterHand: @escaping (Int) -> Void,
         save: @escaping (Poker) -> Void, pause: @escaping () -> Void, leave: @escaping (Bool) -> Void) {
        self.venue = venue
        self.afterHand = afterHand
        self.save = save
        self.pause = pause
        self.leave = leave
        _session = StateObject(wrappedValue: TournamentSession(poker: initialPoker))
    }
    private var poker: Poker { session.poker }
    private var raiseTo: Int { session.raiseTo }
    private var isPlayerTurn: Bool { poker.turn == 0 }
    private var upper: Int { poker.seats[0].chips + poker.seats[0].street }
    private var lower: Int { min(poker.price + poker.minRaise, upper) }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 10) {
                    masthead
                    arena(height: max(280, geo.size.height - 209))
                    actionDeck
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Noir.ink)
        .onAppear {
            syncRaise()
            if !poker.result.isEmpty && !poker.finished { afterHand(poker.hand) }
        }
        .onChange(of: poker) { old, new in
            save(new)
            if old.result.isEmpty && !new.result.isEmpty && !new.finished { afterHand(new.hand) }
        }
        .onChange(of: poker.turn) { _,_ in syncRaise() }
        .task(id: poker.turn) {
            while let i = poker.turn, i != 0 {
                do { try await Task.sleep(for: .milliseconds(390)) } catch { return }
                session.poker.bot()
            }
        }
    }

    private func syncRaise() {
        session.raiseTo = min(poker.price + poker.minRaise, poker.seats[0].chips+poker.seats[0].street)
    }

    private var masthead: some View {
        VStack(spacing: 3) {
            Text("RIVER CITY  /  POKER").font(.system(size: 9, weight: .semibold, design: .default))
                .tracking(3).foregroundStyle(Noir.gold)
            Text(venue.title).font(.system(size: 24, weight: .semibold, design: .default)).padding(.horizontal, 48)
                .foregroundStyle(Noir.paper).lineLimit(1).minimumScaleFactor(0.65)
            Text("HAND \(poker.hand)     •     BLINDS \(poker.bigBlind/2)/\(poker.bigBlind)")
                .font(.system(size: 9, weight: .medium, design: .default)).tracking(0.8)
                .foregroundStyle(Noir.paper.opacity(0.66))
        }
        .overlay(alignment: .leading) {
            Button {
                save(poker)
                pause()
            } label: {
                GameGlyph( "map")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 44, height: 44)
            }.buttonStyle(.plain)
                .foregroundStyle(Noir.gold)
                .accessibilityLabel("Save and return to city")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3)
    }

    private func arena(height: CGFloat) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cardWidth = min(45, max(27, (w * 0.63 - 20) / 5))
            let positions: [CGPoint] = [
                .init(x: 0.5, y: 0.90), .init(x: 0.16, y: 0.69), .init(x: 0.16, y: 0.30),
                .init(x: 0.5, y: 0.12), .init(x: 0.84, y: 0.30), .init(x: 0.84, y: 0.69)
            ]
            ZStack {
                NoirArtwork("club", zoom: 1.22, alignment: .top)
                LinearGradient(colors: [.black.opacity(0.22), .black.opacity(0.45), .black.opacity(0.88)],
                               startPoint: .top, endPoint: .bottom)
                TableScene(velvet: venue != .river)
                    .frame(width: w, height: min(h * 0.66, w * 0.8))
                    .position(x: w/2, y: h * 0.51)
                    .accessibilityHidden(true)
                ForEach(1..<poker.seats.count, id: \.self) { i in
                    seatBadge(i, width: min(76, w*0.25))
                        .position(x: w * positions[i].x, y: h * positions[i].y)
                }
                VStack(spacing: 7) {
                    Text("POT   \(poker.pot.formatted())")
                        .font(.system(size: 11, weight: .bold, design: .default))
                        .foregroundStyle(Noir.paper)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(.black.opacity(0.58), in: .capsule)
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            if poker.board.indices.contains(index) {
                                cardFace(poker.board[index], width: cardWidth)
                            } else {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(.black.opacity(0.19))
                                    .overlay(RoundedRectangle(cornerRadius: 5)
                                        .strokeBorder(Noir.paper.opacity(0.19), lineWidth: 1))
                                    .frame(width: cardWidth, height: cardWidth * 1.33)
                            }
                        }
                    }.accessibilityLabel("Community cards")
                }
                .position(x: w/2, y: h * 0.49)
                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        ForEach(Array(poker.seats[0].cards.enumerated()), id: \.offset) { _, card in
                            cardFace(card, width: min(48, cardWidth + 4))
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isPlayerTurn ? "YOUR TURN" : "YOUR STACK")
                            .font(.system(size: 9, weight: .bold, design: .default)).tracking(1)
                            .foregroundStyle(isPlayerTurn ? Noir.gold : Noir.paper.opacity(0.63))
                        Text(poker.seats[0].chips.formatted())
                            .font(.system(.title3, design: .default).weight(.semibold))
                            .foregroundStyle(Noir.paper)
                    }
                }
                .position(x: w/2, y: h * 0.88)
            }
            .clipShape(.rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Noir.gold.opacity(0.27), lineWidth: 1))
        }
        .frame(height: height)
    }

    private func seatBadge(_ index: Int, width: CGFloat) -> some View {
        let seat = poker.seats[index]
        let active = poker.turn == index
        return VStack(spacing: 3) {
            Text(seat.name + (poker.button == index ? " ◈" : ""))
                .font(.system(size: 11, weight: .semibold)).lineLimit(1)
            Text(seat.chips.formatted()).font(.system(size: 10, weight: .medium, design: .default))
                .foregroundStyle(Noir.gold)
            if poker.showdown && !seat.folded {
                Text(seat.cards.map(\.label).joined(separator: " ")).font(.system(size: 10, weight: .bold))
            } else if !seat.action.isEmpty {
                Text(seat.action).font(.system(size: 9)).lineLimit(1).minimumScaleFactor(0.7)
                    .foregroundStyle(Noir.paper.opacity(0.68))
            }
        }
        .foregroundStyle(Noir.paper)
        .padding(.vertical, 6)
        .frame(width: width)
        .background(.black.opacity(0.82), in: .rect(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Noir.gold.opacity(active ? 0.95 : 0.26), lineWidth: 1))
        .opacity(seat.folded ? 0.62 : 1)
    }

    private var actionDeck: some View {
        VStack(spacing: 7) {
            if !poker.result.isEmpty {
                Text(poker.finished ? (poker.seats[0].chips > 0 ? "Tournament won" : "You are out") : "HAND RESULT")
                    .font(.system(size: 12, weight: .semibold, design: .default)).foregroundStyle(Noir.gold)
                Text(poker.result).font(.caption).multilineTextAlignment(.center)
                    .foregroundStyle(Noir.paper)
                if poker.finished {
                    action("Return to city", primary: true) { leave(poker.seats[0].chips > 0) }
                } else {
                    action("Next hand", primary: true) { session.poker.deal() }
                }
            } else if isPlayerTurn {
                if poker.canRaise(0), upper > lower {
                    HStack {
                        Text("Raise to").font(.caption).foregroundStyle(Noir.paper.opacity(0.65))
                        Text(raiseTo.formatted()).font(.caption.monospacedDigit().bold()).foregroundStyle(Noir.gold)
                        Slider(value: Binding(get: { Double(max(lower, min(raiseTo, upper))) },
                                              set: { session.raiseTo = Int($0) }),
                               in: Double(lower)...Double(upper), step: 1)
                            .accessibilityLabel("Raise amount")
                        Button("Max") { session.raiseTo = upper }.font(.caption.bold()).frame(minHeight: 44)
                    }
                }
                HStack(spacing: 7) {
                    action("Fold") { session.poker.move("fold") }
                    action(poker.owed(0) == 0 ? "Check" : "Call \(min(poker.owed(0),poker.seats[0].chips))", primary: true) {
                        session.poker.move("call")
                    }
                    if poker.canRaise(0) {
                        action(raiseTo >= upper ? "All-in" : "Raise \(raiseTo)") {
                            session.poker.move("raise", target: max(lower, raiseTo))
                        }
                    }
                }
            } else {
                Text(poker.turn.map { "To act: \(poker.seats[$0].name)" } ?? "Dealing")
                    .font(.system(.caption, design: .default)).foregroundStyle(Noir.gold)
                    .frame(maxWidth: .infinity, minHeight: 82)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 108)
        .background(Color(red: 0.075, green: 0.095, blue: 0.097), in: .rect(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(Noir.gold.opacity(0.19), lineWidth: 1))
    }

    private func action(_ title: String, primary: Bool = false, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(title).font(.system(size: 14, weight: .bold))
                .lineLimit(1).minimumScaleFactor(0.68)
                .frame(maxWidth: .infinity, minHeight: 46)
                .padding(.horizontal, 4)
                .foregroundStyle(primary ? Noir.ink : Noir.paper)
                .background {
                    RoundedRectangle(cornerRadius: 8).fill(
                        LinearGradient(colors: primary ? [Noir.paper, Noir.gold] : [Noir.brass.opacity(0.48), .black.opacity(0.4)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                }
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Noir.gold.opacity(0.4), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func cardFace(_ card: Card, width: CGFloat) -> some View {
        let suit = ["♠","♥","♣","♦"][card.suit]
        let rank = card.rank < 11 ? String(card.rank) : ["J","Q","K","A"][card.rank-11]
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 5).fill(
                LinearGradient(colors: [.white, Noir.paper], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            Text(rank).font(.system(size: width*0.33, weight: .heavy, design: .default))
                .padding(.leading, 4).padding(.top, 2)
            Text(suit).font(.system(size: width*0.55, weight: .semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 4).padding(.bottom, 2)
        }
        .foregroundStyle(card.suit == 1 || card.suit == 3 ? Color(red: 0.57, green: 0.10, blue: 0.15) : Noir.ink)
        .frame(width: width, height: width*1.33)
        .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
        .accessibilityLabel(card.label)
    }

}

struct TableScene: UIViewRepresentable {
    var velvet = false
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X

        func oval(_ width: CGFloat, _ depth: CGFloat, _ height: CGFloat, _ y: Float, _ color: UIColor) {
            let path = UIBezierPath()
            for index in 0..<96 {
                let angle = Double(index) * 2 * .pi / 96
                let point = CGPoint(x: cos(angle)*width/2, y: sin(angle)*depth/2)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.close()
            let shape = SCNShape(path: path, extrusionDepth: height)
            shape.chamferRadius = min(0.04, height/3)
            shape.firstMaterial?.diffuse.contents = color
            let node = SCNNode(geometry: shape)
            node.eulerAngles.x = -.pi/2
            node.position.y = y
            scene.rootNode.addChildNode(node)
        }
        oval(8.55,5.28,0.38,0,UIColor(red: 0.23, green: 0.13, blue: 0.09, alpha: 1))
        oval(8.42,5.15,0.085,0.19,UIColor(red: 0.63, green: 0.43, blue: 0.22, alpha: 1))
        oval(8.23,4.96,0.22,0.29,UIColor(red: 0.17, green: 0.12, blue: 0.09, alpha: 1))
        let felt = velvet ? UIColor(red: 0.31, green: 0.065, blue: 0.11, alpha: 1)
                          : UIColor(red: 0.04, green: 0.27, blue: 0.21, alpha: 1)
        oval(7.82,4.55,0.055,0.38,UIColor(red: 0.50, green: 0.33, blue: 0.17, alpha: 1))
        oval(7.68,4.42,0.065,0.405,felt)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 4.45
        camera.position = .init(0,9,8)
        camera.look(at: .init(0,0,0))
        scene.rootNode.addChildNode(camera)
        view.pointOfView = camera
        view.autoenablesDefaultLighting = true
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) {}
}

private enum Noir {
    static let ink = Color(red: 0.025, green: 0.045, blue: 0.055)
    static let gold = Color(red: 0.95, green: 0.73, blue: 0.40)
    static let brass = Color(red: 0.39, green: 0.24, blue: 0.08)
    static let paper = Color(red: 1, green: 0.96, blue: 0.86)
}

private struct NoirScene: View {
    let page: Int
    var body: some View {
        NoirArtwork(page == 0 ? "street" : page == 3 ? "city" : "woman",
                    alignment: page == 2 ? .trailing : .center)
    }
}

private struct NoirArtwork: View {
    let name: String
    let zoom: CGFloat
    let alignment: Alignment

    init(_ name: String, zoom: CGFloat = 1, alignment: Alignment = .center) {
        self.name = name
        self.alignment = alignment
        self.zoom = zoom
    }

    var body: some View {
        GeometryReader { geometry in
            if let url = Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "Art"),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width * zoom, height: geometry.size.height * zoom)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: alignment)
                    .clipped()
            } else {
                Noir.ink
            }
        }
        .accessibilityHidden(true)
    }
}


private struct GameLabel: View {
    let title: String
    let icon: String
    init(_ title: String, icon: String) { self.title = title; self.icon = icon }
    var body: some View {
        HStack(spacing: 7) {
            GameGlyph(icon).frame(width: 18, height: 18)
            Text(title)
        }
    }
}

private struct GameGlyph: View {
    let name: String
    init(_ name: String) { self.name = name }

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            var path = Path()
            func polygon(_ points: [(Double, Double)]) {
                path.addLines(points.map { CGPoint(x: $0.0*w, y: $0.1*h) })
                path.closeSubpath()
            }
            switch name {
            case "dice.fill":
                path.addRoundedRect(in: CGRect(x: w*0.07, y: h*0.07, width: w*0.86, height: h*0.86), cornerSize: CGSize(width: w*0.17, height: h*0.17))
            case "coin", "circle.dashed":
                path.addEllipse(in: CGRect(x: w*0.08, y: h*0.08, width: w*0.84, height: h*0.84))
            case "reputation", "moon.stars.fill":
                polygon((0..<10).map { i in
                    let angle = Double(i)*Double.pi/5-Double.pi/2
                    let radius = i.isMultiple(of: 2) ? 0.47 : 0.23
                    return (0.5+cos(angle)*radius,0.5+sin(angle)*radius)
                })
            case "crown.fill", "trophy.fill":
                polygon([(0.12,0.24),(0.32,0.46),(0.5,0.12),(0.68,0.46),(0.88,0.24),(0.79,0.81),(0.21,0.81)])
            case "ticket":
                path.addRoundedRect(in: CGRect(x:w*0.04,y:h*0.20,width:w*0.92,height:h*0.60),cornerSize: CGSize(width:3,height:3))
            case "heart.fill":
                path.move(to: CGPoint(x:w*0.5,y:h*0.86))
                path.addCurve(to:CGPoint(x:w*0.5,y:h*0.26),control1:CGPoint(x:-w*0.5,y:h*0.10),control2:CGPoint(x:w*0.33,y:-h*0.03))
                path.addCurve(to:CGPoint(x:w*0.5,y:h*0.86),control1:CGPoint(x:w*0.67,y:-h*0.03),control2:CGPoint(x:w*1.5,y:h*0.1))
            case "xmark":
                polygon([(0.17,0.08),(0.5,0.41),(0.83,0.08),(0.92,0.17),(0.59,0.5),(0.92,0.83),(0.83,0.92),(0.5,0.59),(0.17,0.92),(0.08,0.83),(0.41,0.5),(0.08,0.17)])
            case "suit.spade.fill":
                polygon([(0.5,0.04),(0.95,0.57),(0.78,0.76),(0.58,0.66),(0.68,0.94),(0.32,0.94),(0.42,0.66),(0.22,0.76),(0.05,0.57)])
            case "play.fill", "arrow.down.right":
                polygon([(0.25,0.13),(0.89,0.5),(0.25,0.87)])
            case "lock.fill", "lock":
                path.addRoundedRect(in:CGRect(x:w*0.18,y:h*0.43,width:w*0.64,height:h*0.47),cornerSize:CGSize(width:3,height:3))
                var loop=Path()
                loop.addRoundedRect(in:CGRect(x:w*0.30,y:h*0.12,width:w*0.40,height:h*0.48),cornerSize:CGSize(width:w*0.2,height:h*0.2))
                context.stroke(loop,with:.color(Noir.gold),lineWidth:2)
            case "checkmark.circle.fill":
                polygon([(0.12,0.49),(0.35,0.73),(0.88,0.19),(0.96,0.29),(0.35,0.91),(0.04,0.59)])
            case "building.2":
                polygon([(0.21,0.90),(0.21,0.22),(0.5,0.08),(0.79,0.22),(0.79,0.90)])
                for y in [0.35,0.53,0.71] {
                    path.move(to: CGPoint(x:w*0.36,y:h*y))
                    path.addLine(to: CGPoint(x:w*0.64,y:h*y))
                }
            case "map":
                polygon([(0.08,0.25),(0.35,0.10),(0.65,0.25),(0.92,0.10),(0.92,0.78),(0.65,0.93),(0.35,0.78),(0.08,0.93)])
            default:
                polygon([(0.5,0.04),(0.96,0.5),(0.5,0.96),(0.04,0.5)])
            }
            context.fill(path, with: .color(Noir.gold.opacity(0.06)))
            context.stroke(path, with: .linearGradient(Gradient(colors: [Noir.paper, Noir.gold]), startPoint: .zero, endPoint: CGPoint(x:w,y:h)),
                           style: StrokeStyle(lineWidth: max(1.2,min(w,h)*0.065), lineCap: .round, lineJoin: .round))
            if name == "dice.fill" {
                for point in [(0.28,0.28),(0.72,0.28),(0.5,0.5),(0.28,0.72),(0.72,0.72)] {
                    context.fill(Path(ellipseIn: CGRect(x: w*(point.0-0.065),y:h*(point.1-0.065),width:w*0.13,height:h*0.13)), with: .color(Noir.gold))
                }
            }
            if name == "coin" || name == "ticket" {
                context.draw(Text(name == "coin" ? "$" : "V").font(.system(size:min(w,h)*0.52,weight:.black,design:.rounded)).foregroundStyle(Noir.gold),at:CGPoint(x:w/2,y:h/2))
            }
        }
        .frame(idealWidth: 20, idealHeight: 20)
        .accessibilityHidden(true)
    }
}

private enum EnglishSave {
 static func text(_ source: String) -> String {
 var text = source
 text = text.replacingOccurrences(of: "Вы", with: "You")
 text = text.replacingOccurrences(of: "Мира", with: "Mira")
 text = text.replacingOccurrences(of: "Лев", with: "Leo")
 text = text.replacingOccurrences(of: "Дана", with: "Dana")
 text = text.replacingOccurrences(of: "Макс", with: "Max")
 text = text.replacingOccurrences(of: "Ника", with: "Nika")
 text = text.replacingOccurrences(of: "Агата", with: "Agatha")
 text = text.replacingOccurrences(of: "Борис", with: "Boris")
 text = text.replacingOccurrences(of: "Сев", with: "Sev")
 text = text.replacingOccurrences(of: "Вера", with: "Vera")
 text = text.replacingOccurrences(of: "Эмиль", with: "Emil")
 text = text.replacingOccurrences(of: "Лея", with: "Leya")
 text = text.replacingOccurrences(of: "Рейн", with: "Rain")
 text = text.replacingOccurrences(of: "Грант", with: "Grant")
 text = text.replacingOccurrences(of: "София", with: "Sophia")
 text = text.replacingOccurrences(of: "Роман", with: "Roman")
 text = text.replacingOccurrences(of: "Рейз", with: "Raise")
 text = text.replacingOccurrences(of: "Пас", with: "Fold")
 text = text.replacingOccurrences(of: "Чек", with: "Check")
 text = text.replacingOccurrences(of: "Олл-ин", with: "All-in")
 text = text.replacingOccurrences(of: "Колл", with: "Call")
 text = text.replacingOccurrences(of: "Фишки возвращены", with: "Chips returned")
 return text
 }
}

private final class ProfileSession: ObservableObject {
    @Published var purchase = false
}

private struct PlayerHub: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("cash") private var cash = 500
    @AppStorage("rep") private var rep = 0
    @AppStorage("bonusPoints") private var points = 0
    @AppStorage("tickets") private var tickets = 0
    @AppStorage("tournamentsPlayed") private var played = 0
    @AppStorage("tournamentsWon") private var won = 0
    @AppStorage("velvetAccess") private var velvetAccess = false
    @StateObject private var session = ProfileSession()
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(rep >= 80 ? "CITY ELITE" : rep >= 30 ? "RISING PLAYER" : "NEWCOMER")
                        .font(.custom("AvenirNextCondensed-DemiBold", size: 28)).foregroundStyle(Noir.gold)
                    LabeledContent("Cash", value: cash.formatted())
                    LabeledContent("Reputation", value: rep.formatted())
                    LabeledContent("Bonus Points", value: points.formatted())
                    LabeledContent("VIP Tickets", value: tickets.formatted())
                }
                Section("Upgrades") {
                    NavigationLink("Velvet Room Membership") {
                        List {
                            Section { Text("Velvet Room Membership").font(.title2)
                                Text("Open The Velvet Room in Old Quarter without the reputation requirement. Tournament buy-ins still apply.") }
                            Section("Requirements") { Text("100 bonus points")
                                LabeledContent("Available", value: points.formatted()) }
                            Button(velvetAccess ? "Unlocked" : "Unlock · 100 points") { session.purchase = true }
                                .disabled(velvetAccess || points < 100)
                        }.navigationTitle("Upgrade")
                        .confirmationDialog("Unlock Velvet Room Membership?", isPresented: $session.purchase, titleVisibility: .visible) {
                            Button("Confirm Unlock · 100 points") {
                                guard !velvetAccess, points >= 100 else { return }
                                points -= 100; velvetAccess = true
                            }
                        } message: { Text("Permanent access. This does not change cards or opponent decisions.") }
                    }
                }
                Section("Inventory") {
                    Text(tickets == 0 ? "No VIP tickets yet" : "Crown invitations · \(tickets)")
                    Text("Crown invitations cover entry when reputation is below 80.").font(.caption)
                }
                Section("Statistics") {
                    LabeledContent("Tournaments completed", value: played.formatted())
                    LabeledContent("Wins", value: won.formatted())
                    Text("Statistics begin with this update.").font(.caption)
                }
                Section("Rules") {
                    Text("No-limit Texas Hold’em · six players. Make the best five-card hand using your two cards and the board. Tournament chips cannot be spent in the city.")
                    Text("Participation earns 20 bonus points on elimination or victory. The winner receives 100 extra points, cash and reputation. Use bonus points for permanent city access.")
                }
            }
            .scrollContentBackground(.hidden).background(Noir.ink)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { PlayerSettings() } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings")
                }
            }
        }.tint(Noir.gold).preferredColorScheme(.dark)
    }
}

private struct PlayerSettings: View {
    @AppStorage("introSeen") private var introSeen = false
    var body: some View {
        Form {
            Section("Help") {
                Button("Replay Introduction") { introSeen = false }
                NavigationLink("Hand Rankings") {
                    List(["Royal flush", "Straight flush", "Four of a kind", "Full house", "Flush", "Straight", "Three of a kind", "Two pair", "One pair", "High card"], id: \.self) { Text($0) }.navigationTitle("Hand Rankings")
                }
            }
            Section("Save Data") { Text("Progress saves automatically. Story mode and Test mode use separate saves.") }
            Section("About") { Text("River City · Development Build") }
        }.navigationTitle("Settings")
    }
}
