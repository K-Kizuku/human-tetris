# CLAUDE.md

このファイルは **Claude Code** が本リポジトリで作業する際の「プロジェクト専用ガイド／ガードレール」です。  
**以降、Claude とのやりとり・説明・出力は必ず日本語**で行ってください（コード中の識別子・ファイル名・コミットメッセージは英語推奨）。

- 参照仕様: `./specification.md`（**差異がある場合は仕様書を優先**）
- 本ドキュメントは仕様の**抜粋＋実装規約**です。定義値・API 方針はここを唯一の真実源として更新してください。

---

## 0. 言語ポリシー（最優先）

- **日本語**：設計説明、実装方針、レビューコメント、PR 本文、エラーレポート、要約。
- **英語**：コード識別子（型／関数／変数／ファイル名）、ドキュメンテーションコメント、コミット（推奨）。
- **YOU MUST**：Claude は出力前に「要約（日本語）」→「変更点」→「理由」を提示。
- **NEVER**：英語での長文説明をデフォルトにしない（依頼時のみ可）。

---

## 1. 環境（Environment）

- **Platform / Target**: iOS **18.6**（Deployment Target: **iOS 18.0**）
- **Xcode**: **16.4**
- **Swift**: **5.x**（Swift 6 機能の使用は別タスク合意後）
- **Primary Simulator**: **iPhone 16 / iOS 18.6**
- **UI**: **SwiftUI**（必要時のみ UIKit）
- **Persistence**: **SwiftData**（Core Data 不使用）
- **Dependencies**: Swift Package Manager（現状 外部依存なし）
- **主要フレームワーク**: **AVFoundation / Vision / Accelerate(vImage) / SpriteKit**（または SwiftUI Canvas）

> **YOU MUST**: モダン API（Swift Concurrency 等）を優先。**非推奨 API は使用禁止**。  
> **NEVER**: 秘密情報（鍵・トークン）をソースに保存しない。

---

## 2. プロジェクト概要

- アプリ名: **human-tetris**（MVP：2D）
- 目的: ポーズ → 量子化 → ポリオミノ化 → 落下・消去の**イベント向け即盛り上がり体験**
- ゲーム盤: **10×20**
- ピース: **3〜6 セル**の連結集合（可変ポリオミノ）
- 仕様の核は `./specification.md` を参照（**常に同期**）

---

## 3. ディレクトリ構成（推奨）

```

human-tetris/
├─ human-tetris/
│  ├─ App/                 # エントリポイント, App-level DI
│  │  └─ HumanTetrisApp.swift
│  ├─ Features/
│  │  ├─ Capture/          # AVFoundation/Vision/vImage パイプライン
│  │  ├─ Game/             # 盤面・衝突・ライン消去・操作
│  │  ├─ Hinting/          # Board-driven ヒント生成（TargetSpec）
│  │  └─ Render/           # SpriteKit（推奨）/ SwiftUI Canvas
│  ├─ Models/              # SwiftData @Model, ゲームドメイン型
│  ├─ ViewModels/          # MVVM VM
│  ├─ Views/               # SwiftUI 画面
│  ├─ Services/            # Repository/設定/テレメトリ等
│  ├─ Resources/           # Assets / Localizations
│  ├─ Config/              # 調整可能パラメータ定義（Config.swift）
│  └─ Info.plist           # **AIは直接編集しない**
├─ human-tetrisTests/      # Unit / Swift Testing
└─ human-tetrisUITests/    # UI Tests (XCUITest)

```

**アーキテクチャ**: **MVVM** を基本。`Views -> ViewModels -> Services/Repositories -> Models` の一方向。  
**YOU MUST**: 量子化・探索・スコア式は**純ロジック**として分離し、Swift Testing でテスト可能にする。

---

## 4. 実装規約 — Capture/認識/量子化

- **Pipeline**: `AVCaptureVideoDataOutput` → (BG) `Vision`
  - 人物セグ: `VNGeneratePersonSegmentationRequest`（中品質・fps 優先）
  - 骨格補助: `VNDetectHumanBodyPoseRequest`（妥当性/チート抑止）
- **量子化**（ROI 3×4）:
  - vImage でマスクを **3×4 平均縮約** → セル **占有率 0..1**
  - 閾値 `θ` により ON/OFF（初期 `θ=0.45`、適応レンジ `0.35..0.55`）
  - 小連結成分除去＆モルフォロジでノイズ低減
- **候補抽出**（3..6 連結, 4 近傍）: **ビームサーチ**（幅 8..12, 早期枝刈り）
- **初期列決定**: ON セルの **重心 X ∈[0,1]** → 盤列 0..9 へ線形マップ
- **確定条件（MVP）**: `IoU >= 0.60` かつ `安定時間 >= 0.40s`

**提供関数（純ロジック）**（Claude はこの API を優先して実装/利用）:

```swift
struct Grid3x4 { var on: [[Bool]] } // 3 rows x 4 cols

func quantize(mask: CVPixelBuffer, roi: CGRect, threshold: Float) -> Grid3x4

struct Polyomino {
    let cells: [(x: Int, y: Int)] // 3..6 連結
    let rot: Int
    var size: Int { cells.count }
}

func bestConnectedSubset(from grid: Grid3x4) -> Polyomino?
func spawnColumn(for grid: Grid3x4) -> Int // 重心X→0..9
```

---

## 5. 実装規約 — ゲームルール/操作/スコア

- **盤**: 10×20、**自動落下**、接地でロック、**同時ライン消去可**
- **操作**: 左右移動（ボタン/スワイプ）、回転（時計回り／長押しで反時計回りオプション）、一時停止/再開/リトライ
- **ピース順**: **ユーザーポーズ駆動**。候補のうち**スコア最大**を採用（同点のみランダム TB）
- **スコア（確定後）**: `gameScore = α*linesBonus + β*IoU + γ*stable + δ*diversityIndex`

  - 初期: `α=4, β=10, γ=3, δ=5`（詳細は仕様 §25.2）

- **多様性/抑制**: **形状多様性ボーナス**、**シェイプ・クールダウン**、**ミッション（任意 ON）** を実装（仕様 §27–29）

**YOU MUST**: 盤面ロジック（衝突/回転/キック/消去）は `GameCore` に集約。
**NEVER**: View にビジネスロジックを持たせない。

---

## 6. ヒント生成（Board-driven Targeting）

- **目的**: 任意ポーズを尊重しつつ、盤面に有益＝**やさしい誘導**
- **TargetSpec**:

```swift
struct TargetSpec {
    var k: Int                  // 3..6
    enum Aspect { case slender, wide, balanced }
    var aspect: Aspect
    enum Convexity { case none, left, right, center }
    var convexity: Convexity
    var rot: Int                // 0..3
    var centroidX: Int          // 0..9
}
```

- **決定**: 盤面特徴/多様性/クールダウン/ミッションで TargetSpec 群をスコア → 上位採用
- **検出統合**: スコア式の `w4*TargetSpec一致` を付加（仕様 §8.1 / §25.1）

**UI**: 3×4 ゴースト表示、短文ヒント（骨格差分）、`match=α*IoU+β*関節一致度` バー。

---

## 7. レンダリング/アニメーション

- **描画**: SpriteKit（推奨）/ SwiftUI Canvas。背景グリッド。カメラプレビューは下層、盤は上層。
- **落下**: **1 マス 200–350ms** イージング
- **接地/ロック**: 小バウンス
- **ライン消去**: 行発光 → 縮退 → 上詰め **300–450ms**
- **YOU MUST**: 60fps 目標（最低 30fps）。描画と推論はスレッド分離。

---

## 8. 設定（MVP 難易度）

- **Easy**: `θ=0.40`, `IoU>=0.55`, `安定>=0.30s`
- **Normal**: `θ=0.45`, `IoU>=0.60`, `安定>=0.40s`
- **Hard**: `θ=0.50`, `IoU>=0.70`, `安定>=0.50s`

**Config.swift（例）**:

```swift
enum Difficulty { case easy, normal, hard }

struct QuantizeConfig {
    var theta: Float
    var iou: Float
    var stableSec: Float
}

let QUANTIZE_PRESET: [Difficulty: QuantizeConfig] = [
    .easy:   .init(theta: 0.40, iou: 0.55, stableSec: 0.30),
    .normal: .init(theta: 0.45, iou: 0.60, stableSec: 0.40),
    .hard:   .init(theta: 0.50, iou: 0.70, stableSec: 0.50)
]
```

---

## 9. パフォーマンス/受け入れ基準（MVP）

- **端末**: iPhone 12 以降 **≥30fps**、iPhone 15 以降 **60fps 目標**
- **推論解像度**: 短辺 256–320（動的可変）
- **遅延**: **≤ 250ms（中央値）**（ポーズ → 確定）
- **堅牢性**: 明暗/屋内外で `IoU 0.60` 達成率 ≥80%
- **誤確定**: 無人 100 試行で 0 件
- **安定性**: 連続 15 分プレイでクラッシュなし

**Definition of Done（要約）**（詳細は仕様 §22）

- 指定端末でプレイ可、主要クラッシュ 0、プライバシ/安全 UI 完了、I 型対策が定量的に有効

---

## 10. セキュリティ/プライバシ/安全

- **オンデバイス**処理。画像/映像は**自動保存しない**（スクショのみ手動）
- **顔モザイク**（任意 ON）
- **権限**: 必要時のみ要求／利用目的を明示
- **安全注意**: 無理姿勢/障害物/写り込みへの警告表示
- **NEVER**: PII/秘匿情報のログ出力

---

## 11. テレメトリ（オフライン）

- 収集: 平均 IoU、平均安定時間、総ライン、プレイ時間、**多様性指数**（匿名・端末内のみ）
- 送信: MVP は**送信なし**。デバッグ可視化のみ

---

## 12. 開発ルール（Workflow）

- **Branch**: `feature/<summary>` → PR → `main`（**main 直 push 禁止**）
- **Commit**: 英語サマリ（imperative）。PR 本文は日本語で**変更概要・動機・スクショ・テスト結果**
- **TDD 推奨**: 新機能はテスト先行（Swift Testing）。失敗ケースから
- **CI（将来）**: Lint/Unit/UI を標準化（導入後は落ちたら修正 → 再実行が必須）
- **依存追加**: SPM のみ。採用理由・維持性を PR に明記
- **設計変更**: 公開 API/モデル変更は**影響範囲・移行手順**を提示して合意後に実装

**YOU MUST**: 変更後は **ビルド → テスト → 結果サマリ（日本語）** を自動で提示。
**NEVER**: `Info.plist`/署名/Entitlements を無断変更。

---

## 13. ビルド/実行/テスト（CLI）

```bash
# Build (Simulator: iPhone 16 / iOS 18.6)
xcodebuild -project human-tetris.xcodeproj \
  -scheme human-tetris \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  build

# Device Generic Build
xcodebuild -project human-tetris.xcodeproj \
  -scheme human-tetris \
  -destination 'generic/platform=iOS' \
  build

# Clean
xcodebuild -project human-tetris.xcodeproj -scheme human-tetris clean

# Run on Simulator
xcodebuild -project human-tetris.xcodeproj \
  -scheme human-tetris \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  install

# Unit (Swift Testing) / UI Tests
xcodebuild test -project human-tetris.xcodeproj \
  -scheme human-tetris \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'

xcodebuild test -project human-tetris.xcodeproj \
  -scheme human-tetris \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  -only-testing:human-tetrisUITests
```

---

## 14. 変更履歴

- 2025-08-16: `./specification.md` 反映。Capture/量子化/探索/ヒント/難易度/スコア/性能/DoD を追記。
- 2025-08-16: 日本語運用／iOS 18.6 前提ガードレールを確定。
