import 'package:uuid/uuid.dart';

import 'busy_block.dart';
import 'lesson.dart';

const _uuid = Uuid();

/// A friend whose timetable we compare against.
///
/// In local/demo mode the friend's lessons live on-device. When the cloud
/// backend is enabled the same shape is stored in Firestore (see
/// `lib/data/cloud/firestore_data_store.dart`) and kept in sync.
class Friend {
  final String id;
  final String displayName;
  final String friendCode;
  final List<Lesson> lessons;
  final bool included; // included in "who's free" comparisons
  final List<BusyBlock> busyBlocks; // one-off busy overrides
  /// True when [lessons] are fabricated sample data (offline placeholder for
  /// a raw friend-code add). Real data arrives via a WRF1- share import or,
  /// once enabled, the cloud lookup — both reset this to false.
  final bool demoData;

  const Friend({
    required this.id,
    required this.displayName,
    required this.friendCode,
    this.lessons = const [],
    this.included = true,
    this.busyBlocks = const [],
    this.demoData = false,
  });

  Friend copyWith({
    String? displayName,
    String? friendCode,
    List<Lesson>? lessons,
    bool? included,
    List<BusyBlock>? busyBlocks,
    bool? demoData,
  }) {
    return Friend(
      id: id,
      displayName: displayName ?? this.displayName,
      friendCode: friendCode ?? this.friendCode,
      lessons: lessons ?? this.lessons,
      included: included ?? this.included,
      busyBlocks: busyBlocks ?? this.busyBlocks,
      demoData: demoData ?? this.demoData,
    );
  }

  List<Lesson> lessonsOn(int weekday) {
    final list = lessons.where((l) => l.weekday == weekday).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));
    return list;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'friendCode': friendCode,
        'lessons': lessons.map((l) => l.toJson()).toList(),
        'included': included,
        'busyBlocks': busyBlocks.map((b) => b.toJson()).toList(),
        'demoData': demoData,
      };

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
        id: json['id'] as String? ?? _uuid.v4(),
        displayName: json['displayName'] as String? ?? 'Friend',
        friendCode: (json['friendCode'] as String? ?? '').toUpperCase(),
        lessons: ((json['lessons'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Lesson.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        included: json['included'] as bool? ?? true,
        busyBlocks: ((json['busyBlocks'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => BusyBlock.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        // Old backups predate the flag: friends created from raw codes were
        // always demo data, while share-imported ones set it explicitly.
        demoData: json['demoData'] as bool? ??
            ((json['id'] as String?)?.startsWith('demo-') ?? false),
      );
}
