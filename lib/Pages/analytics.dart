import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analytics'),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Text(
              'User Analytics',
              style: TextStyle(fontSize: 24),
            ),
            Expanded(
              child: BarChart(
                BarChartData(
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 5)]),
                    BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 10)]),
                    BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 15)]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
