import 'package:cocktailmaestro/core/providers/user_provider.dart';
import 'package:cocktailmaestro/core/utils/report_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text(user?.displayName ?? 'ゲスト'),
            accountEmail: Text(user?.email ?? 'メールアドレス未登録'),
            currentAccountPicture: CircleAvatar(
              backgroundImage:
                  user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child:
                  user?.photoURL == null ? Icon(Icons.person, size: 40) : null,
            ),
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('設定'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
          ),
          ListTile(
            leading: Icon(Icons.receipt_long),
            title: Text('マイレシピ'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/my_recipes');
            },
          ),
          ListTile(
            leading: Icon(Icons.bug_report),
            title: Text('アプリの不具合を報告する'),
            onTap: () => showReportDialog(context: context, reportType: 'app'),
          ),

          ListTile(
            leading: Icon(Icons.logout),
            title: Text('ログアウト'),
            onTap: () async {
              await userProvider.signOut();
            },
          ),
        ],
      ),
    );
  }
}
