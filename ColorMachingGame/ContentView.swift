//
//  ContentView.swift
//  ColorMachingGame
//
//  Created by COBSCCOMP242P-042 on 2026-01-10.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "pencil")
                .imageScale(.large)
                .foregroundStyle(.tint)
            HStack{
                Text("Hello!");
                Text("Yasodha")
            }
            Button("Log In"){
                
            }
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(5)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
