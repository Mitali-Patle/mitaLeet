import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

// ── Models ─────────────────────────────────────────────────────────

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.xp,
    required this.totalSolves,
    required this.currentStreak,
    required this.isOnline,
  });

  final String userId;
  final String displayName;
  final String role;
  final int xp;
  final int totalSolves;
  final int currentStreak;
  final bool isOnline;

  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
        userId: j['userId'] ?? '',
        displayName: j['displayName'] ?? '',
        role: j['role'] ?? 'MEMBER',
        xp: j['xp'] ?? 0,
        totalSolves: j['totalSolves'] ?? 0,
        currentStreak: j['currentStreak'] ?? 0,
        isOnline: j['isOnline'] ?? false,
      );
}

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.code,
    required this.memberCount,
    required this.activeMemberCount,
    this.rank,
    required this.members,
  });

  final String id;
  final String name;
  final String code;
  final int memberCount;
  final int activeMemberCount;
  final int? rank;
  final List<GroupMember> members;

  factory Group.fromJson(Map<String, dynamic> j) {
    final members = (j['members'] as List? ?? [])
        .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
        .toList();
    return Group(
      id: j['id'] ?? '',
      name: j['name'] ?? '',
      code: j['code'] ?? '',
      memberCount: members.length,
      activeMemberCount: members.where((m) => m.isOnline).length,
      rank: j['rank'],
      members: members,
    );
  }
}

// ── State ──────────────────────────────────────────────────────────

class GroupsState {
  const GroupsState({
    this.groups = const [],
    this.isLoading = false,
    this.isJoining = false,
    this.isCreating = false,
    this.error,
    this.successMessage,
  });

  final List<Group> groups;
  final bool isLoading;
  final bool isJoining;
  final bool isCreating;
  final String? error;
  final String? successMessage;

  GroupsState copyWith({
    List<Group>? groups,
    bool? isLoading,
    bool? isJoining,
    bool? isCreating,
    String? error,
    String? successMessage,
    bool clearMessages = false,
  }) =>
      GroupsState(
        groups: groups ?? this.groups,
        isLoading: isLoading ?? this.isLoading,
        isJoining: isJoining ?? this.isJoining,
        isCreating: isCreating ?? this.isCreating,
        error: clearMessages ? null : (error ?? this.error),
        successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
      );
}

// ── Notifier ───────────────────────────────────────────────────────

class GroupsNotifier extends StateNotifier<GroupsState> {
  GroupsNotifier(this._api) : super(const GroupsState());

  final ApiClient _api;

  Future<void> loadGroups() async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      final res = await _api.get(ApiEndpoints.groups);
      final data = res.data['data'] as List? ?? [];
      state = state.copyWith(
        groups: data.map((e) => Group.fromJson(e as Map<String, dynamic>)).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load squads: ${_msg(e)}',
      );
    }
  }

  Future<bool> joinGroup(String code) async {
    if (code.trim().isEmpty) return false;
    state = state.copyWith(isJoining: true, clearMessages: true);
    try {
      await _api.post(ApiEndpoints.groupsJoin, data: {'code': code.trim().toUpperCase()});
      await loadGroups();
      state = state.copyWith(isJoining: false, successMessage: 'Joined squad!');
      return true;
    } catch (e) {
      state = state.copyWith(isJoining: false, error: _msg(e));
      return false;
    }
  }

  Future<bool> createGroup(String name, {String? description}) async {
    if (name.trim().isEmpty) return false;
    state = state.copyWith(isCreating: true, clearMessages: true);
    try {
      await _api.post(ApiEndpoints.groups, data: {
        'name': name.trim(),
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      });
      await loadGroups();
      state = state.copyWith(isCreating: false, successMessage: 'Squad created!');
      return true;
    } catch (e) {
      state = state.copyWith(isCreating: false, error: _msg(e));
      return false;
    }
  }

  void clearMessages() => state = state.copyWith(clearMessages: true);

  String _msg(dynamic e) => e.toString().replaceAll('Exception:', '').trim();
}

// ── Provider ───────────────────────────────────────────────────────

final groupsProvider = StateNotifierProvider<GroupsNotifier, GroupsState>((ref) {
  return GroupsNotifier(ref.watch(apiClientProvider));
});
