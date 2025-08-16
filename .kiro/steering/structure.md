# プロジェクト構造・組織化

## ルートディレクトリ構造

```
human-tetris/
├── App/                    # アプリケーションエントリポイント
│   └── HumanTetrisApp.swift
├── Features/               # 機能ベースモジュール
│   ├── Capture/           # カメラ・コンピュータビジョン
│   ├── Game/              # ゲームロジック・状態管理
│   ├── Hinting/           # AIヒント・ターゲット提案
│   └── Render/            # グラフィックス・アニメーション
├── Models/                # データモデル・ゲームエンティティ
├── ViewModels/            # MVVM ビューモデル
├── Views/                 # SwiftUIビュー・UIコンポーネント
├── Services/              # 共有サービス・ユーティリティ
├── Config/                # 設定・定数
└── Resources/             # アセット・ローカライゼーション
```

## 機能モジュール組織化

### Captureモジュール
- `CameraManager.swift`: AVFoundationカメラ処理
- `VisionProcessor.swift`: Visionフレームワーク統合
- `QuantizationProcessor.swift`: 4×3グリッド量子化
- `ShapeExtractor.swift`: 連結成分解析
- `CountdownManager.swift`: 3秒キャプチャカウントダウン

### Gameモジュール  
- `GameCore.swift`: 核となるゲームロジック・状態管理
- `ShapeHistoryManager.swift`: ピース多様性追跡

### Models
- `GameState.swift`: 盤面状態、スコア計算、ゲーム状況
- `Polyomino.swift`: 可変ピース表現（3-6セル）
- `Grid4x3.swift`: 量子化グリッド構造
- `TargetSpec.swift`: AIヒント仕様
- `GameScore.swift`: SwiftDataスコア永続化

## 命名規則

- **クラス**: PascalCase（`GameCore`、`CameraManager`）
- **プロパティ/メソッド**: camelCase（`currentPiece`、`spawnPiece`）
- **定数**: 型はPascalCase、インスタンスはcamelCase
- **プロトコル**: 説明的接尾辞付きPascalCase（`GamePieceProvider`）
- **列挙型**: PascalCaseで小文字ケース（`Difficulty.easy`）

## コード組織化原則

- **単一責任**: 各クラス/構造体は明確な目的を一つ持つ
- **プロトコル指向**: テスト可能性と柔軟性のためプロトコルを使用
- **機能分離**: 関連機能を機能モジュールにグループ化
- **非同期優先**: Vision用バックグラウンド処理、UI用メインキュー
- **設定駆動**: `Config.swift`での定数一元化

## ファイル配置ルール

- **ビュー**: SwiftUIビューは`Views/`ディレクトリ
- **ビジネスロジック**: 核となるゲームロジックは`Features/Game/`
- **コンピュータビジョン**: すべてのCVコードは`Features/Capture/`
- **データモデル**: 純粋なデータ構造は`Models/`
- **設定**: すべての定数と設定は`Config/`
- **テスト**: テストディレクトリでメイン構造をミラー