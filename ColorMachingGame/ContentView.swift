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
    
    // Time allotted for each level
    var gameDuration: Int {
        switch self {
        case .easy: return 30
        case .medium: return 25
        case .hard: return 20
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

// MARK: - Game View (With Timer and Back Button)
struct ColorMatchGame: View {
    private let allColors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink, .cyan, .indigo]
    
    let difficulty: Difficulty
    var onExit: () -> Void
    
    @State private var gridColors: [Color] = []
    @State private var targetColor: Color = .gray
    @State private var score = 0
    @State private var timeLeft: Int
    @State private var isGameOver = false
    
    // Timer Setup
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(difficulty: Difficulty, onExit: @escaping () -> Void) {
        self.difficulty = difficulty
        self.onExit = onExit
        _timeLeft = State(initialValue: difficulty.gameDuration)
        _gridColors = State(initialValue: Array(repeating: .gray, count: difficulty.gridCellCount))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Updated Header with Back Icon
            HStack {
                Button(action: {
                    saveAndExit()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.title2.bold())
                        Text("Back")
                            .font(.headline)
                    }
                    .foregroundStyle(.blue)
                }
                
                Spacer()
                
                // Timer UI
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                    Text("\(timeLeft)")
                        .monospacedDigit()
                }
                .font(.title3.bold())
                .foregroundStyle(timeLeft < 6 ? .red : .primary)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(.thinMaterial, in: Capsule())
                
                Spacer()
                
                Text("Score: \(score)")
                    .font(.headline)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal)
            
            Spacer()

            VStack(spacing: 12) {
                Text("Match this color:")
                    .font(.subheadline).bold()
                    .foregroundStyle(.secondary)
                
                RoundedRectangle(cornerRadius: 20)
                    .fill(targetColor)
                    .frame(width: 110, height: 110)
                    .shadow(color: targetColor.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            
            // Grid Layout
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
            
            Spacer()
        }
        .padding(.vertical)
        .onAppear { resetGame() }
        .onReceive(timer) { _ in
            if timeLeft > 0 {
                timeLeft -= 1
            } else if !isGameOver {
                handleTimeOut()
            }
        }
        // Game Over Alert
        .alert("Time's Up!", isPresented: $isGameOver) {
            Button("Retry") { resetGame() }
            Button("Exit") { onExit() }
        } message: {
            Text("Your score: \(score)")
        }
    }
    
    // MARK: - Logic
    private func resetGame() {
        score = 0
        timeLeft = difficulty.gameDuration
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
    
    private func checkMatch(at index: Int) {
        if gridColors[index] == targetColor {
            score += 1
            lightlyReshuffle()
            pickNewTargetColor()
        } else {
            score = max(0, score - 1)
        }
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

#Preview {
    ContentView()
}
