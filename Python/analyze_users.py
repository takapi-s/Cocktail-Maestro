from datetime import datetime, timezone
import firebase_admin
from firebase_admin import credentials, firestore

# Firebase 初期化（サービスアカウントキーのパスを指定）
cred = credentials.Certificate("e-business-6330a-firebase-adminsdk-a70xb-0d705a30e0.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# 現在時刻（UTC）
now = datetime.now(timezone.utc).isoformat()

# 分析対象ユーザーを最大100件取得（lastAnalyzedAtが古い順、または存在しないもの含む）
users_ref = db.collection("users")
query = users_ref.order_by("lastAnalyzedAt", direction=firestore.Query.ASCENDING).limit(100)
users = query.stream()
users = list(query.stream())

print(f"取得ユーザー数: {len(users)}")

for user in users:
    uid = user.id
    print(f"[分析開始] User: {uid}")

    # 分析処理があればここに挿入
    print(f"  [分析完了] User: {uid}")

    # lastAnalyzedAt を現在時刻に更新
    users_ref.document(uid).update({
        "lastAnalyzedAt": now
    })

print("✅ 全ユーザーの分析完了")
