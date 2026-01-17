//
//  ContentView.swift
//  ColorMachingGame
//
//  Created by COBSCCOMP242P-042 on 2026-01-10.
//

import SwiftUI

// MARK: - Difficulty
enum Difficulty: String, CaseIterable, Identifiable {
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
}

// Root view expected by ColorMachingGameApp
struct ContentView: View {
    @State private var selectedDifficulty: Difficulty? = nil
    
    var body: some View {
        if let difficulty = selectedDifficulty {
            ColorMatchGame(difficulty: difficulty) {
                // onExit: return to start screen
                selectedDifficulty = nil
            }
        } else {
            StartGameView { difficulty in
                selectedDifficulty = difficulty
            }
        }
    }
}

// MARK: - Start Screen
struct StartGameView: View {
    var startAction: (Difficulty) -> Void
    
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
        _gridColors = State(initialValue: (0..<9).map { _ in Color.gray })
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button("Back") { onExit() }
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
            
            let columns = Array(repeating: GridItem(.flexible()), count: 3)
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(0..<9, id: \.self) { index in
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
                Button("Reset Game") { resetGame() }
                    .buttonStyle(.bordered)
                Button("New Target") { pickNewTargetColor() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear { resetGame() }
    }
    
    // MARK: - Logic
    private func resetGame() {
        // Build the palette based on difficulty
        let distinctCount = min(difficulty.numberOfDistinctColors, allColors.count)
        let palette = Array(allColors.shuffled().prefix(distinctCount))
        
        // Fill 9 grid cells using the limited palette
        gridColors = (0..<9).map { _ in palette.randomElement() ?? .red }
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
        let indices = Array(0..<9).shuffled().prefix(3)
        for i in indices {
            gridColors[i] = palette.randomElement() ?? gridColors[i]
        }
    }
}

#Preview {
    ContentView()
}

