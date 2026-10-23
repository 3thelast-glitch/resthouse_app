// Hijri date formatting helpers shared by the booking manager and the
// Hijri date picker dialog.
String toArabicDigits(int number) {
  const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return number
      .toString()
      .split('')
      .map((char) {
        int? val = int.tryParse(char);
        return val != null ? arabicDigits[val] : char;
      })
      .join('');
}

String getArabicHijriMonthName(int hMonth) {
  const months = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];
  if (hMonth >= 1 && hMonth <= 12) {
    return months[hMonth - 1];
  }
  return '';
}
