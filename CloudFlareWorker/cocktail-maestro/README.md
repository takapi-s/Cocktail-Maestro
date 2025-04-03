## Gasとの連携、検索機能をCloud Flareで実装している

以下のコマンドで各値を登録するか、Cloud Flareのwebpageで登録する必要がある
```
wrangler secret put SECRET_API_KEY 
wrangler secret put GAS_ENDPOINT 
```

これでデプロイ
```
wrangler deploy
```

