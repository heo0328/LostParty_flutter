class NiceGroupPolicyResult {
  const NiceGroupPolicyResult({required this.classNames});

  final Set<String> classNames;

  bool containsClass(String className) =>
      classNames.contains(className.trim().toLowerCase());

  bool get isEmpty => classNames.isEmpty;
}
