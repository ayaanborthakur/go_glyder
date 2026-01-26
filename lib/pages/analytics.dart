import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  static const Color primaryGreen = Color(0xFF023020);
  static const Color accentBlue = Color(0xFF2196F3);
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color accentPurple = Color(0xFF9C27B0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Analytics Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Overview Metrics'),
              _buildModernCard(
                title: 'Student Attendance Increase',
                content: _buildBarChart(),
                color: Colors.green[50]!,
              ),
              const SizedBox(height: 20),
              _buildSectionHeader('Engagement & Participation'),
              _buildModernCard(
                title: 'Parents Involved (%)',
                content: _buildPieChart(),
                color: Colors.blue[50]!,
              ),
              const SizedBox(height: 20),
              _buildSectionHeader('Operational Efficiency'),
              _buildModernCard(
                title: 'Carpools per Day',
                content: _buildCarpoolsBarChart(),
                color: Colors.orange[50]!,
              ),
              const SizedBox(height: 20),
              _buildModernCard(
                title: 'Traffic Carbon Impact Removed',
                content: _buildLineChart(),
                color: Colors.teal[50]!,
              ),
              const SizedBox(height: 20),
              _buildSectionHeader('Growth & Impact'),
              _buildModernCard(
                title: 'Extracurricular Growth (%)',
                content: _buildExtracurricularLineChart(),
                color: Colors.purple[50]!,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildModernCard({
    required String title,
    required Widget content,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: primaryGreen.withOpacity(0.7),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(height: 240, child: content),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        barGroups: [
          _makeGroupData(0, 27, Colors.green),
          _makeGroupData(1, 19, Colors.green),
          _makeGroupData(2, 36, Colors.green),
          _makeGroupData(3, 22, Colors.green),
          _makeGroupData(4, 15, Colors.green),
        ],
        titlesData: _buildDefaultTitles(
          days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: true),
      ),
    );
  }

  Widget _buildCarpoolsBarChart() {
    return BarChart(
      BarChartData(
        barGroups: [
          _makeGroupData(0, 45, Colors.orange),
          _makeGroupData(1, 52, Colors.orange),
          _makeGroupData(2, 48, Colors.orange),
          _makeGroupData(3, 60, Colors.orange),
          _makeGroupData(4, 55, Colors.orange),
          _makeGroupData(5, 30, Colors.orange),
          _makeGroupData(6, 25, Colors.orange),
        ],
        titlesData: _buildDefaultTitles(
          days: ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildPieChart() {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: 65,
            title: '65%',
            color: primaryGreen,
            radius: 50,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          PieChartSectionData(
            value: 35,
            title: '35%',
            color: Colors.grey[300],
            radius: 45,
            titleStyle: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey[200]!, strokeWidth: 1),
        ),
        titlesData: _buildDefaultTitles(),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 11),
              FlSpot(1, 18),
              FlSpot(2, 23),
              FlSpot(3, 16),
              FlSpot(4, 21),
            ],
            isCurved: true,
            color: Colors.teal,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.teal.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtracurricularLineChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: _buildDefaultTitles(),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 5),
              FlSpot(1, 12),
              FlSpot(2, 10),
              FlSpot(3, 25),
              FlSpot(4, 35),
            ],
            isCurved: true,
            color: Colors.purple,
            barWidth: 4,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.purple.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 16,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
      ],
    );
  }

  FlTitlesData _buildDefaultTitles({List<String>? days}) {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            if (days == null) return const Text('');
            final index = value.toInt();
            if (index >= 0 && index < days.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  days[index],
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              );
            }
            return const Text('');
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          getTitlesWidget: (value, meta) => Text(
            value.toInt().toString(),
            style: TextStyle(color: Colors.grey[500], fontSize: 10),
          ),
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }
}
