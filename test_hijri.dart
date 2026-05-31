import 'package:hijri/hijri_calendar.dart';

void main() {
  try {
    HijriCalendar.setLocal('id');
    print('Success');
  } catch(e) {
    print('Failed: $e');
  }
}
