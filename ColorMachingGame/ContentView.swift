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
    @State private var showHistory = false
    
    var body: some View {
        if let difficulty = selectedDifficulty {
            ColorMatchGame(difficulty: difficulty) {
                selectedDifficulty = nil
            }
        } else {
            StartGameView(startAction: { difficulty in
                selectedDifficulty = difficulty
            }, onShowHistory: {
                showHistory = true
            })
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
        }
    }
}

// MARK: - Start Screen
struct StartGameView: View {
    var startAction: (Difficulty) -> Void
    var onShowHistory: () -> Void
    
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
    
    let difficulty: Difficulty
    var onExit: () -> Void
    
    @State private var gridColors: [Color] = []
    @State private var targetColor: Color = .gray
    @State private var score = 0
    @State private var timeLeft: Int
    @State private var isGameOver = false
    
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
        setupNewLevel()
    }
    
    private func setupNewLevel() {
        let distinctCount = min(difficulty.numberOfDistinctColors, allColors.count)
        let palette = Array(allColors.shuffled().prefix(distinctCount))
        gridColors = (0..<difficulty.gridCellCount).map { _ in palette.randomElement() ?? .blue }
        pickNewTargetColor()
    }
    
    private func pickNewTargetColor() {
        targetColor = gridColors.randomElement() ?? .blue
    }
    
    private func lightlyReshuffle() {
        let distinctCount = min(difficulty.numberOfDistinctColors, allColors.count)
        let palette = Array(allColors.shuffled().prefix(distinctCount))
        let indices = Array(0..<gridColors.count).shuffled().prefix(3)
        for i in indices {
            gridColors[i] = palette.randomElement() ?? gridColors[i]
        }
    }
    
    private func handleTimeOut() {
        isGameOver = true
        if score > 0 {
            ScoreStore.append(ScoreEntry(difficulty: difficulty, score: score))
        }
    }
    
    private func saveAndExit() {
        if score > 0 && !isGameOver {
            ScoreStore.append(ScoreEntry(difficulty: difficulty, score: score))
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
                ToolbarItem(placement: .topBarLeading) { Button("Dismiss") { dismiss() } }
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
