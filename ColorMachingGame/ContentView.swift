//
//  ContentView.swift
//  ColorMachingGame
//
//  Created by COBSCCOMP242P-042 on 2026-01-10.
//

import SwiftUI

// MARK: - Difficulty
enum Difficulty: String, CaseIterable, Identifiable, Codable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    
    var id: String { rawValue }
    
    // Controls how many distinct colors appear in the grid
    var numberOfDistinctColors: Int {
        switch self {
        case .easy: return 3
        case .medium: return 5
        case .hard: return 9
        }
    }
    
    // Controls how many grid cells appear
    var gridCellCount: Int {
        switch self {
        case .easy: return 9  // 3x 3
        case .medium: return 16 // 4x 4
        case .hard: return 20 // 5x 4
        }
    }

    // Suggested number of columns for the grid layout
    var gridColumns: Int {
        switch self {
        case .easy: return 3
        case .medium: return 4
        case .hard: return 5
        }
    }
}

// MARK: - Score History Models
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

// Root view expected by ColorMachingGameApp
struct ContentView: View {
    @State private var selectedDifficulty: Difficulty? = nil
    @State private var showHistory = false
    
    var body: some View {
        if let difficulty = selectedDifficulty {
            ColorMatchGame(difficulty: difficulty) {
                // onExit: return to start screen
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
    var onShowHistory: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Color Match Game")
                .font(.largeTitle).bold()
            Text("Choose Difficulty")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            ForEach(Difficulty.allCases) { difficulty in
                Button {
                    startAction(difficulty)
                } label: {
                    HStack {
                        Image(systemName: icon(for: difficulty))
                        Text(difficulty.rawValue)
                            .font(.title3).bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            
            Button {
                onShowHistory()
            } label: {
                Label("View History", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .padding(.horizontal)
            
            Spacer(minLength: 0)
        }
        .padding()
    }
    
    private func icon(for difficulty: Difficulty) -> String {
        switch difficulty {
        case .easy: return "tortoise.fill"
        case .medium: return "hare.fill"
        case .hard: return "flame.fill"
        }
    }
}

// MARK: - Game View
struct ColorMatchGame: View {
    // All available colors in the palette
    private let allColors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink, .cyan, .indigo]
    
    let difficulty: Difficulty
    var onExit: () -> Void = {}
    
    @State private var gridColors: [Color] = []
    @State private var targetColor: Color = .gray
    @State private var score = 0
    
    init(difficulty: Difficulty, onExit: @escaping () -> Void = {}) {
        self.difficulty = difficulty
        self.onExit = onExit
        _gridColors = State(initialValue: Array(repeating: .gray, count: difficulty.gridCellCount))
    }
    
    private func persistCurrentScoreIfNeeded() {
        guard score > 0 else { return }
        let entry = ScoreEntry(difficulty: difficulty, score: score)
        ScoreStore.append(entry)
        score = 0
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button {
                    persistCurrentScoreIfNeeded()
                    onExit()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                Spacer()
                Text(difficulty.rawValue)
                    .font(.headline)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(.thinMaterial, in: Capsule())
            }
            
            Text("Score: \(score)")
                .font(.largeTitle)
                .bold()
            
            VStack(spacing: 8) {
                Text("Match this color:")
                    .font(.headline)
                RoundedRectangle(cornerRadius: 15)
                    .fill(targetColor)
                    .frame(width: 120, height: 120)
                    .shadow(radius: 5)
            }
            
            let columns = Array(repeating: GridItem(.flexible()), count: difficulty.gridColumns)
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(0..<gridColors.count, id: \.self) { index in
                    Button {
                        checkMatch(at: index)
                    } label: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(gridColors[index])
                            .frame(height: 100)
                            .shadow(radius: 2)
                    }
                }
            }
            .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button("Reset Game") {
                    persistCurrentScoreIfNeeded()
                    resetGame()
                }
                .buttonStyle(.bordered)
                Button("New Target") { pickNewTargetColor() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear { resetGame() }
        .onDisappear { persistCurrentScoreIfNeeded() }
    }
    
    // MARK: - Logic
    private func resetGame() {
        // Build the palette based on difficulty
        let distinctCount = min(difficulty.numberOfDistinctColors, allColors.count)
        let palette = Array(allColors.shuffled().prefix(distinctCount))
        
        // Fill grid cells using the limited palette
        gridColors = (0..<difficulty.gridCellCount).map { _ in palette.randomElement() ?? .red }
        pickNewTargetColor()
    }
    
    private func pickNewTargetColor() {
        targetColor = gridColors.randomElement() ?? .red
    }
    
    private func checkMatch(at index: Int) {
        if gridColors[index] == targetColor {
            score += 1
            // On correct match, choose a new target and slightly reshuffle a few cells
            lightlyReshuffle()
            pickNewTargetColor()
        } else {
            if score > 0 { score -= 1 }
        }
    }
    
    private func lightlyReshuffle() {
        // Change 3 random cells to new colors from the current difficulty palette
        let distinctCount = min(difficulty.numberOfDistinctColors, allColors.count)
        let palette = Array(allColors.shuffled().prefix(distinctCount))
        let indices = Array(0..<gridColors.count).shuffled().prefix(min(3, gridColors.count))
        for i in indices {
            gridColors[i] = palette.randomElement() ?? gridColors[i]
        }
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
                Section("Best Scores") {
                    ForEach(Difficulty.allCases) { diff in
                        HStack {
                            Text(diff.rawValue)
                            Spacer()
                            if let best = bestScore(for: diff) {
                                Text("\(best)").bold()
                            } else {
                                Text("—").foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Recent Scores") {
                    if entries.isEmpty {
                        Text("No scores yet. Play a game to set your first score!")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(entries) { entry in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.difficulty.rawValue)
                                        .font(.headline)
                                    Text(entry.date, style: .date)
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                                Spacer()
                                Text("\(entry.score)")
                                    .font(.title3).bold()
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear All") {
                        entries.removeAll()
                        ScoreStore.save(entries)
                    }
                    .disabled(entries.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

