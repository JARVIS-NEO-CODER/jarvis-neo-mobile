enum FileCapability { read, create, edit, convert, analyze, compare }
class FileCapabilities {
  static const supported = <FileCapability>[
    FileCapability.read, FileCapability.create, FileCapability.edit,
    FileCapability.convert, FileCapability.analyze, FileCapability.compare,
  ];
  static const extensions = <String>['pdf','docx','xlsx','pptx','csv','txt','md','json','jpg','jpeg','png','webp'];
}
