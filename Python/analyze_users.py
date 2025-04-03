from datetime import datetime, timedelta, timezone
import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict

# --- Firebase 初期化 ---
cred = credentials.Certificate("e-business-6330a-firebase-adminsdk-a70xb-0d705a30e0.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# --- パラメータ ---
now = datetime.now(timezone.utc)

# --- ユーザー取得 ---
users_ref = db.collection("users")
query = users_ref.order_by("lastAnalyzedAt", direction=firestore.Query.ASCENDING).limit(100)
users = list(query.stream())

print(f"取得ユーザー数: {len(users)}")

for user in users:
    uid = user.id
    print(f"[分析開始] User: {uid}")
    cutoff = user.to_dict().get("lastAnalyzedAt")
    # 分析対象期間（日数）を算出
    analyzed_days = (now - cutoff).days


    rated_ref = users_ref.document(uid).collection("ratedRecipes")
    rated_docs = list(rated_ref.stream())

    # --- タグ統計用辞書 ---
    tag_stats = defaultdict(lambda: {"count": 0, "ratingSum": 0})

    for rated in rated_docs:
        data = rated.to_dict()
        ts = data.get("timestamp")
        rating = data.get("rating")
        if not (ts and rating):
            continue

        # Firestore の timestamp を datetime に変換
        rated_time = ts if isinstance(ts, datetime) else datetime.fromisoformat(ts)

        if rated_time < cutoff:
            continue

        # 該当レシピの tags を取得
        recipe_id = rated.id
        recipe_ref = db.collection("recipes").document(recipe_id)
        recipe_doc = recipe_ref.get()
        if not recipe_doc.exists:
            continue

        recipe_data = recipe_doc.to_dict()
        tags = recipe_data.get("tags", [])
        for tag in tags:
            tag_stats[tag]["count"] += 1
            tag_stats[tag]["ratingSum"] += rating

    # 平均を追加
    for tag in tag_stats:
        stats = tag_stats[tag]
        stats["ratingAvg"] = stats["ratingSum"] / stats["count"] if stats["count"] > 0 else 0.0

    # --- 保存 ---
    analysis_ref = users_ref.document(uid).collection("analysis")
    analysis_ref.add({
        "uploadedAt": now.isoformat(),
        "days": analyzed_days,
        "tagStats": tag_stats
    })

    # lastAnalyzedAt 更新
    users_ref.document(uid).update({"lastAnalyzedAt": now.isoformat()})

    print(f"[分析完了] User: {uid}")

print("✅ 全ユーザーの分析完了")
