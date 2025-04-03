import 'package:cocktailmaestro/core/services/global.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cocktailmaestro/core/models/providers/material_provider.dart';
import 'package:cocktailmaestro/widgets/material_listview.dart';

class SearchIngredientsTab extends StatefulWidget {
  const SearchIngredientsTab({super.key});

  @override
  State<SearchIngredientsTab> createState() => _SearchIngredientsTabState();
}

class _SearchIngredientsTabState extends State<SearchIngredientsTab> {
  final TextEditingController _searchController = TextEditingController();

  String? _selectedCategoryMain;
  String? _selectedCategorySub;
  bool isLoading = false; // ロード中フラグ
  final Map<String, List<String>> _categoryMap = categoryMap;

  /// 検索実行
  void _performSearch() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('検索する内容を入力してください。')));
      return;
    }

    setState(() {
      isLoading = true;
    });

    final categoryMain =
        _selectedCategoryMain != 'すべて' ? _selectedCategoryMain : null;
    final categorySub =
        _selectedCategorySub != 'すべて' ? _selectedCategorySub : null;

    final Map<String, String> queryParams = {};
    if (query.isNotEmpty) queryParams['q'] = query;
    if (categoryMain != null) queryParams['categoryMain'] = categoryMain;
    if (categorySub != null) queryParams['categorySub'] = categorySub;

    Provider.of<MaterialProvider>(
      context,
      listen: false,
    ).searchMaterialsWithCloudflareAndFetchDetails(queryParams).then((_) {
      setState(() {
        isLoading = false;
      });
    });
  }

  List<String> _getSubCategories() {
    if (_selectedCategoryMain != null && _selectedCategoryMain != 'すべて') {
      return ['すべて', ..._categoryMap[_selectedCategoryMain!]!];
    }
    return ['すべて'];
  }

  @override
  Widget build(BuildContext context) {
    final materials = Provider.of<MaterialProvider>(context).materials;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: '材料を検索',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _performSearch,
                  ),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _performSearch(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      value: _selectedCategoryMain ?? 'すべて',
                      decoration: const InputDecoration(
                        labelText: 'メインカテゴリ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'すべて',
                          child: Text('すべて'),
                        ),
                        ..._categoryMap.keys.map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryMain = value;
                          _selectedCategorySub = 'すべて';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      value: _selectedCategorySub ?? 'すべて',
                      decoration: const InputDecoration(
                        labelText: 'サブカテゴリ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items:
                          _getSubCategories().map((value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategorySub = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              MaterialListView(
                materials: materials,
                onTap: (material) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${material.name} を選択しました')),
                  );
                },
              ),
              if (isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ],
    );
  }
}
