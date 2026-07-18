import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/stats/widgets/member_chart_colors.dart';

void main() {
  test('üye grafik rengi sıralamadan bağımsız ve sabittir', () {
    final aliceContributionColor = memberChartColor('alice-id');
    final bobContributionColor = memberChartColor('bob-id');

    expect(memberChartColor('alice-id'), aliceContributionColor);
    expect(memberChartColor('bob-id'), bobContributionColor);
  });
}
