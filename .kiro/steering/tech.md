# 技術スタック・ビルドシステム

## 核となる技術

- **言語**: Swift 5.x
- **プラットフォーム**: iOS 18.0+（30fps推奨：iPhone 12+、60fps目標：iPhone 15+）
- **UIフレームワーク**: MVVMアーキテクチャを伴うSwiftUI
- **コンピュータビジョン**: Visionフレームワーク（人物セグメンテーション、ポーズ検出）
- **カメラ**: AVFoundation（AVCaptureVideoDataOutput）
- **データ永続化**: スコア保存用SwiftData
- **画像処理**: 量子化とモルフォロジー演算用Accelerate/vImage

## 依存関係

- **Inject** (1.5.2): 開発用ホットリロード（Swift Package Manager経由）

## アーキテクチャパターン

- **MVVM**: ViewModelが状態管理、ViewがUI処理
- **プロトコル指向**: ピース生成用`GamePieceProvider`プロトコル
- **機能ベース構造**: ドメイン別組織化（Capture、Game、Render）
- **非同期処理**: Vision処理用バックグラウンドキュー、UI更新用メインキュー

## 主要パフォーマンス要件

- **フレームレート**: 最低30fps、目標60fps
- **認識遅延**: 中央値≤250ms（ポーズ捕捉からピース確定まで）
- **解像度**: Vision処理用256-320px短辺
- **メモリ**: オンデバイスのみ、画像保存なし

## ビルドコマンド

```bash
# Xcodeでプロジェクトを開く
open human-tetris.xcodeproj

# シミュレータ用ビルド
xcodebuild -project human-tetris.xcodeproj \
  -scheme human-tetris \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  build

# テスト実行
xcodebuild test -project human-tetris.xcodeproj \
  -scheme human-tetris \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'

# ビルドフォルダクリーン
xcodebuild clean -project human-tetris.xcodeproj
```

## 開発環境セットアップ

- **Xcode**: 16.4+必須
- **iOS配布ターゲット**: 18.0
- **Swift Package Manager**: 依存関係管理に使用
- **ホットリロード**: 高速反復のためInjectフレームワーク有効