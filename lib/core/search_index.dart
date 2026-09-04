class SearchIndex {
  final Map<String,String> _items = {};
  void index(String id,String text) => _items[id]=text.toLowerCase();
  List<String> search(String query) {
    final q=query.toLowerCase().trim();
    if(q.isEmpty)return _items.keys.toList();
    return _items.entries.where((e)=>e.value.contains(q)).map((e)=>e.key).toList();
  }
  void remove(String id)=>_items.remove(id);
  void clear()=>_items.clear();
}
