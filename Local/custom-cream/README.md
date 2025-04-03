# Firebase Admin 権限付与スクリプト

この Node.js スクリプトは、Firebase Authentication に登録されているユーザーに対して、`admin` カスタムクレームを付与するためのツールです。管理者権限を持つユーザーを認証ロジックなどで区別する際に役立ちます。

## 🔧 前提条件

- Node.js がインストールされていること
- Firebase プロジェクトが存在していること
- Firebase Admin SDK のサービスアカウントキーを取得済みであること

## 📦 インストール

1. プロジェクトディレクトリを作成し、必要なモジュールをインストールします：

```bash
mkdir firebase-admin-script
cd firebase-admin-script
npm init -y
npm install firebase-admin readline
