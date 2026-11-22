import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/date_utils.dart';

/// The names must match the check constraint on `expenses.category`.
enum ExpenseCategory {
  food('Food', Icons.restaurant_rounded, AppColors.orange),
  transport('Transport', Icons.directions_bus_rounded, AppColors.blue),
  study('Study', Icons.menu_book_rounded, AppColors.purple),
  mobile('Mobile & net', Icons.wifi_rounded, AppColors.cyan),
  health('Health', Icons.medical_services_rounded, AppColors.error),
  other('Other', Icons.category_rounded, AppColors.textSecondary);

  final String label;
  final IconData icon;
  final Color color;

  const ExpenseCategory(this.label, this.icon, this.color);

  /// Rows from before the categories were merged read as their new home.
  static ExpenseCategory fromName(String? name) => switch (name) {
    'education' => study,
    'housing' || 'fun' => other,
    _ => ExpenseCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => other,
    ),
  };
}

class Expense {
  final String id;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime spentOn;
  final String? note;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.spentOn,
    required this.note,
    required this.createdAt,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    final note = (map['note'] as String?)?.trim();
    return Expense(
      id: map['id'] as String,
      title: (map['title'] as String?)?.trim() ?? '',
      amount: (map['amount'] as num).toDouble(),
      category: ExpenseCategory.fromName(map['category'] as String?),
      spentOn: AppDate.fromDbDate(map['spent_on'] as String),
      note: (note == null || note.isEmpty) ? null : note,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toRow() => {
    'title': title,
    'amount': amount,
    'category': category.name,
    'spent_on': AppDate.toDbDate(spentOn),
    'note': note,
  };
}
