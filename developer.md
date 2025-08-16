# Human Tetris - 開発者向けドキュメント

## プロジェクト概要

Human Tetrisは、カメラでポーズを認識してテトリスピースを生成・操作するiOSアプリです。AVFoundation + Vision + SwiftUIを使用してリアルタイム画像処理とゲーム体験を統合しています。

**技術スタック**: iOS 18.0+, Swift 5.x, SwiftUI, AVFoundation, Vision, SwiftData

---

## ディレクトリ構成と責務

```
human-tetris/
├─ App/
│  └─ HumanTetrisApp.swift          # エントリポイント、DI設定
├─ Features/                        # 機能別モジュール
│  ├─ Capture/                      # カメラ・画像処理パイプライン
│  │  ├─ CameraManager.swift        # AVFoundation カメラ制御
│  │  ├─ VisionProcessor.swift      # Vision 人物セグメンテーション
│  │  ├─ QuantizationProcessor.swift # 3×4グリッド量子化
│  │  ├─ ShapeExtractor.swift       # 連結成分抽出・ビームサーチ
│  │  ├─ CountdownManager.swift     # 3秒カウントダウン・オーディオ
│  │  └─ ShapeHistoryManager.swift  # 形状履歴・多様性管理
│  ├─ Game/                         # テトリスゲームロジック
│  │  ├─ GameCore.swift             # 盤面・衝突・ライン消去・操作
│  │  └─ GamePieceProvider.swift    # ピース提供プロトコル
│  ├─ Hinting/                      # Board-driven ヒント（未実装）
│  └─ Render/                       # 描画・アニメーション
├─ Models/                          # データモデル
│  ├─ Grid4x3.swift                 # 4×3グリッド構造
│  ├─ Polyomino.swift               # ポリオミノ（3-6セル連結）
│  ├─ GameState.swift               # ゲーム状態管理
│  └─ CaptureState.swift            # キャプチャ状態管理
├─ ViewModels/                      # MVVM ViewModel（現在最小限）
├─ Views/                           # SwiftUI画面
│  ├─ HomeView.swift                # ホーム画面・メニュー
│  ├─ UnifiedGameView.swift         # **メイン統合画面**
│  ├─ GameBoardView.swift           # テトリス盤面描画
│  ├─ CameraPreview.swift           # カメラプレビュー
│  ├─ Grid4x3Overlay.swift          # 4×3グリッド重ね表示
│  └─ OccupancyHeatmap.swift        # 占有率ヒートマップ
├─ Services/                        # 共通サービス
├─ Resources/                       # Assets, Localizations
└─ Config/                          # 設定・定数
   └─ Config.swift                  # 調整可能パラメータ定義
```

---

## 主要ファイルの詳細

### 🎯 **UnifiedGameView.swift** - **最重要統合画面**
**役割**: カメラ + ゲーム + UI を統合したメイン画面
- **レイアウト**: 垂直（上部25%カメラ、下部75%ゲーム）
- **責務**: 全体フロー制御、delegates統合、ROIフレーム計算
- **編集する場合**: UI レイアウト変更、新機能統合、フロー調整

### 🎮 **GameCore.swift** - **ゲームエンジン**
**役割**: テトリス盤面ロジック（10×20）
- **主要機能**: 衝突判定、ライン消去、ピース操作（移動・回転・キック）
- **編集する場合**: ゲームルール変更、新操作追加、スコアリング

### 📸 **CameraManager.swift** - **カメラ制御**
**役割**: AVFoundation を使用したカメラセッション管理
- **主要機能**: プレビュー表示、フレーム取得、権限管理
- **編集する場合**: カメラ設定変更、解像度調整、パフォーマンス最適化

### 🧠 **VisionProcessor.swift** - **画像認識**
**役割**: Vision フレームワークを使用した人物セグメンテーション
- **主要機能**: `VNGeneratePersonSegmentationRequest` 実行
- **編集する場合**: 認識精度向上、新しいVision機能追加

### ⚡ **QuantizationProcessor.swift** - **量子化エンジン**
**役割**: セグメンテーションマスク → 4×3グリッド変換
- **主要機能**: vImage縮約、閾値処理、ノイズ除去
- **編集する場合**: 量子化精度調整、適応閾値アルゴリズム改善

### 🔍 **ShapeExtractor.swift** - **形状抽出**
**役割**: 4×3グリッド → 最適ポリオミノ抽出（ビームサーチ）
- **主要機能**: 連結成分検出、候補生成、スコアリング
- **編集する場合**: 抽出アルゴリズム改善、新しい形状評価指標

---

## 機能追加ガイド

### 🎵 **オーディオ機能追加**
**編集対象**: `CountdownManager.swift`
- オーディオエンジン設定、音声生成ロジックが実装済み
- 新しい効果音追加、音楽再生機能を拡張可能

### 🎨 **新しいUI要素**
**編集対象**: `UnifiedGameView.swift`, `GameBoardView.swift`
- SwiftUI ベース、レスポンシブデザイン対応
- 新しいコンポーネントは `Views/` 以下に作成

### 🧮 **ゲームルール変更**
**編集対象**: `GameCore.swift`, `Config.swift`
- 盤面サイズ、難易度パラメータは `Config.swift` で調整
- ゲームロジックは `GameCore.swift` で変更

### 📊 **新しいデータ収集**
**編集対象**: `CaptureState.swift`, `ShapeHistoryManager.swift`
- テレメトリデータ構造追加
- 統計情報、分析機能拡張

### 🎯 **ヒント・ガイダンス機能**
**編集対象**: `Features/Hinting/` （未実装）
- Board-driven ターゲット生成
- ユーザー誘導UI

---

## 重要な設計パターン

### **MVVM アーキテクチャ**
- **Views**: SwiftUI コンポーネント（状態表示のみ）
- **ViewModels**: ビジネスロジック（最小限実装）
- **Models**: データ構造、ドメインロジック

### **Delegate パターン**
```swift
// 主要なdelegate関係
CameraManager → UnifiedGameView (フレーム配信)
VisionProcessor → UnifiedGameView (セグメンテーション結果)
CountdownManager → UnifiedGameView (カウントダウン制御)
GameCore ← UnifiedGameView (ピース提供)
```

### **フロー制御**
1. **カメラフレーム取得** → `CameraManager`
2. **Vision処理** → `VisionProcessor`
3. **量子化** → `QuantizationProcessor`
4. **形状抽出** → `ShapeExtractor`
5. **ゲーム統合** → `GameCore`

---

## 開発時の注意点

### **パフォーマンス**
- **Vision処理**: バックグラウンドキューで実行
- **UI更新**: メインキューで実行、60fps目標
- **メモリ管理**: CVPixelBuffer の適切な解放

### **テスト**
- **Unit Tests**: `human-tetrisTests/` （重要ロジックのみ）
- **精度テスト**: `CountdownPrecisionTests.swift` （±50ms精度）
- **実機テスト**: iPhone 12以降推奨

### **設定管理**
- **調整可能パラメータ**: `Config.swift` に集約
- **難易度設定**: Easy/Normal/Hard プリセット
- **実験的機能**: フィーチャーフラグで制御

### **デバッグ**
- **ログ出力**: print文で重要イベント記録
- **ROIフレーム**: 開発時は可視化オーバーレイ使用
- **シミュレータ**: テストピース生成機能利用

---

## 現在の実装状況

### ✅ **完了済み**
- カメラ→量子化→形状抽出→ゲーム統合パイプライン
- 10×20テトリス盤面、基本操作（移動・回転・キック）
- 3秒カウントダウン、オーディオフィードバック
- 垂直レイアウトUI（上部カメラ25%、下部ゲーム75%）
- 形状多様性管理、同形判定

### 🚧 **部分実装**
- パフォーマンス最適化（30fps目標）
- エラーハンドリング、フォールバック機能

### ❌ **未実装**
- Board-driven ヒント生成 (`Features/Hinting/`)
- SpriteKit エフェクト統合
- 設定画面（難易度・プライバシー）
- テレメトリ送信機能

---

## 次の開発者へのメッセージ

このプロジェクトは **リアルタイム画像処理** と **ゲーム体験** の融合を目指しています。特に `UnifiedGameView.swift` が全体のフローを制御する中心となっているため、新機能追加時はここから始めることをお勧めします。

**パフォーマンスとユーザー体験** のバランスが重要で、iPhone実機での動作確認を頻繁に行ってください。Vision処理は重い処理なので、バックグラウンド処理とUI応答性の両立に注意が必要です。

コードベースは比較的新しく、Swift 6 対応や新しいVision機能の活用余地が多くあります。楽しんで開発してください！

---

**最終更新**: 2025-08-16  
**対応iOS**: 18.0+  
**主要依存**: AVFoundation, Vision, SwiftUI, SwiftData