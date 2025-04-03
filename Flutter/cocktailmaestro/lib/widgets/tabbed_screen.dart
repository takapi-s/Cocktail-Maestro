import 'package:flutter/material.dart';

class TabbedScreen extends StatelessWidget {
  final List<Tab> tabs;
  final List<Widget> views;
  final Widget? Function(int tabIndex)? fabBuilder;

  const TabbedScreen({
    super.key,
    required this.tabs,
    required this.views,
    this.fabBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        body: Column(
          children: [
            TabBar(tabs: tabs),
            Expanded(child: TabBarView(children: views)),
          ],
        ),
        floatingActionButton:
            fabBuilder != null
                ? Builder(
                  builder: (context) {
                    final controller = DefaultTabController.of(context);
                    return AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) {
                        return fabBuilder!(controller.index) ??
                            const SizedBox.shrink();
                      },
                    );
                  },
                )
                : null,
      ),
    );
  }
}
