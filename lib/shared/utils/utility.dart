class PrintUtil {
  static void printMap(final String? title, final Map<String, String> map) {
    String dividerTitle = title ?? '===';
    print('==========================$dividerTitle===============================(START)');
    map.forEach((k, v) => {print('key-> $k : value->$v')});
    print('=============================$dividerTitle===============================(END)');
    print('\n');
  }
}
