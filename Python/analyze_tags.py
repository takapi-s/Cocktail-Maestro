from datetime import datetime, timedelta, timezone
import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict
import statistics

# Firebase 初期化
cred = credentials.Certificate("e-business-6330a-firebase-adminsdk-a70xb-0d705a30e0.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

now = datetime.now(timezone.utc)
days = 7  # 分析対象日数
cutoff = now - timedelta(days=days)

# ---------- 1. タグごとの評価傾向分析 ----------
print("🧠 タグごとの評価傾向分析を開始")

recipes_ref = db.collection("recipes")
recipes = list(recipes_ref.stream())

tag_ratings = defaultdict(list)

for recipe in recipes:
    data = recipe.to_dict()
    tags = data.get("tags", [])
    rating = data.get("ratingAverage")
    if rating is None:
        continue
    for tag in tags:
        tag_ratings[tag].append(rating)

tag_rating_stats = {}
for tag, ratings in tag_ratings.items():
    tag_rating_stats[tag] = {
        "count": len(ratings),
        "ratingSum": sum(ratings),
        "ratingAvg": sum(ratings) / len(ratings),
        "ratingMedian": statistics.median(ratings)
    }

db.collection("tagAnalysis").document("ratingStats").collection("entries").add({
    "uploadedAt": now.isoformat(),
    "days": days,
    "tags": tag_rating_stats
})
print("✅ 評価傾向保存完了")

# ---------- 2. タグランキング ----------
print("🏆 タグランキング集計を開始")

users = db.collection("users").stream()
tag_popularity = defaultdict(lambda: {"count": 0, "ratingSum": 0})

for user in users:
    uid = user.id
    rated_ref = db.collection("users").document(uid).collection("ratedRecipes")
    for doc in rated_ref.stream():
        data = doc.to_dict()
        ts = data.get("timestamp")
        rating = data.get("rating")
        if not (ts and rating):
            continue
        rated_time = ts if isinstance(ts, datetime) else datetime.fromisoformat(ts)
        if rated_time < cutoff:
            continue

        recipe_id = doc.id
        recipe_doc = db.collection("recipes").document(recipe_id).get()
        if not recipe_doc.exists:
            continue
        tags = recipe_doc.to_dict().get("tags", [])
        for tag in tags:
            tag_popularity[tag]["count"] += 1
            tag_popularity[tag]["ratingSum"] += rating

# 平均計算
for tag in tag_popularity:
    count = tag_popularity[tag]["count"]
    tag_popularity[tag]["ratingAvg"] = tag_popularity[tag]["ratingSum"] / count if count else 0

db.collection("tagAnalysis").document("popularityStats").collection("entries").add({
    "uploadedAt": now.isoformat(),
    "days": days,
    "tags": tag_popularity
})
print("✅ タグランキング保存完了")
