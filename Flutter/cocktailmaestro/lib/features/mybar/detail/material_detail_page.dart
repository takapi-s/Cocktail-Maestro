import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocktailmaestro/core/utils/report_dialog.dart';
import 'package:cocktailmaestro/widgets/comment_section.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cocktailmaestro/core/models/material_model.dart';
import 'package:url_launcher/url_launcher.dart';

class MaterialDetailPage extends StatefulWidget {
  final MaterialModel material;

  const MaterialDetailPage({super.key, required this.material});

  @override
  State<MaterialDetailPage> createState() => _MaterialDetailPageState();
}

class _MaterialDetailPageState extends State<MaterialDetailPage> {
  bool _isOwned = false;
  bool _initialOwned = false; // 初期値を保持しておく
  bool _loading = true;

  final userId = FirebaseAuth.instance.currentUser?.uid; // 現在のユーザーID

  @override
  void initState() {
    super.initState();
    _checkIfOwned();
  }

  // ✅ 初期状態を確認
  Future<void> _checkIfOwned() async {
    if (userId == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('OwnedIngredient')
        .doc(widget.material.id);

    final doc = await docRef.get();

    if (mounted) {
      setState(() {
        _isOwned = doc.exists;
        _initialOwned = doc.exists; // 初期状態を保存
        _loading = false;
      });
    }
  }

  // ✅ 実際の登録・削除処理（画面離れる時だけ呼ぶ）
  Future<void> _submitIfChanged() async {
    if (userId == null) return;
    if (_isOwned == _initialOwned) return; // 変更がなければ送信しない

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('OwnedIngredient')
        .doc(widget.material.id);

    if (_isOwned) {
      await docRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'materialName': widget.material.name,
      });
    } else {
      await docRef.delete();
    }
  }

  @override
  void dispose() {
    _submitIfChanged(); // 離脱時に保存（awaitしない）
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.material.name),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () async {
            await _submitIfChanged(); // AppBar戻るも対応
            // ignore: use_build_context_synchronously
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed:
                () => showReportDialog(
                  context: context,
                  reportType: 'material',
                  materialId: widget.material.id,
                ),
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.material.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text('カテゴリ: ${widget.material.categoryMain}'),
                        ),
                        Chip(
                          label: Text('サブカテゴリ: ${widget.material.categorySub}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '度数: ${widget.material.alcPercent}%',
                      style: TextStyle(
                        fontSize: 18,
                        color:
                            widget.material.alcPercent > 20
                                ? Colors.red
                                : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('持っている', style: TextStyle(fontSize: 18)),
                        Switch(
                          value: _isOwned,
                          onChanged: (value) {
                            setState(() {
                              _isOwned = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (widget.material.affiliateUrl.isNotEmpty)
                      ElevatedButton(
                        onPressed:
                            widget.material.approved
                                ? () async {
                                  final url = Uri.parse(
                                    widget.material.affiliateUrl,
                                  );
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(
                                      url,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('リンクを開けませんでした'),
                                      ),
                                    );
                                  }
                                }
                                : null,
                        child: const Text('この材料を購入する [楽天]'),
                      ),

                    if (!widget.material.approved)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'この材料はまだ認証されていません。認証されると購入できます。',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),

                    const SizedBox(height: 32),

                    // コメントセクション
                    CommentSection(
                      collectionName: "materials",
                      docId: widget.material.id,
                    ),
                  ],
                ),
              ),
    );
  }
}
