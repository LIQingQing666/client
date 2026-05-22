import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// ---------- PERSISTENCE ----------

// Resolve the project root directory reliably.
// In dart_frog dev, Platform.script is .dart_frog/server.dart (2 levels up = project root).
// In production or when that fails, fall back to Directory.current.
String _resolveProjectRoot() {
  try {
    final scriptDir = Directory(Platform.script.toFilePath()).parent;
    // In dart_frog dev, scriptDir is .dart_frog/ — go up one more to get project root
    if (scriptDir.path.endsWith('.dart_frog') || scriptDir.path.endsWith('.dart_frog/')) {
      return scriptDir.parent.path;
    }
    return scriptDir.path;
  } catch (_) {
    return Directory.current.path;
  }
}

final _projectRoot = _resolveProjectRoot();
final _dataDir = Directory('$_projectRoot/data');

void _loadAll() {
  if (!_dataDir.existsSync()) return;

  _readList('users.json', _users);
  _readList('videos.json', _videos);
  _readList('products.json', _products);
  _readList('comments.json', _comments);
  _readList('orders.json', _orders);

  final cartsFile = File('${_dataDir.path}/carts.json');
  if (cartsFile.existsSync()) {
    final decoded = jsonDecode(cartsFile.readAsStringSync()) as Map<String, dynamic>;
    _carts.clear();
    decoded.forEach((k, v) {
      _carts[k] = (v as List).cast<Map<String, dynamic>>();
    });
  }

  final likesFile = File('${_dataDir.path}/video_likes.json');
  if (likesFile.existsSync()) {
    final decoded = jsonDecode(likesFile.readAsStringSync()) as Map<String, dynamic>;
    _videoLikes.clear();
    decoded.forEach((k, v) {
      _videoLikes[k] = Set<String>.from(v as List);
    });
  }

  final metaFile = File('${_dataDir.path}/_meta.json');
  if (metaFile.existsSync()) {
    final meta = jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
    _nextCommentId = meta['nextCommentId'] as int;
    _nextCartItemId = meta['nextCartItemId'] as int;
    _nextOrderId = meta['nextOrderId'] as int;
  }
}

void _readList(String filename, List<Map<String, dynamic>> target) {
  final file = File('${_dataDir.path}/$filename');
  if (file.existsSync()) {
    final list = (jsonDecode(file.readAsStringSync()) as List).cast<Map<String, dynamic>>();
    target.clear();
    target.addAll(list);
  }
}

/// Manually persist all data to disk. Called automatically every 3 seconds,
/// but can also be called explicitly after critical writes.
void persist() {
  _persist();
}

void _persist() {
  try {
    if (!_dataDir.existsSync()) {
      _dataDir.createSync(recursive: true);
    }
    File('${_dataDir.path}/users.json').writeAsStringSync(jsonEncode(_users));
    File('${_dataDir.path}/videos.json').writeAsStringSync(jsonEncode(_videos));
    File('${_dataDir.path}/products.json').writeAsStringSync(jsonEncode(_products));
    File('${_dataDir.path}/comments.json').writeAsStringSync(jsonEncode(_comments));
    File('${_dataDir.path}/orders.json').writeAsStringSync(jsonEncode(_orders));
    File('${_dataDir.path}/carts.json').writeAsStringSync(jsonEncode(_carts));

    final serializableLikes = <String, List<String>>{};
    _videoLikes.forEach((k, v) {
      serializableLikes[k] = v.toList();
    });
    File('${_dataDir.path}/video_likes.json').writeAsStringSync(jsonEncode(serializableLikes));

    File('${_dataDir.path}/_meta.json').writeAsStringSync(jsonEncode({
      'nextCommentId': _nextCommentId,
      'nextCartItemId': _nextCartItemId,
      'nextOrderId': _nextOrderId,
    }));
  } catch (e, stack) {
    print('[persist] ERROR: $e');
    print('[persist] STACK: $stack');
  }
}

/// ---------- SEED DATA ----------

final List<Map<String, dynamic>> _users = [
  {
    'userId': 'u1',
    'username': 'alice',
    'password': '123456',
    'nickname': 'Alice',
    'avatar': 'https://example.com/avatars/alice.png',
    'token': 'token-u1-abc123',
  },
  {
    'userId': 'u2',
    'username': 'bob',
    'password': '123456',
    'nickname': 'Bob',
    'avatar': 'https://example.com/avatars/bob.png',
    'token': 'token-u2-def456',
  },
];

final List<Map<String, dynamic>> _videos = [
  {
    'videoId': 'v1',
    'title': '春季新品开箱测评',
    'cover': 'https://example.com/covers/v1.png',
    'playUrl': 'https://example.com/videos/v1.mp4',
    'likeCount': 128,
    'commentCount': 32,
    'userId': 'u1',
    'createdAt': '2026-05-01T10:00:00Z',
  },
  {
    'videoId': 'v2',
    'title': '夏日穿搭指南',
    'cover': 'https://example.com/covers/v2.png',
    'playUrl': 'https://example.com/videos/v2.mp4',
    'likeCount': 256,
    'commentCount': 64,
    'userId': 'u1',
    'createdAt': '2026-05-10T14:00:00Z',
  },
  {
    'videoId': 'v3',
    'title': '厨房好物推荐',
    'cover': 'https://example.com/covers/v3.png',
    'playUrl': 'https://example.com/videos/v3.mp4',
    'likeCount': 89,
    'commentCount': 18,
    'userId': 'u2',
    'createdAt': '2026-05-15T09:30:00Z',
  },
];

final List<Map<String, dynamic>> _products = [
  {
    'productId': 'p1',
    'title': '复古牛仔夹克',
    'description': '高品质复古水洗牛仔夹克，春秋必备单品',
    'images': [
      'https://example.com/products/p1_1.png',
      'https://example.com/products/p1_2.png',
    ],
    'price': 299.00,
    'originalPrice': 599.00,
    'stock': 100,
    'categoryId': 'c1',
    'specs': [
      {'name': '颜色', 'values': ['蓝色', '黑色']},
      {'name': '尺码', 'values': ['S', 'M', 'L', 'XL']},
    ],
    'salesCount': 520,
  },
  {
    'productId': 'p2',
    'title': '纯棉T恤',
    'description': '100%新疆长绒棉，亲肤透气',
    'images': [
      'https://example.com/products/p2_1.png',
      'https://example.com/products/p2_2.png',
    ],
    'price': 89.00,
    'originalPrice': 159.00,
    'stock': 500,
    'categoryId': 'c1',
    'specs': [
      {'name': '颜色', 'values': ['白色', '黑色', '灰色']},
      {'name': '尺码', 'values': ['S', 'M', 'L', 'XL', 'XXL']},
    ],
    'salesCount': 2300,
  },
  {
    'productId': 'p3',
    'title': '运动跑鞋',
    'description': '轻量缓震，适合日常跑步训练',
    'images': [
      'https://example.com/products/p3_1.png',
      'https://example.com/products/p3_2.png',
    ],
    'price': 459.00,
    'originalPrice': 799.00,
    'stock': 200,
    'categoryId': 'c2',
    'specs': [
      {'name': '颜色', 'values': ['黑白', '蓝白', '全黑']},
      {'name': '尺码', 'values': ['38', '39', '40', '41', '42', '43']},
    ],
    'salesCount': 890,
  },
  {
    'productId': 'p4',
    'title': '智能手表',
    'description': '心率监测、血氧检测、运动追踪，7天续航',
    'images': [
      'https://example.com/products/p4_1.png',
      'https://example.com/products/p4_2.png',
    ],
    'price': 899.00,
    'originalPrice': 1299.00,
    'stock': 50,
    'categoryId': 'c3',
    'specs': [
      {'name': '颜色', 'values': ['黑色', '银色', '玫瑰金']},
    ],
    'salesCount': 340,
  },
  {
    'productId': 'p5',
    'title': '不锈钢保温杯',
    'description': '316不锈钢内胆，12小时保温',
    'images': [
      'https://example.com/products/p5_1.png',
      'https://example.com/products/p5_2.png',
    ],
    'price': 79.00,
    'originalPrice': 129.00,
    'stock': 300,
    'categoryId': 'c4',
    'specs': [
      {'name': '容量', 'values': ['350ml', '500ml', '750ml']},
      {'name': '颜色', 'values': ['白色', '粉色', '蓝色']},
    ],
    'salesCount': 1500,
  },
  {
    'productId': 'p6',
    'title': '蓝牙降噪耳机',
    'description': 'ANC主动降噪，40小时续航，Hi-Res音质',
    'images': [
      'https://example.com/products/p6_1.png',
      'https://example.com/products/p6_2.png',
    ],
    'price': 349.00,
    'originalPrice': 699.00,
    'stock': 80,
    'categoryId': 'c3',
    'specs': [
      {'name': '颜色', 'values': ['黑色', '白色', '蓝色']},
    ],
    'salesCount': 670,
  },
  {
    'productId': 'p7',
    'title': '日式拉面碗套装',
    'description': '釉下彩陶瓷，4只装，微波炉可用',
    'images': [
      'https://example.com/products/p7_1.png',
    ],
    'price': 68.00,
    'originalPrice': 108.00,
    'stock': 150,
    'categoryId': 'c4',
    'specs': [
      {'name': '规格', 'values': ['4只装', '6只装', '8只装']},
    ],
    'salesCount': 420,
  },
];

final List<Map<String, dynamic>> _comments = [
  {
    'commentId': 'c1',
    'userId': 'u2',
    'targetType': 'video',
    'targetId': 'v1',
    'content': '这个视频拍得真好，学到了很多！',
    'createdAt': '2026-05-15T09:00:00Z',
  },
  {
    'commentId': 'c2',
    'userId': 'u1',
    'targetType': 'video',
    'targetId': 'v1',
    'content': '谢谢分享，已下单！',
    'createdAt': '2026-05-15T10:30:00Z',
  },
  {
    'commentId': 'c3',
    'userId': 'u2',
    'targetType': 'product',
    'targetId': 'p1',
    'content': '质量很好，颜色和图片一致',
    'createdAt': '2026-05-16T14:00:00Z',
  },
  {
    'commentId': 'c4',
    'userId': 'u1',
    'targetType': 'product',
    'targetId': 'p1',
    'content': '尺码偏大，建议买小一号',
    'createdAt': '2026-05-17T08:20:00Z',
  },
];

final Map<String, List<Map<String, dynamic>>> _carts = {
  'u1': [
    {
      'itemId': 'ci1',
      'productId': 'p1',
      'userId': 'u1',
      'quantity': 2,
      'spec': {'颜色': '蓝色', '尺码': 'M'},
      'selected': true,
    },
    {
      'itemId': 'ci2',
      'productId': 'p3',
      'userId': 'u1',
      'quantity': 1,
      'spec': {'颜色': '黑白', '尺码': '41'},
      'selected': true,
    },
    {
      'itemId': 'ci3',
      'productId': 'p5',
      'userId': 'u1',
      'quantity': 1,
      'spec': {'容量': '500ml', '颜色': '白色'},
      'selected': false,
    },
  ],
  'u2': [
    {
      'itemId': 'ci4',
      'productId': 'p2',
      'userId': 'u2',
      'quantity': 3,
      'spec': {'颜色': '黑色', '尺码': 'L'},
      'selected': true,
    },
  ],
};

final List<Map<String, dynamic>> _orders = [
  {
    'orderId': 'o1',
    'userId': 'u1',
    'items': [
      {
        'productId': 'p2',
        'title': '纯棉T恤',
        'image': 'https://example.com/products/p2_1.png',
        'price': 89.00,
        'quantity': 2,
        'spec': {'颜色': '白色', '尺码': 'M'},
      },
    ],
    'totalAmount': 178.00,
    'paidAmount': 158.00,
    'status': 'completed',
    'addressId': 'addr1',
    'createdAt': '2026-05-18T10:00:00Z',
    'paidAt': '2026-05-18T10:05:00Z',
  },
  {
    'orderId': 'o2',
    'userId': 'u1',
    'items': [
      {
        'productId': 'p4',
        'title': '智能手表',
        'image': 'https://example.com/products/p4_1.png',
        'price': 899.00,
        'quantity': 1,
        'spec': {'颜色': '黑色'},
      },
    ],
    'totalAmount': 899.00,
    'paidAmount': 899.00,
    'status': 'pending_delivery',
    'addressId': 'addr1',
    'createdAt': '2026-05-20T15:00:00Z',
    'paidAt': '2026-05-20T15:02:00Z',
  },
];

final Map<String, Set<String>> _videoLikes = {
  'v1': {'u2'},
};

int _nextCommentId = 5;
int _nextCartItemId = 5;
int _nextOrderId = 3;

/// ---------- ACCESSORS ----------

List<Map<String, dynamic>> get users => _users;
List<Map<String, dynamic>> get videos => _videos;
List<Map<String, dynamic>> get products => _products;
List<Map<String, dynamic>> get comments => _comments;
Map<String, List<Map<String, dynamic>>> get carts => _carts;
List<Map<String, dynamic>> get orders => _orders;
Map<String, Set<String>> get videoLikes => _videoLikes;

/// ---------- USER HELPERS ----------

Map<String, dynamic>? findUserByToken(String? token) {
  if (token == null || token.isEmpty) return null;
  try {
    return _users.firstWhere((u) => u['token'] == token);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? findUserByUsername(String username) {
  try {
    return _users.firstWhere((u) => u['username'] == username);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? findUserById(String userId) {
  try {
    return _users.firstWhere((u) => u['userId'] == userId);
  } catch (_) {
    return null;
  }
}

String generateToken(String userId) {
  final random = Random().nextInt(999999);
  return 'token-$userId-$random';
}

Map<String, dynamic> sanitizeUser(Map<String, dynamic> user) {
  final safe = Map<String, dynamic>.from(user);
  safe.remove('password');
  return safe;
}

/// ---------- PRODUCT HELPERS ----------

Map<String, dynamic>? findProductById(String productId) {
  try {
    return _products.firstWhere((p) => p['productId'] == productId);
  } catch (_) {
    return null;
  }
}

/// ---------- VIDEO HELPERS ----------

Map<String, dynamic>? findVideoById(String videoId) {
  try {
    return _videos.firstWhere((v) => v['videoId'] == videoId);
  } catch (_) {
    return null;
  }
}

/// ---------- CART HELPERS ----------

List<Map<String, dynamic>> getCartForUser(String userId) {
  return _carts.putIfAbsent(userId, () => []);
}

Map<String, dynamic>? findCartItem(String userId, String itemId) {
  final cart = getCartForUser(userId);
  try {
    return cart.firstWhere((item) => item['itemId'] == itemId);
  } catch (_) {
    return null;
  }
}

String nextCartItemId() {
  return 'ci${_nextCartItemId++}';
}

/// ---------- COMMENT HELPERS ----------

String nextCommentId() {
  return 'c${_nextCommentId++}';
}

/// ---------- ORDER HELPERS ----------

String nextOrderId() {
  return 'o${_nextOrderId++}';
}

Map<String, dynamic>? findOrderById(String orderId) {
  try {
    return _orders.firstWhere((o) => o['orderId'] == orderId);
  } catch (_) {
    return null;
  }
}

/// ---------- PAGINATION HELPERS ----------

Map<String, dynamic> paginate(List<Map<String, dynamic>> items, int page, int pageSize) {
  final total = items.length;
  final start = (page - 1) * pageSize;
  final end = start + pageSize;
  final paged = (start >= total) ? <Map<String, dynamic>>[] : items.sublist(start, end.clamp(0, total));
  return {
    'list': paged,
    'total': total,
    'page': page,
    'pageSize': pageSize,
    'totalPages': (total / pageSize).ceil(),
  };
}

/// ---------- RESPONSE HELPERS ----------

Map<String, dynamic> successBody(dynamic data, {String message = 'success'}) {
  return {
    'code': 200,
    'message': message,
    'data': data,
  };
}

Map<String, dynamic> errorBody(int code, String message) {
  return {
    'code': code,
    'message': message,
    'data': null,
  };
}

/// ---------- INIT ----------

bool _initialized = false;

bool _init() {
  if (_initialized) return true;
  _initialized = true;
  _loadAll();
  _persist(); // initial save — also creates the data directory
  Timer.periodic(const Duration(seconds: 3), (_) => _persist());
  return true;
}

final _initDone = _init();
