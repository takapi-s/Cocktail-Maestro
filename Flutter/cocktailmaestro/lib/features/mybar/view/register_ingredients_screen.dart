import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocktailmaestro/core/services/global.dart';
import 'package:cocktailmaestro/core/models/material_model.dart';
import 'package:cocktailmaestro/core/providers/material_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RegisterIngredientScreen extends StatefulWidget {
  const RegisterIngredientScreen({super.key});

  @override
  State<RegisterIngredientScreen> createState() =>
      _IngredientRegisterScreenState();
}

class _IngredientRegisterScreenState extends State<RegisterIngredientScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _alcPercentController = TextEditingController();
  final TextEditingController _affiliateUrlController = TextEditingController();

  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _isSubmitting = false;
  String? _selectedMainCategory;
  String? _selectedSubCategory;

  final Map<String, List<String>> _categoryMap = categoryMap;

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      final newMaterial = MaterialModel(
        id: '',
        name: _nameController.text.trim(),
        categoryMain: _selectedMainCategory!,
        categorySub: _selectedSubCategory!,
        alcPercent: double.tryParse(_alcPercentController.text.trim()) ?? 0.0,
        affiliateUrl: _affiliateUrlController.text.trim(),
        approved: false,
        createdAt: Timestamp.now(),
        registeredBy: userId,
      );

      await Provider.of<MaterialProvider>(
        context,
        listen: false,
      ).addMaterial(newMaterial);

      setState(() {
        _isSubmitting = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('材料を登録しました（承認待ち）')));

      Navigator.pop(context);
    }
  }

  bool _isFormComplete() {
    return _nameController.text.isNotEmpty &&
        _selectedMainCategory != null &&
        _selectedSubCategory != null &&
        _alcPercentController.text.isNotEmpty &&
        _affiliateUrlController.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新しい材料を登録')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '材料名'),
                validator: (value) => value!.isEmpty ? '材料名は必須です' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedMainCategory,
                decoration: const InputDecoration(labelText: '大カテゴリ'),
                items:
                    _categoryMap.keys
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMainCategory = value;
                    _selectedSubCategory = null;
                  });
                },
                validator: (value) => value == null ? '大カテゴリは必須です' : null,
              ),
              const SizedBox(height: 16),
              if (_selectedMainCategory != null)
                DropdownButtonFormField<String>(
                  value: _selectedSubCategory,
                  decoration: const InputDecoration(labelText: '小カテゴリ'),
                  items:
                      _categoryMap[_selectedMainCategory!]!
                          .map(
                            (sub) =>
                                DropdownMenuItem(value: sub, child: Text(sub)),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSubCategory = value;
                    });
                  },
                  validator: (value) => value == null ? '小カテゴリは必須です' : null,
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _alcPercentController,
                decoration: const InputDecoration(labelText: 'アルコール度数 (%)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value!.isEmpty) return 'アルコール度数は必須です';
                  final doubleValue = double.tryParse(value);
                  if (doubleValue == null ||
                      doubleValue < 0 ||
                      doubleValue > 100) {
                    return '有効なアルコール度数を入力してください（0〜100の範囲）';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _affiliateUrlController,
                decoration: const InputDecoration(labelText: '商品リンク'),
                validator: (value) => value!.isEmpty ? '商品リンクは必須です' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 32),
              _isSubmitting
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                    onPressed: _isFormComplete() ? _submitForm : null,
                    child: const Text('材料を登録する'),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
