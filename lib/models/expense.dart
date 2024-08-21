import 'package:isar/isar.dart';

// this line is needed to create isar file
// isar is a data base
// to create it you run following in the cmd: dart run build_runner build
part 'expense.g.dart';

@Collection()
class Expense {
  Id id = Isar.autoIncrement;

  final String name;
  final double amount;
  final DateTime date;

  Expense({
    required this.name,
    required this.amount,
    required this.date,
  });
}
