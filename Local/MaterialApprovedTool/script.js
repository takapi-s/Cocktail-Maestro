// Firebase 初期化
const firebaseConfig = {
    apiKey: "AIzaSyDuOiMTYpaotuDUy1mughdve2dmTSIr_Xw",
    authDomain: "e-business-6330a.firebaseapp.com",
    projectId: "e-business-6330a",
    storageBucket: "e-business-6330a.firebasestorage.app",
    messagingSenderId: "344832694445",
    appId: "1:344832694445:web:7d0d28dc9cc0d87f2c8e24",
    measurementId: "G-PGFV3953S3"
};

const app = firebase.initializeApp(firebaseConfig);
const db = firebase.firestore(app);

// ログインボタン
document.getElementById("login-button").addEventListener("click", () => {
    const provider = new firebase.auth.GoogleAuthProvider();
    firebase.auth().signInWithPopup(provider)
        .catch((error) => {
            alert("ログインに失敗しました: " + error.message);
        });
});

firebase.auth().onAuthStateChanged((user) => {
    if (user) {
        user.getIdTokenResult().then((idTokenResult) => {
            if (idTokenResult.claims.admin === true) {
                // 管理者UIを表示
                document.getElementById("login-panel").style.display = "none";
                document.getElementById("app-left").style.display = "block";
                document.getElementById("app-right").style.display = "block";
                fetchMaterials();
            } else {
                // 管理者でない場合：アクセス拒否画面を表示
                document.getElementById("login-panel").style.display = "none";
                document.getElementById("unauthorized-panel").style.display = "block";
                firebase.auth().signOut();
            }
        }).catch((error) => {
            console.error("トークン取得エラー:", error);
            alert("トークン取得に失敗しました。");
        });
    }
});


// 現在選択中のドキュメントID
let currentDocId = null;

// Firestore materials コレクションから未承認データを取得
function fetchMaterials() {
    db.collection("materials").where("approved", "==", false).get().then((querySnapshot) => {
        const materialList = document.getElementById("material-list");
        materialList.innerHTML = "";
        querySnapshot.forEach((doc) => {
            const data = doc.data();
            const listItem = document.createElement("li");
            listItem.textContent = data.name;
            listItem.addEventListener("click", () => {
                currentDocId = doc.id;
                showDetail(data);
            });
            materialList.appendChild(listItem);
        });
    });
}

// 詳細表示
function showDetail(data) {
    const detailContent = document.getElementById("detail-content");
    detailContent.innerHTML = `<pre>${JSON.stringify(data, null, 2)}</pre>`;

    document.getElementById("name-input").value = data.name || "";
    document.getElementById("alcohol-input").value = data.alcPercent !== undefined ? data.alcPercent : "";
    document.getElementById("category-main-input").value = data.categoryMain || "";
    document.getElementById("category-sub-input").value = data.categorySub || "";
    document.getElementById("affiliate-input").value = data.affiliateUrl || "";

    if (data.affiliateUrl) {
        window.open(data.affiliateUrl, "newwindow");
    }
}

// 認証ボタン（approved を true にする）
document.getElementById("approve-button").addEventListener("click", () => {
    const name = document.getElementById("name-input").value;
    const alcPercent = parseFloat(document.getElementById("alcohol-input").value) || null;
    const categoryMain = document.getElementById("category-main-input").value;
    const categorySub = document.getElementById("category-sub-input").value;
    const affiliateUrl = document.getElementById("affiliate-input").value;

    if (currentDocId && name) {
        db.collection("materials").doc(currentDocId).update({
            name,
            alcPercent,
            categoryMain,
            categorySub,
            affiliateUrl,
            approved: true
        }).then(() => {
            alert("認証が完了しました。");
            fetchMaterials(); // 再読み込み
        }).catch((error) => {
            console.error("認証エラー:", error);
            alert("認証に失敗しました。");
        });
    } else {
        alert("名前を入力してください。");
    }
});
