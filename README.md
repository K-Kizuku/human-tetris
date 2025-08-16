# Human Tetris

人間のポーズをテトリスピースに変換するiOSアプリケーション

## 概要

Human Tetrisは、カメラで人間のポーズを認識し、リアルタイムで3×4グリッドに量子化してテトリスピース（3-6セル）を生成するゲームです。AVFoundationとVision Frameworkを使用したオンデバイス処理により、プライバシーを保護しながら楽しい体験を提供します。

## 主要機能

### ✅ 実装済み機能

- **カメラ認識システム**
  - AVFoundationによるリアルタイムカメラプレビュー
  - Vision Frameworkによる人物セグメンテーション
  - 3×4グリッドへの量子化処理
  - ビームサーチによる最適形状探索

- **ゲームシステム**
  - 10×20の2Dテトリス盤面
  - 左右移動・回転・落下操作
  - ライン消去とスコア計算
  - ゲームオーバー判定

- **ユーザーインターフェース**
  - SwiftUIベースのモダンUI
  - リアルタイム占有率ヒートマップ
  - IoU・安定性バー表示
  - 直感的な操作ボタン

- **設定・プライバシー**
  - 難易度選択（Easy/Normal/Hard）
  - オンデバイス処理でプライバシー保護
  - 顔モザイク機能（オプション）
  - SwiftDataによるスコア保存

### 🚧 未実装機能（追加開発可能）

- SpriteKit統合によるリッチなアニメーション
- 形状多様性ボーナス・重複ペナルティシステム
- I型スパム防止機能
- Board-drivenターゲット生成・ヒントシステム

## 技術スタック

- **言語**: Swift 5.x
- **フレームワーク**: SwiftUI, AVFoundation, Vision, Accelerate
- **データ永続化**: SwiftData
- **最小対応バージョン**: iOS 18.0+
- **推奨端末**: iPhone 12以降

## アーキテクチャ

```
human-tetris/
├─ App/                 # エントリポイント
├─ Features/
│  ├─ Capture/          # カメラ・認識・量子化
│  ├─ Game/             # ゲームロジック
│  └─ Render/           # 描画システム
├─ Models/              # データモデル
├─ ViewModels/          # MVVM ViewModel
├─ Views/               # SwiftUI画面
├─ Services/            # 共通サービス
└─ Config/              # 設定パラメータ
```

## パフォーマンス仕様

- **フレームレート**: 30fps以上（iPhone 12+）、60fps目標（iPhone 15+）
- **認識遅延**: ≤250ms（中央値）
- **精度**: IoU 0.60達成率 ≥80%
- **安定性**: 連続15分プレイでクラッシュなし

## 使用方法

1. アプリを起動し、「ゲームスタート」をタップ
2. カメラ許可を与える
3. 3×4の枠内でポーズを取る
4. IoU・安定性が閾値を満たすとピース確定
5. 左右・回転ボタンでピースを操作
6. ラインを揃えて高スコアを目指す

## 安全に関する注意

- 無理なポーズは避けてください
- 周囲の障害物に注意してください
- 体調や服装にご配慮ください
- 第三者の写り込みにご配慮ください

## ビルド方法

```bash
# プロジェクトをクローン
git clone <repository-url>
cd human-tetris

# Xcode 16.4以降でプロジェクトを開く
open human-tetris.xcodeproj

# iPhone 16シミュレータでビルド
xcodebuild -project human-tetris.xcodeproj \
  -scheme human-tetris \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  build
```

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。

## 開発者

Created during hackathon development session - August 2025
