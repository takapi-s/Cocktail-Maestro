import { Hono } from 'hono'
import { getFirebaseAccessToken } from './getFirebaseAccessToken';

type Bindings = {
  SECRET_API_KEY: string
  GAS_ENDPOINT: string
  R2: R2Bucket
  FIREBASE_SERVICE_ACCOUNT: string; // ← これを追加
}

type GasUploadResponse = {
  url: string;
  fileId: string;
}

type FirebaseServiceAccount = {
  type: string;
  project_id: string;
  private_key_id: string;
  private_key: string;
  client_email: string;
  client_id: string;
  auth_uri: string;
  token_uri: string;
  auth_provider_x509_cert_url: string;
  client_x509_cert_url: string;
  universe_domain: string;
};


const app = new Hono<{ Bindings: Bindings }>()

app.post('/upload', async (c) => {
  const {newDocID, imageBase64, fileName, apiKey, recipeInfo } = await c.req.json();
  const GAS_ENDPOINT = c.env.GAS_ENDPOINT;
  const SECRET_API_KEY = c.env.SECRET_API_KEY;

  if (apiKey !== SECRET_API_KEY) {
    return c.json({ error: 'Unauthorized' }, 401);
  }

  // ========== 画像アップロード ==========
  const gasResponse = await fetch(GAS_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'upload',
      imageBase64,
      fileName,
      apiKey: SECRET_API_KEY,
    }),
  });

  const gasResult = await gasResponse.json();
  const { url, fileId } = gasResult as GasUploadResponse;

  // ========== index.json の更新 ==========
  let indexData: any[] = [];
  
  const indexObj = await c.env.R2.get('index.json');
  if (indexObj) {
    indexData = await indexObj.json<any[]>();
  }

  const ingredientsNames = recipeInfo.ingredients ?? [];
  const tags = recipeInfo.tags ?? [];
  const glass = recipeInfo.glass ?? '';

  indexData.push({
    key: newDocID,
    name: recipeInfo.name,
    ingredients: ingredientsNames,
    tags: tags, // 👈 タグ情報を保存
    glass: glass,
    fileId,
  });

  await c.env.R2.put('index.json', JSON.stringify(indexData, null, 2), {
    httpMetadata: { contentType: 'application/json' },
  });

  return c.json({
    message: 'Upload successful',
    fileId: fileId,
    recipeId: newDocID,
  });
});


app.get('/search', async (c) => {
  try {
    const query = c.req.query('q') || '';
    console.log('検索クエリ:', query);  // クエリ確認

    // 空白区切りで複数ワードに分割（全角スペースも考慮）
    const keywords = query
      .split(/\s+/)  // 半角スペースまたは連続スペース区切り
      .filter(Boolean)  // 空文字削除
      .map(word => word.toLowerCase());

    console.log('検索キーワード:', keywords);

    // R2からindex.json取得
    const obj = await c.env.R2.get('index.json');
    if (!obj) {
      console.error('index.json が R2 に存在しません');
      return c.json({ error: 'Index file not found' }, 404);
    }

    const text = await obj.text();
    console.log('index.json 読み込み成功:', text.substring(0, 100)); // 先頭100文字だけ出す

    const data = JSON.parse(text) as {
      key: string;
      name: string;
      ingredients: string[];
    }[];

    console.log('パース成功。データ件数:', data.length);

    // フィルタリング処理（AND検索）
    const result = data.filter(item => {
      const haystack = [
        item.name.toLowerCase(),
        ...item.ingredients.map(ing => ing.toLowerCase())
      ].join(' ');  // 検索対象の文字列

      // すべてのキーワードが含まれているか (AND検索)
      return keywords.every(keyword => haystack.includes(keyword));
    });

    console.log('検索結果件数:', result.length);

    return c.json(result);

  } catch (error) {
    console.error('API 実行中にエラー:', error);
    return c.json({ error: 'Internal Server Error', detail: String(error) }, 500);
  }
});

app.post('/delete', async (c) => {
  const { recipeId, apiKey, fileId } = await c.req.json();

  const SECRET_API_KEY = c.env.SECRET_API_KEY;
  const GAS_ENDPOINT = c.env.GAS_ENDPOINT;

  if (apiKey !== SECRET_API_KEY) {
    return c.json({ error: 'Unauthorized' }, 401);
  }

  // ======================
  // 1. index.json 読み込み
  // ======================
  let indexData: any[] = [];
  const indexObj = await c.env.R2.get('index.json');
  if (indexObj) {
    indexData = await indexObj.json<any[]>();
  } else {
    return c.json({ error: 'Index file not found' }, 404);
  }

  // ======================
  // 2. レシピ情報取得と除外
  // ======================
  const targetRecipe = indexData.find(item => item.key === recipeId);
  if (!targetRecipe) {
    return c.json({ error: 'Recipe not found' }, 404);
  }

  const updatedIndexData = indexData.filter(item => item.key !== recipeId);

  // ======================
  // 3. index.json 上書き
  // ======================
  await c.env.R2.put('index.json', JSON.stringify(updatedIndexData, null, 2), {
    httpMetadata: { contentType: 'application/json' },
  });

  // ======================
  // 4. GASへ画像削除依頼
  // ======================
  const gasResponse = await fetch(GAS_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'delete',
      fileId: targetRecipe.fileId ?? fileId, // 🔧 両方対応
      apiKey: SECRET_API_KEY,
    }),
  });

  const gasResult = await gasResponse.json();

  return c.json({
    message: 'Delete successful',
    gasResult,
  });
});

app.post('/edit', async (c) => {
  const { recipeId, apiKey, recipeInfo = {}, imageBase64, fileName } = await c.req.json();

  const { SECRET_API_KEY, GAS_ENDPOINT, R2 } = c.env;

  // ======== Step 1: 認証チェック ========
  if (apiKey !== SECRET_API_KEY) {
    console.log('[認証エラー] APIキーが一致しません');
    return c.json({ error: 'Unauthorized' }, 401);
  }

  console.log('[受信] recipeId:', recipeId);
  console.log('[受信] recipeInfo:', recipeInfo);

  // ======== Step 2: index.jsonの取得 ========
  const indexObj = await R2.get('index.json');
  if (!indexObj) {
    console.log('[エラー] index.json が見つかりません');
    return c.json({ error: 'Index file not found' }, 404);
  }

  const indexData = await indexObj.json<any[]>();
  const targetIndex = indexData.findIndex(item => item.key === recipeId);
  if (targetIndex === -1) {
    console.log(`[エラー] 該当レシピが見つかりません: ${recipeId}`);
    return c.json({ error: 'Recipe not found' }, 404);
  }

  // ======== Step 3: 値の抽出（安全に） ========
  const {
    name = '',
    ingredients = [],
    tags = [],
    glass = '',
  } = recipeInfo;

  console.log('[解析] name:', name);
  console.log('[解析] ingredients:', ingredients);
  console.log('[解析] tags:', tags);
  console.log('[解析] glass:', glass);

  let newFileId = indexData[targetIndex].fileId;

  // ======== Step 4: 画像アップロード（任意） ========
  if (imageBase64 && fileName) {
    console.log('[処理] 画像アップロード開始:', fileName);
    const uploadPayload = {
      action: 'upload',
      imageBase64,
      fileName,
      apiKey: SECRET_API_KEY,
    };

    const uploadRes = await fetch(GAS_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(uploadPayload),
    });

    const uploadResult = await uploadRes.json() as GasUploadResponse;
    newFileId = uploadResult.fileId;

    console.log('[アップロード完了] 新しい fileId:', newFileId);

    // 古い画像削除
    const oldFileId = indexData[targetIndex].fileId;
    console.log('[処理] 古い画像削除:', oldFileId);
    await fetch(GAS_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        action: 'delete',
        fileId: oldFileId,
        apiKey: SECRET_API_KEY,
      }),
    });
  }

  // ======== Step 5: indexData の上書き前ログ ========
  console.log('[更新前データ]', indexData[targetIndex]);

  // ======== Step 6: index.json 更新 ========
  indexData[targetIndex] = {
    ...indexData[targetIndex],
    name,
    ingredients: Array.isArray(ingredients) ? ingredients : [],
    tags: Array.isArray(tags) ? tags : [],
    glass: typeof glass === 'string' ? glass : '',
    fileId: newFileId,
  };

  console.log('[更新後データ]', indexData[targetIndex]);

  // ======== Step 7: index.json 保存 ========
  await R2.put('index.json', JSON.stringify(indexData, null, 2), {
    httpMetadata: { contentType: 'application/json' },
  });

  // ======== Step 8: 書き込み確認用の再取得（オプション） ========
  // const verify = await R2.get('index.json');
  // const verifyText = await verify.text();
  // console.log('[書き込み後 index.json]', verifyText);

  return c.json({
    message: 'Edit successful',
    recipeId,
    fileId: newFileId,
    updated: indexData[targetIndex],
  });
});



app.post('/material/register', async (c) => {
  const { id, name, categoryMain, categorySub, apiKey } = await c.req.json();

  const SECRET_API_KEY = c.env.SECRET_API_KEY;

  if (apiKey !== SECRET_API_KEY) {
    return c.json({ error: 'Unauthorized' }, 401);
  }

  // ======================
  // 1. materials_index.json 読み込み
  // ======================
  let indexData: any[] = [];
  const indexObj = await c.env.R2.get('materials_index.json');
  if (indexObj) {
    indexData = await indexObj.json<any[]>();
  }

  // ======================
  // 2. 既に存在するIDのチェック（重複防止）
  // ======================
  const alreadyExists = indexData.some((item) => item.id === id);
  if (alreadyExists) {
    return c.json({ message: 'Material already registered' }, 200);
  }

  // ======================
  // 3. 新規材料データを追加
  // ======================
  indexData.push({
    id,              // FirestoreのID
    name,            // 材料名
    categoryMain,    // 大分類
    categorySub      // 小分類
  });

  // ======================
  // 4. materials_index.json 上書き保存
  // ======================
  await c.env.R2.put('materials_index.json', JSON.stringify(indexData, null, 2), {
    httpMetadata: { contentType: 'application/json' },
  });

  return c.json({ message: 'Material registered successfully' });
});


app.get('/material/search', async (c) => {
  try {
    const query = c.req.query('q') || '';
    const categoryMainQuery = c.req.query('categoryMain') || '';
    const categorySubQuery = c.req.query('categorySub') || '';

    console.log('検索クエリ:', query);
    console.log('メインカテゴリ検索:', categoryMainQuery);
    console.log('サブカテゴリ検索:', categorySubQuery);

    // ========================
    // 1. R2からmaterials_index.jsonを読み込み
    // ========================
    const obj = await c.env.R2.get('materials_index.json');
    if (!obj) {
      console.error('materials_index.json が存在しません');
      return c.json({ error: 'Index file not found' }, 404);
    }

    const text = await obj.text();
    console.log('materials_index.json 読み込み成功 (先頭100文字):', text.substring(0, 100));

    const data = JSON.parse(text) as {
      id: string;
      name: string;
      categoryMain: string;
      categorySub: string;
    }[];

    console.log('データ件数:', data.length);

    // ========================
    // 2. クエリの分割と小文字変換
    // ========================
    const keywords = query
      .split(/\s+/) // スペース区切り
      .filter(Boolean) // 空文字削除
      .map(k => k.toLowerCase());

    const lowerCategoryMain = categoryMainQuery.toLowerCase();
    const lowerCategorySub = categorySubQuery.toLowerCase();

    // ========================
    // 3. フィルタリング
    // ========================
    const result = data.filter(item => {
      // キーワード全てに部分一致するか (AND条件)
      const matchKeywords = keywords.every(keyword =>
        item.name.toLowerCase().includes(keyword) ||
        item.categoryMain.toLowerCase().includes(keyword) ||
        item.categorySub.toLowerCase().includes(keyword)
      );

      // カテゴリ完全一致 (空ならスキップ)
      const matchCategoryMain = !categoryMainQuery || item.categoryMain.toLowerCase() === lowerCategoryMain;
      const matchCategorySub = !categorySubQuery || item.categorySub.toLowerCase() === lowerCategorySub;

      return (keywords.length === 0 || matchKeywords) && matchCategoryMain && matchCategorySub;
    });

    console.log('検索結果件数:', result.length);

    // ========================
    // 4. 結果返却
    // ========================
    return c.json(result);

  } catch (error) {
    console.error('検索API エラー:', error);
    return c.json({ error: 'Internal Server Error', detail: String(error) }, 500);
  }
});

const tagSimilarityMap: Record<string, Record<string, number>> = {
  "甘い": { "甘党向け": 0.9, "フルーティ": 0.7, "ジュース感覚": 0.6 },
  "さっぱり": { "さっぱり派におすすめ": 0.9, "食前におすすめ": 0.6 },
  "ビター": { "アルコール感が強い": 0.7 },
  "濃厚": { "重め": 0.8, "アルコール感が強い": 0.6 },
  "フルーティ": { "甘い": 0.7, "さっぱり": 0.5 },
  "ハーバル": { "スパイシー": 0.6 },
  "スパイシー": { "ハーバル": 0.6 },
  "色がきれい": { "インスタ映え": 0.8 },
  "飾りが印象的": { "インスタ映え": 0.7 },
  "インスタ映え": { "色がきれい": 0.8, "飾りが印象的": 0.7 },
  "軽い": { "さっぱり": 0.7, "ジュース感覚": 0.6 },
  "重め": { "濃厚": 0.8 },
  "アルコール感が強い": { "ビター": 0.7, "重め": 0.6 },
  "ジュース感覚": { "甘い": 0.6, "軽い": 0.6 },
  "食前におすすめ": { "さっぱり": 0.6 },
  "食後に合う": { "濃厚": 0.5, "甘い": 0.5 },
  "夜にぴったり": { "アルコール感が強い": 0.6, "重め": 0.5 },
  "パーティ向き": { "インスタ映え": 0.6, "意外な組み合わせ": 0.5 },
  "材料がシンプル": { "家でも作りやすい": 0.8, "材料費が安い": 0.7 },
  "家でも作りやすい": { "材料がシンプル": 0.8 },
  "材料費が安い": { "材料がシンプル": 0.7 },
  "意外な組み合わせ": { "オリジナリティが高い": 0.8, "初めての味わい": 0.7 },
  "初めての味わい": { "意外な組み合わせ": 0.7 },
  "オリジナリティが高い": { "意外な組み合わせ": 0.8 },
  "甘党向け": { "甘い": 0.9 },
  "さっぱり派におすすめ": { "さっぱり": 0.9 },
  "アルコール強め好きに": { "アルコール感が強い": 0.9 },
};

app.post('/recommend', async (c) => {
  try {
    const body = await c.req.json<{ tagStats: Record<string, any> }>();
    const tagStats = body.tagStats;

    // 🔢 tagWeights を構築
    const tagWeights: Record<string, number> = {};

    for (const tag in tagStats) {
      const raw = tagStats[tag];
      const stat =
        raw?.mapValue?.fields // REST形式
        ?? raw;               // Flutter形式
    
      const ratingSum = parseFloat(
        stat.ratingSum?.integerValue ||
        stat.ratingSum?.doubleValue ||
        stat.ratingSum || '0'
      );
    
      tagWeights[tag] = (tagWeights[tag] || 0) + ratingSum;
    }
    

    console.log('📌 tagWeights:', tagWeights);

    // 📦 レシピ一覧をR2から取得
    const obj = await c.env.R2.get('index.json');
    if (!obj) return c.json({ error: 'Index file not found' }, 404);

    const indexData = await obj.json<any[]>();

    // 🧠 スコアリング処理（tagWeights → recipe.tags にマッチ）
    const scored = indexData.map(recipe => {
      const recipeTags: string[] = recipe.tags || [];
      let score = 0;

      for (const userTag in tagWeights) {
        const weight = tagWeights[userTag];

        for (const recipeTag of recipeTags) {
          if (userTag === recipeTag) {
            score += weight;
          } else {
            const similarity = tagSimilarityMap[userTag]?.[recipeTag] || 0;
            score += weight * similarity;
          }
        }
      }

      return { id: recipe.key, score };
    });

    console.log('🧮 スコア例:', scored.slice(0, 5));

    // 🎯 スコア上位20件を抽出
    const topRecipeIds = scored
      .filter(r => r.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, 20)
      .map(r => r.id);

    console.log('✅ レコメンド結果:', topRecipeIds);

    return c.json(topRecipeIds);
  } catch (err) {
    console.error('🚨 Recommend error:', err);
    return c.json({ error: 'Internal Server Error', detail: String(err) }, 500);
  }
});



export default app
