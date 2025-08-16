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
- **量子化**（ROI 4×3）:
  - vImage でマスクを **4×3 平均縮約** → セル **占有率 0..1**（縦4マス、横3マス）
  - 閾値 `θ` により ON/OFF（初期 `θ=0.45`、適応レンジ `0.35..0.55`）
  - 小連結成分除去＆モルフォロジでノイズ低減
- **候補抽出**（3..6 連結, 4 近傍）: **ビームサーチ**（幅 8..12, 早期枝刈り）
- **初期列決定**: ON セルの **重心 X ∈[0,1]** → 盤列 0..9 へ線形マップ
- **確定条件（MVP）**: `IoU >= 0.60` かつ `安定時間 >= 0.40s`

**提供関数（純ロジック）**（Claude はこの API を優先して実装/利用）:

```swift
struct Grid4x3 { var on: [[Bool]] } // 4 rows x 3 cols

func quantize(mask: CVPixelBuffer, roi: CGRect, threshold: Float) -> Grid4x3

struct Polyomino {
    let cells: [(x: Int, y: Int)] // 3..6 連結
    let rot: Int
    var size: Int { cells.count }
}

func bestConnectedSubset(from grid: Grid4x3) -> Polyomino?
func spawnColumn(for grid: Grid4x3) -> Int // 重心X→0..9

// 連続ゲームループ用プロトコル
protocol GamePieceProvider {
    func requestNextPiece(completion: @escaping (Polyomino?) -> Void)
    func isAvailable() -> Bool
}

class PieceQueue: ObservableObject {
    func setProvider(_ provider: GamePieceProvider)
    func getNextPiece(completion: @escaping (Polyomino?) -> Void)
    func preloadPieces() // 非同期実行
}
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

**UI**: 4×3 ゴースト表示、短文ヒント（骨格差分）、`match=α*IoU+β*関節一致度` バー。

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

**重要な実装ノート**:

- **非同期処理**：UI フリーズを防ぐため、重い処理は `DispatchQueue.global()` でバックグラウンド実行。
- **デッドロック防止**：同期的な while ループやメインスレッドブロックを防ぐ。
- **GamePieceProvider**：連続ゲームループのために必須。CaptureView が実装し GameCore が使用。

### 12.1 外部検索（Gemini Search）

**目的**  
Web 検索が必要な場面では、**組み込みの `Web_Search` ツールは使用せず**、Google Gemini CLI（コマンド名: `gemini`）を **Task Tool 経由**で必ず使用します。

**ポリシー**

- **YOU MUST**: Web 検索が必要なときは **常に `gemini --prompt` を Task Tool 経由で実行**すること。
- **NEVER**: 組み込みの `Web_Search` を使わない。`gemini` が使えない場合は **理由を日本語で報告**し、指示があるまで代替手段に自動で切り替えない。

**呼び出し規則（Task Tool 経由）**

- 実行形式:

```bash
gemini --prompt "WebSearch: <query>"
```

- 例:

```bash
gemini --prompt "WebSearch: Vision VNGeneratePersonSegmentationRequest iOS18 site:developer.apple.com"
gemini --prompt "WebSearch: SpriteKit line clear animation best practices"
gemini --prompt "WebSearch: SwiftData migration iOS18 since:2024-01-01"
```

**クエリ作法**

- **日本語でまず検索**し、必要に応じて **英語クエリも追加**（2 本投げ可）。
- サイト指定: `site:developer.apple.com`, `site:docs.swift.org`, `site:swift.org`, `site:developer.apple.com/videos` など。
- 時間指定が必要な場合は、CLI の仕様に従って `since:` などの修飾を付加。
- プライバシー: **個人情報や秘密情報をクエリに含めない**。

**結果の取り扱い（出力フォーマット）**

- まず **日本語で 3〜5 行の要約**を提示。
- 続けて **参考リンクの箇条書き**（_タイトル — 出典 — URL — （判明すれば）公開日_）。
- コード引用は **25 行未満**に留める。必要があれば要約＋要点抜粋に切り替える。

**障害時の扱い**

- `gemini` が見つからない／非ゼロ終了／認証エラー等 →

  1. **エラー内容を日本語で報告**
  2. 必要な対処（インストール/認証/再実行手順）を簡潔に提示
  3. **自動で `Web_Search` にフォールバックしない**（指示待ち）

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
- 2025-08-16: **連続ゲームループ実装完了** - GamePieceProvider プロトコルと PieceQueue システムによる自動ピース生成。
- 2025-08-16: **UI フリーズ問題解決** - 非同期処理による setPieceProvider デッドロックの修正。
- 2025-08-16: **4×3グリッド対応完了** - Grid3x4 → Grid4x3 への変更、ピース生成ロジック修正、アスペクト比制限緩和。
- 2025-08-16: **レスポンシブレイアウト実装完了** - GeometryReader による動的サイズ調整、全デバイス対応。

## 15. 実装完了済み機能（2025-08-16 現在）

✅ **基本システム**

- 10×20 盤面、衝突判定、ライン消去ロジック（GameCore.swift）
- 左右移動・回転操作・ウォールキック（GameCore.swift:132-156）
- 可変ポリオミノ（3-6 セル）対応（Polyomino.swift）

✅ **カメラ・認識システム**

- AVFoundation カメラプレビュー・フレーム取得（CameraManager.swift）
- Vision 人物セグメンテーション・骨格推定（VisionProcessor.swift）
- 3×4 量子化・連結成分抽出（QuantizationProcessor.swift, ShapeExtractor.swift）

✅ **連続ゲームループ**

- GamePieceProvider プロトコル（GamePieceProvider.swift:10-13）
- PieceQueue 非同期事前生成・管理（GamePieceProvider.swift:16-91）
- CaptureView Provider 実装（CaptureView.swift:228-294）
- GameCore 自動次ピース要求（GameCore.swift:86-114）

✅ **UI/UX**

- メイン画面（CaptureView.swift:27-155）
- ゲーム画面（GameView.swift, GameBoardView.swift）
- IoU・安定時間バー、プログレス表示（CaptureView.swift:83-98）

✅ **重要なバグ修正**

- setPieceProvider デッドロック解決（非同期処理導入）
- UI フリーズ問題解決（DispatchQueue.global 使用）
- ProgressView 範囲外値エラー修正

🚧 **実装予定**

- 形状多様性ボーナス/重複ペナルティ
- シェイプクールダウン（I 型スパム防止）
- SpriteKit 統合による高度なアニメーション

```

```
