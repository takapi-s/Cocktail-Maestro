import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CommentSection extends StatefulWidget {
  final String collectionName; // e.g. 'recipes'
  final String docId; // e.g. recipe.id

  const CommentSection({
    super.key,
    required this.collectionName,
    required this.docId,
  });

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    final snapshot =
        await _firestore
            .collection(widget.collectionName)
            .doc(widget.docId)
            .collection('comments')
            .orderBy('timestamp', descending: true)
            .get();

    setState(() {
      _comments =
          snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id; // コメントIDを保存しておく（削除に使う）
            return data;
          }).toList();
    });
  }

  Future<void> _submitComment() async {
    final comment = _controller.text.trim();
    if (comment.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final user = _auth.currentUser!;
    final nickname = user.displayName ?? '匿名';

    await _firestore
        .collection(widget.collectionName)
        .doc(widget.docId)
        .collection('comments')
        .add({
          'userId': user.uid,
          'nickname': nickname,
          'comment': comment,
          'timestamp': FieldValue.serverTimestamp(),
        });

    _controller.clear();
    setState(() => _isSubmitting = false);
    await _fetchComments();
  }

  Future<void> _deleteComment(String commentId) async {
    final user = _auth.currentUser!;
    final commentRef = _firestore
        .collection(widget.collectionName)
        .doc(widget.docId)
        .collection('comments')
        .doc(commentId);

    final snapshot = await commentRef.get();
    if (snapshot.exists && snapshot.data()?['userId'] == user.uid) {
      await commentRef.delete();
      await _fetchComments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(thickness: 1),
        const Text(
          'コメント',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        ..._comments.map((c) {
          final isOwn = c['userId'] == currentUser?.uid;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.comment, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            c['nickname'] ?? '名無し',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            c['timestamp'] != null
                                ? (c['timestamp'] as Timestamp)
                                    .toDate()
                                    .toLocal()
                                    .toString()
                                    .substring(0, 16)
                                : '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          if (isOwn)
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                size: 20,
                                color: Colors.redAccent,
                              ),
                              onPressed: () async {
                                await _deleteComment(c['id']);
                              },
                            ),
                        ],
                      ),
                      Text(c['comment'] ?? ''),
                      const Divider(),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),

        TextField(
          controller: _controller,
          maxLines: null,
          decoration: const InputDecoration(
            labelText: 'コメントを入力...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitComment,
          child: const Text('送信'),
        ),
      ],
    );
  }
}
