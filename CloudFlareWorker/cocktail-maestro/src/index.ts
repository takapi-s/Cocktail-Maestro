import { Hono } from 'hono'

type Bindings = {
  SECRET_API_KEY: string
  GAS_ENDPOINT: string
  R2: R2Bucket
}

type GasUploadResponse = {
  url: string;
  fileId: string;
};


const app = new Hono<{ Bindings: Bindings }>()

app.post('/upload', async (c) => {
  const { imageBase64, fileName, apiKey, recipeInfo } = await c.req.json();

  const GAS_ENDPOINT = c.env.GAS_ENDPOINT;
  const SECRET_API_KEY = c.env.SECRET_API_KEY;

  if (apiKey !== SECRET_API_KEY) {
    return c.json({ error: 'Unauthorized' }, 401);
  }

  // ======================
  // 1. GASへの画像転送処理
  // ======================
  const gasResponse = await fetch(GAS_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'upload', // 明示的にアクション指定
      imageBase64,
      fileName,
      apiKey: SECRET_API_KEY,
    }),
  });
  
  const gasResult = await gasResponse.json() as GasUploadResponse;
  const { url, fileId } = gasResult;

  const recipeId = crypto.randomUUID(); // 一意なID生成

  // ======================
  // 2. index.json の更新処理
  // ======================
  let indexData: any[] = [];
  const indexObj = await c.env.R2.get('index.json');
  if (indexObj) {
    indexData = await indexObj.json<any[]>();
  }

  const ingredientsNames = recipeInfo.ingredients?.map((ing: any) => ing.name) || [];
  indexData.push({
    key: `${recipeId}`,
    name: recipeInfo.name,
    ingredients: ingredientsNames,
    fileId, // 追加
  });

  await c.env.R2.put('index.json', JSON.stringify(indexData, null, 2), {
    httpMetadata: { contentType: 'application/json' },
  });

  return c.json({
    message: 'Upload successful',
    fileId: fileId,
    recipeId: recipeId,
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
  const { recipeId, apiKey } = await c.req.json();

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
      fileId: targetRecipe.fileId, // 対象ファイルID
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
  const { recipeId, apiKey, recipeInfo, imageBase64, fileName } = await c.req.json();

  const SECRET_API_KEY = c.env.SECRET_API_KEY;
  const GAS_ENDPOINT = c.env.GAS_ENDPOINT;

  if (apiKey !== SECRET_API_KEY) {
    return c.json({ error: 'Unauthorized' }, 401);
  }

  // index.json を読み込む
  const indexObj = await c.env.R2.get('index.json');
  if (!indexObj) {
    return c.json({ error: 'Index file not found' }, 404);
  }

  const indexData = await indexObj.json<any[]>();
  const targetIndex = indexData.findIndex(item => item.key === recipeId);

  if (targetIndex === -1) {
    return c.json({ error: 'Recipe not found' }, 404);
  }

  let newFileId = indexData[targetIndex].fileId; // 初期は元のファイルIDをそのまま使う

  // 新しい画像があれば GAS にアップロード
  if (imageBase64 && fileName) {
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

    const gasResult = await gasResponse.json() as GasUploadResponse;
    newFileId = gasResult.fileId;

    // 旧画像の削除（オプション）
    const oldFileId = indexData[targetIndex].fileId;
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

  // indexData の該当レシピを更新
  const ingredientsNames = recipeInfo.ingredients?.map((ing: any) => ing.name) || [];
  indexData[targetIndex] = {
    ...indexData[targetIndex],
    name: recipeInfo.name,
    ingredients: ingredientsNames,
    fileId: newFileId,
  };

  await c.env.R2.put('index.json', JSON.stringify(indexData, null, 2), {
    httpMetadata: { contentType: 'application/json' },
  });

  return c.json({
    message: 'Edit successful',
    recipeId,
    fileId: newFileId,
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

app.get('/recommend', async (c) => {
  
});

export default app
