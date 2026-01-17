//
//  ContentView.swift
//  ColorMachingGame
//
//  Created by COBSCCOMP242P-042 on 2026-01-10.
//

import SwiftUI

// Root view expected by ColorMachingGameApp
struct ContentView: View {
    var body: some View {
        ColorMatchGame()
    }
}

struct ColorMatchGame: View {
    // 1. Possible colors for the game
    let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink, .cyan, .indigo]
    
    @State private var gridColors: [Color] = []
    @State private var targetColor: Color = .gray
    @State private var score = 0
    
    init() {
        // Initialize the game on startup
        _gridColors = State(initialValue: (0..<9).map { _ in Color.gray })
    }

    var body: some View {
        VStack(spacing: 30) {
            Text("Score: \(score)")
                .font(.largeTitle)
                .bold()
            
            // The Target Color Indicator
            VStack {
                Text("Match this color:")
                    .font(.headline)
                RoundedRectangle(cornerRadius: 15)
                    .fill(targetColor)
                    .frame(width: 100, height: 100)
                    .shadow(radius: 5)
            }
            
            // The 3x3 Grid
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
            .padding()
            
            Button("Reset Game") {
                resetGame()
            }
            .buttonStyle(.borderedProminent)
        }
        .onAppear {
            resetGame()
        }
    }
    
    // 3. Logic Functions
    func resetGame() {
        // Shuffle colors and pick a new target
        gridColors = colors.shuffled()
        targetColor = gridColors.randomElement() ?? .red
    }
    
    func checkMatch(at index: Int) {
        if gridColors[index] == targetColor {
            score += 1
            resetGame()
        } else {
            // Optional: Penalty for wrong choice
            if score > 0 { score -= 1 }
        }
    }
}
#Preview {
    ContentView()
}

