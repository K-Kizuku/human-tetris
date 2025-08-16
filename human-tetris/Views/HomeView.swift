//
//  HomeView.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import SwiftUI

struct HomeView: View {
    @State private var showingGame = false
    @State private var showingSettings = false
    @State private var showingHowTo = false

    var body: some View {
        NavigationView {
            ZStack {
                // ダイナミック背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color.purple.opacity(0.8),
                        Color.blue.opacity(0.6),
                        Color.cyan.opacity(0.4),
                        Color.black,
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // アニメーション背景パーティクル
                ForEach(0..<20, id: \.self) { i in
                    let colors: [Color] = [.cyan, .purple, .pink, .blue, .green]
                    let randomColor = colors[i % colors.count]

                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    randomColor.opacity(0.6),
                                    randomColor.opacity(0.3),
                                    Color.clear,
                                ]),
                                center: .center,
                                startRadius: 1,
                                endRadius: 30
                            )
                        )
                        .frame(width: CGFloat.random(in: 5...15))
                        .position(
                            x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                            y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                        )
                        .opacity(0.3)
                        .animation(
                            .easeInOut(duration: Double.random(in: 2...5))
                                .repeatForever(autoreverses: true),
                            value: i
                        )
                }

                VStack(spacing: 40) {
                    Spacer()

                    VStack(spacing: 10) {
                        Text("Human Tetris")
                            .font(.largeTitle)
                            .fontWeight(.black)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.cyan, .blue, .purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .cyan, radius: 10)
                            .shadow(color: .blue, radius: 5)

                        Text("ポーズでピースを作ろう！！！！！！！！")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .cyan],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .cyan, radius: 3)
                    }

                    VStack(spacing: 20) {
                        NavigationLink(destination: IntegratedGameView()) {
                            MenuButton(title: "ゲームスタート", icon: "play.fill", color: .green)
                        }

                        Button(action: { showingHowTo = true }) {
                            MenuButton(title: "遊び方", icon: "questionmark.circle.fill", color: .blue)
                        }

                        Button(action: { showingSettings = true }) {
                            MenuButton(title: "設定", icon: "gearshape.fill", color: .gray)
                        }
                    }

                    Spacer()

                    Text("iOS 18.0+ 対応")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingHowTo) {
            HowToPlayView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Human Tetris の遊び方")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom)

                    HowToSection(
                        title: "1. ポーズでピース作成",
                        description: "画面の3×4の枠内でポーズを取り、人物の形をテトリスピースに変換します。",
                        icon: "person.fill"
                    )

                    HowToSection(
                        title: "2. ピースを操作",
                        description: "左右移動と回転でピースを配置し、ラインを揃えて消去しましょう。",
                        icon: "gamecontroller.fill"
                    )

                    HowToSection(
                        title: "3. スコアを稼ごう",
                        description: "IoU（一致度）、安定時間、ライン消去、多様性でスコアが決まります。",
                        icon: "star.fill"
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("注意事項")
                            .font(.headline)
                            .foregroundColor(.red)

                        Text("• 無理なポーズは避け、転倒に注意してください")
                        Text("• 周囲の障害物に気をつけてください")
                        Text("• 第三者の写り込みにご配慮ください")
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("遊び方")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct HowToSection: View {
    let title: String
    let description: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    HomeView()
}
