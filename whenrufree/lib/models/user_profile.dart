import 'dart:math';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const _codeChars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // no ambiguous chars

String generateFriendCode([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(6, (_) => _codeChars[r.nextInt(_codeChars.length)])
      .join();
}

bool isValidFriendCode(String code) {
  final c = code.trim().toUpperCase();
  if (c.length != 6) return false;
  return c.split('').every(_codeChars.contains);
}

/// The local user's profile.
class UserProfile {
  final String id;
  final String displayName;
  final String friendCode;
  final String college;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.friendCode,
    this.college = '',
  });

  factory UserProfile.fresh({String displayName = ''}) => UserProfile(
        id: _uuid.v4(),
        displayName: displayName,
        friendCode: generateFriendCode(),
      );

  UserProfile copyWith({String? displayName, String? friendCode, String? college}) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      friendCode: friendCode ?? this.friendCode,
      college: college ?? this.college,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'friendCode': friendCode,
        'college': college,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String? ?? _uuid.v4(),
        displayName: json['displayName'] as String? ?? '',
        friendCode: (json['friendCode'] as String? ?? generateFriendCode())
            .toUpperCase(),
        college: json['college'] as String? ?? '',
      );
}
