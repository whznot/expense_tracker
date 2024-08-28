import 'package:expense_tracker/bar%20graph/bar_graph.dart';
import 'package:expense_tracker/components/my_list_tile.dart';
import 'package:expense_tracker/database/expense_database.dart';
import 'package:expense_tracker/helper/helper_functions.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController amountController = TextEditingController();

  // futures to load graph data & monthly total
  Future<Map<String, double>>? _monthlyTotalsFuture;
  Future<double>? _calculateCurrentMonthTotal;

  @override
  void initState() {
    super.initState();

    // ensure context is available before accessing provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // reading db on an initial startup
      Provider.of<ExpenseDataBase>(context, listen: false).readExpenses();

      // loading futures (to refresh graph data)
      refreshData();
    });
  }

// refreshing graph data
  void refreshData() {
    final expenseDataBase =
        Provider.of<ExpenseDataBase>(context, listen: false);

    _monthlyTotalsFuture = expenseDataBase.calculateMonthlyTotals();
    _calculateCurrentMonthTotal = expenseDataBase.calculateCurrentMonthTotal();
  }

  void openNewExpenseBox() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New expense"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: "name"),
            ),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(hintText: "amount"),
            ),
          ],
        ),
        actions: [
          _cancelButton(),
          _createNewExpenseButton(),
        ],
      ),
    );
  }

  void openEditBox(Expense expense) {
    String existingName = expense.name;
    String existingAmount = expense.amount.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit expense"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(hintText: existingName),
            ),
            TextField(
              controller: amountController,
              decoration: InputDecoration(hintText: existingAmount),
            ),
          ],
        ),
        actions: [
          _cancelButton(),
          _editExpenseButton(expense),
        ],
      ),
    );
  }

  void openDeleteBox(Expense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete expense"),
        actions: [
          _cancelButton(),
          _deleteExpenseButton(expense.id),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseDataBase>(builder: (context, value, child) {
      int startMonth = value.getStartMonth();
      int startYear = value.getStartYear();
      int currentMonth = DateTime.now().month;
      int currentYear = DateTime.now().year;

      int monthCount =
          calculateMonthCount(startYear, startMonth, currentYear, currentMonth);

      return Scaffold(
        backgroundColor: Colors.grey.shade300,
        floatingActionButton: FloatingActionButton(
          onPressed: openNewExpenseBox,
          child: const Icon(Icons.add),
        ),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: FutureBuilder(
              future: _calculateCurrentMonthTotal,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${snapshot.data!.toStringAsFixed(2)}€'),
                      Text(getCurrentMonthName()),
                    ],
                  );
                } else {
                  return const Text('loading data..');
                }
              }),
        ),
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 250,
                child: FutureBuilder(
                  future: _monthlyTotalsFuture,
                  builder: (context, snapshot) {
                    // check if data is loaded
                    if (snapshot.connectionState == ConnectionState.done) {
                      Map<String, double> monthlyTotals = snapshot.data ?? {};

                      List<double> monthlySummary = List.generate(
                        monthCount,
                        (index) {
                          int year = startYear + (startMonth + index - 1) ~/ 12;
                          int month = (startMonth + index - 1) % 12 + 1;

                          String yearMonthKey = '$year-$month';

                          return monthlyTotals[yearMonthKey] ?? 0.0;
                        },
                      );
                      return MyBarGraph(
                          monthlySummary: monthlySummary,
                          startMonth: startMonth);
                    } else {
                      return const Center(
                        child: Text("loading.."),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 25),
              SlidableAutoCloseBehavior(
                child: Expanded(
                  child: ListView.builder(
                    itemCount: value.allExpense.length,
                    itemBuilder: (context, index) {
                      int reversedIndex = value.allExpense.length - 1 - index;

                      Expense individualExpense =
                          value.allExpense[reversedIndex];

                      return MyListTile(
                        title: individualExpense.name,
                        trailing: formatAmount(individualExpense.amount),
                        onEditPressed: (context) =>
                            openEditBox(individualExpense),
                        onDeletePressed: (context) =>
                            openDeleteBox(individualExpense),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _cancelButton() {
    return MaterialButton(
      onPressed: () {
        Navigator.pop(context);

        nameController.clear();
        amountController.clear();
      },
      child: const Text("Cancel"),
    );
  }

  Widget _createNewExpenseButton() {
    return MaterialButton(
      onPressed: () async {
        if (nameController.text.isNotEmpty &&
            amountController.text.isNotEmpty) {
          Navigator.pop(context);
          Expense newExpense = Expense(
            name: nameController.text,
            amount: convertStringToDouble(amountController.text),
            date: DateTime.now(),
          );
          await context.read<ExpenseDataBase>().createNewExpense(newExpense);

          refreshData();

          nameController.clear();
          amountController.clear();
        }
      },
      child: const Text("Save"),
    );
  }

  Widget _editExpenseButton(Expense expense) {
    return MaterialButton(
      onPressed: () async {
        if (nameController.text.isNotEmpty ||
            amountController.text.isNotEmpty) {
          Navigator.pop(context);

          // creating a new updated expense
          Expense updatedExpense = Expense(
            name: nameController.text.isNotEmpty
                ? nameController.text
                : expense.name,
            amount: amountController.text.isNotEmpty
                ? convertStringToDouble(amountController.text)
                : expense.amount,
            date: DateTime.now(),
          );

          // keeping id the same
          int existingId = expense.id;

          // saving to db
          await context
              .read<ExpenseDataBase>()
              .updateExpense(existingId, updatedExpense);

          refreshData();
        }
      },
      child: const Text("Save"),
    );
  }

  Widget _deleteExpenseButton(int id) {
    return MaterialButton(
      onPressed: () async {
        Navigator.pop(context);
        await context.read<ExpenseDataBase>().deleteExpense(id);

        refreshData();
      },
      child: const Text("Delete"),
    );
  }
}
