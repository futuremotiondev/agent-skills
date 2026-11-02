import 'package:flutter/material.dart';

class Counter extends StatefulWidget {
  const Counter({super.key, this.start = 0});
  Counter.named(int x) : this(start: x);
  factory Counter.fromJson(Map<String, dynamic> json) => Counter(start: json['s']);

  final int start;

  @override
  State<Counter> createState() => _CounterState();

  int get doubled => start * 2;

  Future<void> load() async {
    await Future.delayed(const Duration(seconds: 1));
  }

  static int _helper(int x) {
    return x;
  }
}

void main() {
  runApp(const Counter());
}

sum(a, b) => a + b;
