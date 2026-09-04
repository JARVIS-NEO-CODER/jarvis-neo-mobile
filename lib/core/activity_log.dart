class JarvisActivityLog {
  final int maxEntries;
  final List<Map<String,dynamic>> entries=[];
  JarvisActivityLog({this.maxEntries=500});
  void add(String category,String action,{Map<String,dynamic> meta=const {}}){entries.insert(0,{'at':DateTime.now().toIso8601String(),'category':category,'action':action,'meta':meta});if(entries.length>maxEntries)entries.removeLast();}
  List<Map<String,dynamic>> filter({String? category,String? query})=>entries.where((e){final okCat=category==null||e['category']==category;final q=query?.toLowerCase();final okQ=q==null||e.toString().toLowerCase().contains(q);return okCat&&okQ;}).toList();
}
