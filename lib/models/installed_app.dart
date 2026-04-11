class InstalledApp {
  final String packageName;
  final String label;

  const InstalledApp({
    required this.packageName,
    required this.label,
  });

  factory InstalledApp.fromPackage(String packageName) {
    final parts = packageName.split('.');
    return InstalledApp(
      packageName: packageName,
      label: parts.isEmpty ? packageName : parts.last,
    );
  }
}
