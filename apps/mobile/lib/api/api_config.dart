class ApiConfig {
  const ApiConfig({
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000',
    ),
  });

  final String baseUrl;
}
