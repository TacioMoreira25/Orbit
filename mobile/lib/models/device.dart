class Device {
  final String id;
  final String name;
  final String host;
  final int port;
  final String? token;
  final bool isPaired;

  const Device({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.token,
    this.isPaired = false,
  });

  String get baseUrl => 'http://$host:$port';
  String get wsUrl => 'ws://$host:$port/ws';

  Device copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? token,
    bool? isPaired,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      token: token ?? this.token,
      isPaired: isPaired ?? this.isPaired,
    );
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Dispositivo Linux',
      host: json['host'] ?? '127.0.0.1',
      port: json['port'] ?? 3000,
      token: json['token'],
      isPaired: json['isPaired'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'token': token,
      'isPaired': isPaired,
    };
  }
}
