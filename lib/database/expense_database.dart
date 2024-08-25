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

  // helper, calculates all of the expenses for each month
  Future<Map<String, double>> calculateMonthlyTotals() async {
    await readExpenses(); // ensures that the infos are updated

    // map to keep track of the total expenses per month
    Map<String, double> monthlyTotals = {};

    // iterating over all expenses
    for (var expense in _allExpenses) {
      String yearMonth = '${expense.date.year}-${expense.date.month}'; // extracts the month from the date of expense creation

      // if the year-month is not in the map => set the initial total amount to zero
      if (!monthlyTotals.containsKey(yearMonth)) {
        monthlyTotals[yearMonth] = 0;
      }

      // adding the expense amount to the total for the month
      monthlyTotals[yearMonth] = monthlyTotals[yearMonth]! + expense.amount;
    }
    return monthlyTotals;
  }

  Future<double> calculateCurrentMonthTotal() async {
    await readExpenses();

    int currentMonth = DateTime.now().month;
    int currentYear = DateTime.now().year;

    List<Expense> currentMonthExpenses = _allExpenses.where((expense) {
      return expense.date.month == currentMonth &&
          expense.date.year == currentYear;
    }).toList();

    double total =
        currentMonthExpenses.fold(0, (sum, expense) => sum + expense.amount);
    return total;
  }

  int getStartMonth() {
    if (_allExpenses.isEmpty) {
      return DateTime.now().month;
    }

    // sort expenses to find the earliest
    _allExpenses.sort(
      (a, b) => a.date.compareTo(b.date),
    );
    return _allExpenses.first.date.month;
  }

  int getStartYear() {
    if (_allExpenses.isEmpty) {
      return DateTime.now().year;
    }

    // sort expenses to find the earliest
    _allExpenses.sort(
      (a, b) => a.date.compareTo(b.date),
    );
    return _allExpenses.first.date.year;
  }
}
