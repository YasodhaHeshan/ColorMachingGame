import SwiftUI
import Combine

// MARK: - Difficulty
enum Difficulty: String, CaseIterable, Identifiable, Codable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    
    var id: String { rawValue }
    
    var numberOfDistinctColors: Int {
        switch self {
        case .easy: return 3
        case .medium: return 5
        case .hard: return 9
        }
    }
    
    var gridCellCount: Int {
        switch self {
        case .easy: return 9
        case .medium: return 16
        case .hard: return 20
        }
    }

    var gridColumns: Int {
        switch self {
        case .easy: return 3
        case .medium: return 4
        case .hard: return 5
        }
    }
    
    var gameDuration: Int {
        switch self {
        case .easy: return 60
        case .medium: return 45
        case .hard: return 30
        }
    }
}

// MARK: - Score Models
// MARK: - Achievements
struct Achievement: Identifiable, Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case firstGame
        case score10
        case score25
        case score50
        case threeCombo
        case flawlessEasy
        case flawlessMedium
        case flawlessHard
        case hardCleared
    }

    let id: Kind
    var title: String
    var detail: String
    var icon: String
    var unlockedDate: Date?

    var isUnlocked: Bool { unlockedDate != nil }
}

struct AchievementCatalog {
    static func all() -> [Achievement] {
        [
            Achievement(id: .firstGame, title: "Getting Started", detail: "Finish your first game.", icon: "sparkles", unlockedDate: nil),
            Achievement(id: .score10, title: "On a Roll", detail: "Reach a score of 10 in a single game.", icon: "10.circle.fill", unlockedDate: nil),
            Achievement(id: .score25, title: "Quarter Century", detail: "Reach a score of 25 in a single game.", icon: "25.circle.fill", unlockedDate: nil),
            Achievement(id: .score50, title: "Half Century", detail: "Reach a score of 50 in a single game.", icon: "50.circle.fill", unlockedDate: nil),
            Achievement(id: .threeCombo, title: "Combo Starter", detail: "Hit a 3x combo.", icon: "bolt.fill", unlockedDate: nil),
            Achievement(id: .flawlessEasy, title: "Flawless (Easy)", detail: "Finish Easy without a miss.", icon: "checkmark.seal.fill", unlockedDate: nil),
            Achievement(id: .flawlessMedium, title: "Flawless (Medium)", detail: "Finish Medium without a miss.", icon: "checkmark.seal.fill", unlockedDate: nil),
            Achievement(id: .flawlessHard, title: "Flawless (Hard)", detail: "Finish Hard without a miss.", icon: "checkmark.seal.fill", unlockedDate: nil),
            Achievement(id: .hardCleared, title: "Hard Mode", detail: "Finish a game on Hard.", icon: "flame.fill", unlockedDate: nil)
        ]
    }
}

struct AchievementStore {
    private static let key = "ColorMatch_Achievements_v1"

    static func load() -> [Achievement] {
        let defaults = UserDefaults.standard
        let base = AchievementCatalog.all()
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode([Achievement].self, from: data) else {
            return base
        }
        // Merge saved unlock dates back into current catalog
        var map = Dictionary(uniqueKeysWithValues: base.map { ($0.id, $0) })
        for item in saved { if let _ = map[item.id] { map[item.id]?.unlockedDate = item.unlockedDate } }
        return Array(map.values).sorted { $0.title < $1.title }
    }

    static func save(_ items: [Achievement]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func unlock(_ kind: Achievement.Kind) {
        var items = load()
        if let idx = items.firstIndex(where: { $0.id == kind }) {
            if items[idx].unlockedDate == nil {
                items[idx].unlockedDate = Date()
                save(items)
            }
        }
    }
}

struct ScoreEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let difficulty: Difficulty
    let score: Int

    init(id: UUID = UUID(), date: Date = Date(), difficulty: Difficulty, score: Int) {
        self.id = id
        self.date = date
        self.difficulty = difficulty
        self.score = score
    }
}

struct ScoreStore {
    private static let key = "ColorMatch_ScoreHistory_v1"

    static func load() -> [ScoreEntry] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([ScoreEntry].self, from: data)) ?? []
    }

    static func save(_ entries: [ScoreEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func append(_ entry: ScoreEntry) {
        var current = load()
        current.append(entry)
        save(current)
    }
}

// MARK: - Root Content View
struct ContentView: View {
    @State private var selectedDifficulty: Difficulty? = nil
    
    var body: some View {
        TabView {
            // Home Tab: start screen or active game
            Group {
                if let difficulty = selectedDifficulty {
                    ColorMatchGame(difficulty: difficulty) {
                        selectedDifficulty = nil
                    }
                } else {
                    StartGameView(startAction: { difficulty in
                        selectedDifficulty = difficulty
                    }, onShowHistory: {
                        // Switch to History tab via selection binding if added later
                    }, onShowAchievements: {
                        // Switch to Achievements tab via selection binding if added later
                    })
                }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            // Achievements Tab
            AchievementsView()
                .tabItem {
                    Label("Achievements", systemImage: "rosette")
                }

            // History Tab
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
        }
    }
}

// MARK: - Start Screen
struct StartGameView: View {
    var startAction: (Difficulty) -> Void
    var onShowHistory: () -> Void
    var onShowAchievements: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Color Match")
                .font(.system(size: 48, weight: .black, design: .rounded))
            
            Text("Select Difficulty")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 16) {
                ForEach(Difficulty.allCases) { difficulty in
                    Button {
                        startAction(difficulty)
                    } label: {
                        HStack {
                            Image(systemName: icon(for: difficulty))
                            Text(difficulty.rawValue)
                                .font(.title3).bold()
                            Spacer()
                            Text("\(difficulty.gameDuration)s")
                                .font(.caption).bold()
                                .padding(6)
                                .background(.black.opacity(0.1), in: Capsule())
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(color(for: difficulty))
                }
            }
            .padding(.horizontal, 40)
            
            Button(action: onShowHistory) {
                Label("View History", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .padding(.top, 10)
            
            Button(action: onShowAchievements) {
                Label("Achievements", systemImage: "rosette")
                    .font(.headline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.purple)
            
            Spacer()
        }
    }
    
    private func icon(for difficulty: Difficulty) -> String {
        switch difficulty {
        case .easy: return "tortoise.fill"
        case .medium: return "hare.fill"
        case .hard: return "flame.fill"
        }
    }
    
    private func color(for difficulty: Difficulty) -> Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}

// MARK: - Game View (With Enhanced Logic & Animations)
struct ColorMatchGame: View {
    private let allColors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink, .cyan, .indigo]
    
    // Categorize base colors into schemes to avoid similar colors adjacent in Easy/Medium
    private func colorCategory(_ color: Color) -> String {
        switch color {
        case .red, .pink: return "warm-red"
        case .orange, .yellow: return "warm-yellow"
        case .green: return "green"
        case .blue, .cyan, .indigo: return "blue"
        case .purple: return "purple"
        default: return "other"
        }
    }

    private func buildConstrainedGrid(from palette: [Color], cells: Int, columns: Int) -> [Color] {
        // Ensure no adjacent (left/up) cells share the same category
        var grid: [Color] = Array(repeating: .gray, count: cells)
        guard !palette.isEmpty else { return grid }
        let categories = palette.map { ($0, colorCategory($0)) }
        for index in 0..<cells {
            let leftIndex = (index % columns == 0) ? nil : index - 1
            let upIndex = (index - columns) >= 0 ? index - columns : nil
            let leftCat = leftIndex.flatMap { colorCategory(grid[$0]) }
            let upCat = upIndex.flatMap { colorCategory(grid[$0]) }

            // Candidates that don't match left/up category
            let candidates = categories.filter { pair in
                let cat = pair.1
                if let l = leftCat, l == cat { return false }
                if let u = upCat, u == cat { return false }
                return true
            }
            let pickFrom = candidates.isEmpty ? categories : candidates
            grid[index] = (pickFrom.randomElement()?.0) ?? palette.randomElement()!
        }
        return grid
    }
    
    let difficulty: Difficulty
    var onExit: () -> Void
    
    @State private var gridColors: [Color] = []
    @State private var targetColor: Color = .gray
    @State private var score = 0
    @State private var timeLeft: Int
    @State private var isGameOver = false
    @State private var hadAnyInput = false
    
    // Streaks and Animation States
    @State private var correctStreak = 0
    @State private var wrongStreak = 0
    @State private var shakeOffset: CGFloat = 0
    @State private var targetScale: CGFloat = 1.0
    @State private var timeBonusTrigger = false
    @State private var floatingText: String = ""
    @State private var floatingTextOpacity: Double = 0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(difficulty: Difficulty, onExit: @escaping () -> Void) {
        self.difficulty = difficulty
        self.onExit = onExit
        _timeLeft = State(initialValue: difficulty.gameDuration)
        _gridColors = State(initialValue: Array(repeating: .gray, count: difficulty.gridCellCount))
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: saveAndExit) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.headline).bold()
                    }
                    
                    Spacer()
                    
                    // Animated Timer
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                        Text("\(timeLeft)").monospacedDigit()
                    }
                    .font(.title3.bold())
                    .foregroundStyle(timeLeft < 6 ? .red : .primary)
                    .scaleEffect(timeBonusTrigger ? 1.4 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.4), value: timeBonusTrigger)
                    .padding(.vertical, 8).padding(.horizontal, 16)
                    .background(.thinMaterial, in: Capsule())
                    
                    Spacer()
                    
                    Text("Score: \(score)")
                        .font(.headline)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal)
                
                Spacer()

                // Target Color Section
                VStack(spacing: 12) {
                    Text("Match this color:")
                        .font(.subheadline).bold()
                        .foregroundStyle(.secondary)
                    
                    RoundedRectangle(cornerRadius: 24)
                        .fill(targetColor)
                        .frame(width: 120, height: 120)
                        .scaleEffect(targetScale)
                        .shadow(color: targetColor.opacity(0.4), radius: 15)
                }
                
                // Grid
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: difficulty.gridColumns)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0..<gridColors.count, id: \.self) { index in
                        Button {
                            hadAnyInput = true
                            checkMatch(at: index)
                        } label: {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(gridColors[index])
                                .frame(height: 80)
                                .shadow(radius: 2)
                        }
                        .disabled(isGameOver)
                    }
                }
                .padding(.horizontal, 24)
                .offset(x: shakeOffset) // Error Shake
                
                // Streak info
                HStack {
                    if correctStreak > 0 {
                        Text("Combo: \(correctStreak)x").foregroundColor(.green).bold()
                    } else if wrongStreak > 0 {
                        Text("Misses: \(wrongStreak)").foregroundColor(.red).bold()
                    }
                }
                .font(.callout)
                .frame(height: 20)
                
                Spacer()
            }
            .padding(.vertical)

            // Floating Bonus Text Overlay
            Text(floatingText)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundColor(floatingText.contains("+") ? .green : .red)
                .opacity(floatingTextOpacity)
                .offset(y: floatingTextOpacity == 1 ? -100 : -50)
        }
        .onAppear { resetGame() }
        .onReceive(timer) { _ in
            if timeLeft > 0 {
                timeLeft -= 1
            } else if !isGameOver {
                handleTimeOut()
            }
        }
        .alert("Time's Up!", isPresented: $isGameOver) {
            Button("Retry") { resetGame() }
            Button("Exit") { onExit() }
        } message: {
            Text("Final Score: \(score)")
        }
    }
    
    // MARK: - Logic
    
    private func checkMatch(at index: Int) {
        if gridColors[index] == targetColor {
            handleCorrectMatch()
        } else {
            handleWrongMatch()
        }
    }
    
    private func handleCorrectMatch() {
        score += 1
        correctStreak += 1
        wrongStreak = 0
        
        if score == 1 { AchievementStore.unlock(.firstGame) }
        if score >= 10 { AchievementStore.unlock(.score10) }
        if score >= 25 { AchievementStore.unlock(.score25) }
        if score >= 50 { AchievementStore.unlock(.score50) }
        if correctStreak >= 3 { AchievementStore.unlock(.threeCombo) }
        
        // Success Pulse Animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            targetScale = 1.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            targetScale = 1.0
        }
        
        // 3-Streak Reward
        if correctStreak % 3 == 0 {
            triggerFloatingText(text: "+5s TIME BONUS!")
            modifyTime(by: 5)
        }
        
        lightlyReshuffle()
        pickNewTargetColor()
    }
    
    private func handleWrongMatch() {
        score = max(0, score - 1)
        wrongStreak += 1
        correctStreak = 0
        
        // Shake Animation
        triggerShake()
        
        // 3-Wrong Penalty
        if wrongStreak % 3 == 0 {
            triggerFloatingText(text: "-5s PENALTY")
            modifyTime(by: -5)
        }
    }
    
    private func triggerShake() {
        withAnimation(.default) {
            for offset in [-10, 10, -10, 10, 0] {
                shakeOffset = CGFloat(offset)
            }
        }
    }
    
    private func modifyTime(by seconds: Int) {
        timeLeft = max(0, timeLeft + seconds)
        timeBonusTrigger = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            timeBonusTrigger = false
        }
    }
    
    private func triggerFloatingText(text: String) {
        floatingText = text
        withAnimation(.easeOut(duration: 0.5)) {
            floatingTextOpacity = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.3)) {
                floatingTextOpacity = 0
            }
        }
    }

    private func resetGame() {
        score = 0
        timeLeft = difficulty.gameDuration
        correctStreak = 0
        wrongStreak = 0
        isGameOver = false
        hadAnyInput = false
        setupNewLevel()
    }
    
    private func setupNewLevel() {
        let distinctCount = min(difficulty.numberOfDistinctColors, allColors.count)
        let palette = Array(allColors.shuffled().prefix(distinctCount))
        if difficulty == .hard {
            gridColors = (0..<difficulty.gridCellCount).map { _ in palette.randomElement() ?? .blue }
        } else {
            gridColors = buildConstrainedGrid(from: palette, cells: difficulty.gridCellCount, columns: difficulty.gridColumns)
        }
        pickNewTargetColor()
    }
    
    private func pickNewTargetColor() {
        targetColor = gridColors.randomElement() ?? .blue
    }
    
    private func lightlyReshuffle() {
        let distinctCount = min(difficulty.numberOfDistinctColors, allColors.count)
        let palette = Array(allColors.shuffled().prefix(distinctCount))
        if difficulty == .hard {
            // Hard can be fully random
            let indices = Array(0..<gridColors.count).shuffled().prefix(3)
            for i in indices { gridColors[i] = palette.randomElement() ?? gridColors[i] }
        } else {
            // Rebuild a small portion respecting adjacency constraints by patching cells
            let columns = difficulty.gridColumns
            let categories = palette.map { ($0, colorCategory($0)) }
            let indices = Array(0..<gridColors.count).shuffled().prefix(3)
            for i in indices {
                let leftIndex = (i % columns == 0) ? nil : i - 1
                let rightIndex = ((i % columns) == columns - 1) ? nil : i + 1
                let upIndex = (i - columns) >= 0 ? i - columns : nil
                let downIndex = (i + columns) < gridColors.count ? i + columns : nil
                let neighborCats: Set<String> = [leftIndex, rightIndex, upIndex, downIndex]
                    .compactMap { $0 }
                    .map { colorCategory(gridColors[$0]) }
                    .reduce(into: Set<String>()) { $0.insert($1) }
                let candidates = categories.filter { pair in !neighborCats.contains(pair.1) }
                let pickFrom = candidates.isEmpty ? categories : candidates
                gridColors[i] = (pickFrom.randomElement()?.0) ?? gridColors[i]
            }
        }
    }
    
    private func handleTimeOut() {
        isGameOver = true
        if hadAnyInput {
            switch difficulty {
            case .easy:
                if wrongStreak == 0 { AchievementStore.unlock(.flawlessEasy) }
            case .medium:
                if wrongStreak == 0 { AchievementStore.unlock(.flawlessMedium) }
            case .hard:
                AchievementStore.unlock(.hardCleared)
                if wrongStreak == 0 { AchievementStore.unlock(.flawlessHard) }
            }
        }
        if score > 0 {
            ScoreStore.append(ScoreEntry(difficulty: difficulty, score: score))
        }
    }
    
    private func saveAndExit() {
        if score > 0 && !isGameOver {
            ScoreStore.append(ScoreEntry(difficulty: difficulty, score: score))
        }
        if hadAnyInput {
            switch difficulty {
            case .easy:
                if wrongStreak == 0 { AchievementStore.unlock(.flawlessEasy) }
            case .medium:
                if wrongStreak == 0 { AchievementStore.unlock(.flawlessMedium) }
            case .hard:
                AchievementStore.unlock(.hardCleared)
                if wrongStreak == 0 { AchievementStore.unlock(.flawlessHard) }
            }
        }
        onExit()
    }
}

// MARK: - History View
struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [ScoreEntry] = ScoreStore.load().sorted { $0.date > $1.date }

    private func bestScore(for difficulty: Difficulty) -> Int? {
        entries.filter { $0.difficulty == difficulty }.map(\.score).max()
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Personal Bests") {
                    ForEach(Difficulty.allCases) { diff in
                        HStack {
                            Text(diff.rawValue)
                            Spacer()
                            if let best = bestScore(for: diff) {
                                Text("\(best)").bold()
                            } else {
                                Text("-").foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Recent Scores") {
                    if entries.isEmpty {
                        Text("No records found.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(entries) { entry in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(entry.difficulty.rawValue).font(.headline)
                                    Text(entry.date, style: .date).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(entry.score)").font(.title3).bold()
                            }
                        }
                        .onDelete { indexSet in
                            entries.remove(atOffsets: indexSet)
                            ScoreStore.save(entries)
                        }
                    }
                }
            }
            .navigationTitle("Score History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear All") {
                        entries.removeAll()
                        ScoreStore.save(entries)
                    }
                }
            }
        }
    }
}
// MARK: - Achievements View
struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items: [Achievement] = AchievementStore.load()

    private func unlockedCount() -> Int { items.filter { $0.isUnlocked }.count }

    var body: some View {
        NavigationStack {
            List {
                Section("Progress") {
                    HStack {
                        Label("Unlocked", systemImage: "rosette")
                        Spacer()
                        Text("\(unlockedCount())/\(items.count)").bold()
                    }
                }

                Section("All Achievements") {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(item.isUnlocked ? Color.green.opacity(0.2) : Color.gray.opacity(0.15))
                                Image(systemName: item.icon)
                                    .foregroundStyle(item.isUnlocked ? .green : .secondary)
                            }
                            .frame(width: 36, height: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.headline)
                                Text(item.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let date = item.unlockedDate {
                                Text(date, style: .date).font(.caption).foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "lock.fill").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Achievements")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") {
                        // Reset progress to defaults
                        items = AchievementCatalog.all()
                        AchievementStore.save(items)
                    }
                }
            }
            .onAppear { items = AchievementStore.load() }
        }
    }
}

