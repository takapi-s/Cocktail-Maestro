# Firebase User & Tag Analysis Scripts

このリポジトリには、Firebase Firestore 上のカクテルレシピアプリのユーザー評価データを分析するためのスクリプトが含まれています。

## 📁 概要

2つのPythonスクリプトにより、以下のような分析を行います：

### 1. `analysis_users.py`

- 1日ごとに実行される
- 各ユーザーごとに前回の更新以降のデータを取得評価を取得
- レシピのタグごとに、評価回数、合計評価、平均評価を計算
- 結果を `users/{uid}/analysis` に保存
- 処理後に `lastAnalyzedAt` フィールドを更新

### 2. `analysis_tags.py`

- 1週間ごとに実行される
- 全体のレシピを対象にタグごとの評価傾向（平均・中央値）を算出
- 全ユーザーの評価履歴からタグごとの人気度（評価回数・平均評価）を集計
- 結果を `tagAnalysis/ratingStats/entries` および `tagAnalysis/popularityStats/entries` に保存

---

## 📦 依存関係

- Python 3.7+
- Firebase Admin SDK
- `google-cloud-firestore`

### インストール方法

```bash
pip install firebase-admin google-cloud-firestore
