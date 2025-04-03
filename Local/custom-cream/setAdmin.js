const admin = require("firebase-admin");
const readline = require("readline");
const serviceAccount = require("./e-business-6330a-firebase-adminsdk-a70xb-0d705a30e0.json"); // パスは適宜変更

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

rl.question("UIDを入力してください: ", (uid) => {
  admin.auth().setCustomUserClaims(uid, { admin: true })
    .then(() => {
      console.log("✅ 管理者権限を設定しました！");
    })
    .catch((error) => {
      console.error("❌ エラーが発生しました:", error);
    })
    .finally(() => {
      rl.close();
    });
});
