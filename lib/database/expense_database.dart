import 'package:path_provider/path_provider.dart';

import '../models/expense.dart';
import 'package:flutter/cupertino.dart';
import 'package:isar/isar.dart';

class ExpenseDataBase extends ChangeNotifier {
  static late Isar isar;
  List<Expense> _allExpenses = [];

  // db initialize
  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open([ExpenseSchema], directory: dir.path);
  }

  // getter: makes it possible to get _allExpenses list anywhere in the code
  List<Expense> get allExpense => _allExpenses;

  // method: creates and adds a new expense to db
  Future<void> createNewExpense(Expense newExpense) async {
    // Txn - transaction
    await isar.writeTxn(() => isar.expenses.put(newExpense));

    // after each change it is necessary to re-read expenses
    await readExpenses();
  }

  // reading
  Future<void> readExpenses() async {
    // fetching (извлечение) all existing expenses from db
    List<Expense> fetchedExpenses = await isar.expenses.where().findAll();

    // clearing current list and then adding expenses to local list
    _allExpenses.clear();
    _allExpenses.addAll(fetchedExpenses);

    // updates UI
    notifyListeners();
  }

  Future<void> updateExpense(int id, Expense updatedExpense) async {
    // new expense has to have the same id as the existing one
    updatedExpense.id = id;

    // updating db
    await isar.writeTxn(() => isar.expenses.put(updatedExpense));

    await readExpenses();
  }

  Future<void> deleteExpense(int id) async {
    await isar.writeTxn(() => isar.expenses.delete(id));
    await readExpenses();
  }
}