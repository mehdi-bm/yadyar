import 'package:intl/intl.dart';

final NumberFormat _amountFormat = NumberFormat.decimalPattern('fa');

String formatTooman(num amount) => '${_amountFormat.format(amount)} تومان';
