# DirectoryAssistantPy

A cross-platform local tool that opens a project folder as a browser-based file navigator — double-click to launch, no installation required.

## Features

- **Directory tree**: Hierarchical folder view in the sidebar with expand/collapse all and incremental search
- **Card view**: Grid layout with color-coded file types (PDF, Excel, Word, images)
- **Open with default app**: Double-click any file to open it in Excel, Word, or the OS default — the server never touches the file content
- **Reveal in file manager**: Right-click to open in Finder (macOS) / Explorer (Windows) / file manager (Linux)
- **Browser-like navigation**: Breadcrumb trail, back/forward buttons, full keyboard support (Alt+←→)
- **Auto-shutdown**: Server stops automatically 30 seconds after the browser tab is closed — no lingering background processes
- **Self-updating launcher**: Each launcher embeds the latest `DirectoryAssistant.py` and extracts it on startup
- **Local-only**: Binds to `127.0.0.1` only. No data sent anywhere. Checks GitHub Releases API on load to display the latest version — no credentials, no tracking

## Design philosophy

Placing the launcher in a folder *is* the act of declaring it a project.

Unlike a file server (which serves file content through the server), DirectoryAssistantPy only navigates — it tells you where files are, then steps aside so your OS opens them directly. This eliminates the need for permission management, conflict resolution, sessions, and uploads.

```
File server approach          DirectoryAssistantPy
─────────────────────         ────────────────────────
User → Server → File          User → Browser → find file
Server reads & sends            ↓
Browser shows/DL              Double-click
(permissions, locks,          OS opens file directly
 sessions required)           (Excel opens in Excel)
```

## Getting started

1. Copy the launcher for your OS into the project folder
2. Double-click to launch
3. The browser opens automatically at `http://localhost:8742`

| OS | Launcher |
|----|----------|
| Windows | `DirectoryAssistantPy.bat` |
| macOS | `DirectoryAssistantPy.command` |
| Linux | `DirectoryAssistantPy.sh` |

## What this tool does NOT do

By design:

- Create, move, rename, or delete files
- Serve files over a network to other devices
- Preview file contents in the browser
- Sync with cloud storage
- Manage user authentication or access control

File editing stays in Excel, Word, and your usual apps. This tool handles only navigation.

## Requirements

- Python 3 (any recent version)
- If Python is not installed, the launcher automatically opens a local install guide (`PythonInstallGuide.html`)

## Manual

See [Manual/DirectoryAssistantPy.html](Manual/DirectoryAssistantPy.html) for the full user guide (Japanese / English).

## Support

If this tool is helpful for your work, you can support the development here:
https://paypal.me/rawslnc

## License

This tool is distributed under the GNU General Public License v3 or later.
See [LICENSE](LICENSE) for details.

## Author

Copyright (C) 2026 Hideharu Masai

---

# DirectoryAssistantPy（日本語）

現場のフォルダをブラウザで開くローカルツールです。ダブルクリック一発で起動し、インストール不要です。

## 機能

- **ディレクトリツリー**: サイドバーで階層表示・全展開・全閉じ・インクリメンタル検索
- **カードビュー**: PDF・Excel・Word・画像を種類ごとに色分けしてグリッド表示
- **デフォルトアプリで開く**: ダブルクリックで OS のデフォルトアプリが起動。Excel は Excel で開く。サーバーはファイルの中身に一切触れない
- **ファイルマネージャーで表示**: 右クリックから Finder（macOS）・Explorer（Windows）・ファイルマネージャー（Linux）で表示
- **ブラウザライクなナビゲーション**: パンくずリスト・前後ボタン・キーボード操作（Alt+←→）
- **自動終了**: ブラウザタブを閉じると 30 秒後にサーバーが自動終了。プロセスが残り続けない
- **自動更新**: ランチャーが最新の本体（`DirectoryAssistant.py`）を内包し、起動時に自動展開
- **ローカル完結**: `127.0.0.1` のみにバインド。外部へのデータ送信ゼロ。最新バージョン表示のため GitHub Releases API を参照（認証・追跡なし）

## 設計思想

ランチャーをフォルダに置く行為が、そのまま「このフォルダをプロジェクトと宣言する」行為になっています。

ファイルサーバーはファイルをサーバー経由で配信しますが、このツールはファイルの場所を案内するだけです。権限管理・同時編集の衝突・セッション管理・アップロード処理がすべて不要になります。

## 使い方

1. OS に合ったランチャーを現場フォルダに置く
2. ダブルクリックで起動
3. ブラウザが自動で `http://localhost:8742` を開く

| OS | ランチャー |
|----|----------|
| Windows | `DirectoryAssistantPy.bat` |
| macOS | `DirectoryAssistantPy.command` |
| Linux | `DirectoryAssistantPy.sh` |

## アップデート方法

新しいリリースが公開された場合は、古いランチャーを削除し、最新版に置き換えてください。

1. 現場フォルダ内の旧ランチャー（`.bat` / `.command` / `.sh`）を削除
2. [GitHub リリースページ](https://github.com/raw-slnc/directory_assistant_py/releases)から最新のランチャーをダウンロード
3. 現場フォルダに置いてダブルクリック → 本体（`DirectoryAssistant.py`）が自動で最新版に更新されます

> 複数のフォルダにランチャーを置いている場合は、それぞれ置き換えてください。

## できないこと（設計上）

- ファイルの作成・移動・名前変更・削除
- ネットワーク越しの別端末からのアクセス
- ブラウザ内でのファイル内容プレビュー
- クラウド同期
- ユーザー認証・アクセス制限

ファイルの編集は Excel・Word などの慣れたアプリで行います。このツールは「探して開く」だけを担当します。

## 動作環境

- Python 3（バージョンは問いません）
- Python 未導入の場合、ランチャーがインストールガイド（`PythonInstallGuide.html`）を自動で開きます

## マニュアル

詳細なユーザーガイドは [Manual/DirectoryAssistantPy.html](Manual/DirectoryAssistantPy.html) をご覧ください（日本語・英語対応）。

## サポート

このツールがお役に立てた場合、開発のサポートをお願いできると励みになります：
https://paypal.me/rawslnc

## ライセンス

GNU General Public License v3 以降のもとで配布されます。
詳細は [LICENSE](LICENSE) をご覧ください。

## 作者

Copyright (C) 2026 Hideharu Masai
