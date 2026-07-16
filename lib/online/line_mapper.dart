/// Maps the website's CSS `line_N` class to actual Tehran metro line numbers.
///
/// The official metro.tehran.ir site uses CSS classes `line_1` through `line_10`
/// that do NOT match the physical metro line numbers. This function translates.
int cssLineToMetroLine(int cssLine) {
  switch (cssLine) {
    case 1:
      return 1;
    case 4:
      return 2;
    case 5:
      return 3;
    case 6:
      return 4;
    case 7:
      return 5;
    case 8:
      return 6;
    case 9:
      return 7;
    case 10:
      return 8;
    default:
      // Fallback: assume the website numbering shifted by 2 for lines 2+.
      return cssLine >= 4 ? cssLine - 2 : cssLine;
  }
}
