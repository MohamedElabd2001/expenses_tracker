import 'package:expenses_tracker/bar%20graph/bar_graph.dart';
import 'package:expenses_tracker/components/my_list_tile.dart';
import 'package:expenses_tracker/database/expense_database.dart';
import 'package:expenses_tracker/helper/helper_functions.dart';
import 'package:expenses_tracker/models/expense.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController amountController = TextEditingController();

  Future<Map<int, double>>? _monthlyTotalFuture;
  Future<double>? _calculateCurrentMonthTotal;

  @override
  void initState() {
    Provider.of<ExpenseDatabase>(context, listen: false).readExpenses();

    refreshData();

    super.initState();
  }

  void refreshData() {
    _monthlyTotalFuture = Provider.of<ExpenseDatabase>(context, listen: false)
        .calculateMonthlyTotals();
    _calculateCurrentMonthTotal =
        Provider.of<ExpenseDatabase>(context, listen: false)
            .calculateCurrentMonthTotal();
  }

  void openNewExpenseBox() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("New expense"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(hintText: "Name"),
            ),
            TextField(
              controller: amountController,
              decoration: InputDecoration(hintText: "Amount"),
            ),
          ],
        ),
        actions: [_cancelButton(), _createNewExpenseButton()],
      ),
    );
  }

  void openEditBox(Expense expense) {
    String existingName = expense.name;
    String existingAmout = expense.amount.toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("New expense"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(hintText: existingName),
            ),
            TextField(
              controller: amountController,
              decoration: InputDecoration(hintText: existingAmout),
            ),
          ],
        ),
        actions: [_cancelButton(), _editExpenseButton(expense)],
      ),
    );
  }

  void openDeleteBox(Expense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Expense?"),
        actions: [_cancelButton(), _deleteExpenseButton(expense.id)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseDatabase>(builder: (context, value, child) {
      int startMonth = value.getStartMonth();
      int startYear = value.getStartYear();
      int currentMonth = DateTime.now().month;
      int currentYear = DateTime.now().year;

      int monthCount = calculateMonthCount(
        startYear,
        startMonth,
        currentYear,
        currentMonth,
      );

      List<Expense> currentMonthExpenses = value.allExpense.where((expense) {
        return expense.date.year == currentYear &&
            expense.date.month == currentMonth;
      }).toList();

      return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: FutureBuilder<double>(
                future: _calculateCurrentMonthTotal,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("\$" + snapshot.data!.toStringAsFixed(2)),
                        Text(getCurrentMonthName())
                      ],
                    );
                  } else{
                    return Text("Loading...");
                  }
                }),
            centerTitle: true,
          ),
          backgroundColor: Colors.grey.shade300,
          floatingActionButton: FloatingActionButton(
            onPressed: openNewExpenseBox,
            child: Icon(Icons.add),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Text("Eh BAAA"),
                SizedBox(
                  height: 250,
                  child: FutureBuilder(
                    future: _monthlyTotalFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        final monthlyTotals = snapshot.data ?? {};

                        List<double> monthlySummary = List.generate(
                            monthCount,
                            (index) =>
                                monthlyTotals[startMonth + index] ?? 0.0);

                        return MyBarGraph(
                            monthlySummary: monthlySummary,
                            startMonth: startMonth);
                      } else {
                        return Center(
                          child: Text("Loading.."),
                        );
                      }
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                      itemCount: currentMonthExpenses.length,
                      itemBuilder: (context, index) {
                        int reversedIndex =
                            currentMonthExpenses.length - 1 - index;
                        Expense individualExpense =
                            currentMonthExpenses[reversedIndex];

                        return MyListTile(
                          title: individualExpense.name,
                          trailing: formatAmount(individualExpense.amount),
                          onEditPressed: (context) =>
                              openEditBox(individualExpense),
                          onDelPressed: (context) =>
                              openDeleteBox(individualExpense),
                        );
                      }),
                ),
              ],
            ),
          ));
    });
  }

  Widget _cancelButton() {
    return MaterialButton(
      onPressed: () {
        Navigator.pop(context);

        nameController.clear();
        amountController.clear();
      },
      child: Text("Cancel"),
    );
  }

  Widget _createNewExpenseButton() {
    return MaterialButton(
      onPressed: () async {
        if (nameController.text.isNotEmpty &&
            amountController.text.isNotEmpty) {
          Navigator.pop(context);
          Expense newExpense = Expense(
            amount: convertStringToDouble(amountController.text),
            name: nameController.text,
            date: DateTime.now(),
          );

          await context.read<ExpenseDatabase>().createNewExpense(newExpense);

          refreshData();

          nameController.clear();
          amountController.clear();
        }
      },
      child: Text("Save..."),
    );
  }

  Widget _editExpenseButton(Expense expense) {
    return MaterialButton(
      onPressed: () async {
        if (nameController.text.isNotEmpty ||
            amountController.text.isNotEmpty) {
          Navigator.pop(context);

          Expense updatedExpense = Expense(
            amount: amountController.text.isNotEmpty
                ? convertStringToDouble(amountController.text)
                : expense.amount,
            name: nameController.text.isNotEmpty
                ? nameController.text
                : expense.name,
            date: DateTime.now(),
          );

          int existingId = expense.id;

          await context
              .read<ExpenseDatabase>()
              .updateExpense(existingId, updatedExpense);
        }
        refreshData();
      },
      child: Text("Save..."),
    );
  }

  Widget _deleteExpenseButton(int id) {
    return MaterialButton(
      onPressed: () async {
        Navigator.pop(context);

        await context.read<ExpenseDatabase>().deleteExpense(id);
        refreshData();
      },
      child: Text("Delete..."),
    );
  }
}
