class JarvisProfile {
  String id;
  String name;
  final Map<String,bool> categories;
  JarvisProfile({required this.id,required this.name,Map<String,bool>? categories}) : categories=categories??{};
  bool allows(String category)=>categories[category]??false;
}
