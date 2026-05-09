import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../core/prisma/prisma.service';
import { EventsGateway, WS_EVENTS } from '../../core/events/events.gateway';
import { SendFriendRequestDto } from './dto/friends.dto';

@Injectable()
export class FriendsService {
  private readonly logger = new Logger(FriendsService.name);

  constructor(
    private prisma: PrismaService,
    private events: EventsGateway,
  ) {}

  /** Send a friend request. */
  async sendRequest(senderId: string, dto: SendFriendRequestDto) {
    if (senderId === dto.receiverId) {
      throw new BadRequestException('Cannot send a friend request to yourself');
    }

    // Check receiver exists
    const receiver = await this.prisma.user.findUnique({
      where: { id: dto.receiverId },
      select: { id: true, displayName: true },
    });
    if (!receiver) throw new NotFoundException('User not found');

    // Check if already friends
    const existing = await this.findFriendship(senderId, dto.receiverId);
    if (existing) throw new ConflictException('Already friends');

    // Check for existing request in either direction
    const existingRequest = await this.prisma.friendRequest.findFirst({
      where: {
        OR: [
          { senderId, receiverId: dto.receiverId, status: 'PENDING' },
          { senderId: dto.receiverId, receiverId: senderId, status: 'PENDING' },
        ],
      },
    });
    if (existingRequest) {
      throw new ConflictException('Friend request already exists');
    }

    const request = await this.prisma.friendRequest.create({
      data: { senderId, receiverId: dto.receiverId },
      include: {
        sender: { select: { id: true, displayName: true, avatarUrl: true } },
      },
    });

    // Realtime notification
    this.events.emitToUser(dto.receiverId, WS_EVENTS.FRIEND_REQUEST_SENT, {
      requestId: request.id,
      sender: request.sender,
    });

    return request;
  }

  /** Accept or decline a friend request. */
  async respondToRequest(
    userId: string,
    requestId: string,
    action: 'ACCEPTED' | 'DECLINED',
  ) {
    const request = await this.prisma.friendRequest.findUnique({
      where: { id: requestId },
      include: {
        sender: { select: { id: true, displayName: true, avatarUrl: true } },
        receiver: { select: { id: true, displayName: true, avatarUrl: true } },
      },
    });

    if (!request || request.receiverId !== userId) {
      throw new NotFoundException('Friend request not found');
    }
    if (request.status !== 'PENDING') {
      throw new BadRequestException('Request already processed');
    }

    await this.prisma.friendRequest.update({
      where: { id: requestId },
      data: { status: action },
    });

    if (action === 'ACCEPTED') {
      // Create bidirectional friendship
      const [userA, userB] = [request.senderId, request.receiverId].sort();
      await this.prisma.friendship.create({
        data: { userAId: userA, userBId: userB },
      });

      // Notify sender
      this.events.emitToUser(request.senderId, WS_EVENTS.FRIEND_REQUEST_ACCEPTED, {
        user: request.receiver,
      });
    }

    return { requestId, action };
  }

  /** Cancel a pending outgoing request. */
  async cancelRequest(userId: string, requestId: string) {
    const request = await this.prisma.friendRequest.findUnique({
      where: { id: requestId },
    });
    if (!request || request.senderId !== userId || request.status !== 'PENDING') {
      throw new NotFoundException('Request not found');
    }
    await this.prisma.friendRequest.delete({ where: { id: requestId } });
  }

  /** Remove a friend. */
  async removeFriend(userId: string, friendId: string) {
    const [userA, userB] = [userId, friendId].sort();
    const friendship = await this.prisma.friendship.findUnique({
      where: { userAId_userBId: { userAId: userA, userBId: userB } },
    });
    if (!friendship) throw new NotFoundException('Friendship not found');
    await this.prisma.friendship.delete({ where: { id: friendship.id } });
  }

  /** Get friend list with presence. */
  async getFriends(userId: string) {
    const friendships = await this.prisma.friendship.findMany({
      where: { OR: [{ userAId: userId }, { userBId: userId }] },
      include: {
        userA: {
          select: { id: true, displayName: true, avatarUrl: true, status: true },
          include: { profile: { select: { username: true, xp: true } } },
        },
        userB: {
          select: { id: true, displayName: true, avatarUrl: true, status: true },
          include: { profile: { select: { username: true, xp: true } } },
        },
      },
    });

    return friendships.map((f) => {
      const friend = f.userAId === userId ? f.userB : f.userA;
      return {
        friendshipId: f.id,
        ...friend,
        isOnline: this.events.isUserOnline(friend.id),
      };
    });
  }

  /** Get pending incoming requests. */
  async getIncomingRequests(userId: string) {
    return this.prisma.friendRequest.findMany({
      where: { receiverId: userId, status: 'PENDING' },
      include: {
        sender: {
          select: { id: true, displayName: true, avatarUrl: true },
          include: { profile: { select: { username: true } } },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /** Get pending outgoing requests. */
  async getOutgoingRequests(userId: string) {
    return this.prisma.friendRequest.findMany({
      where: { senderId: userId, status: 'PENDING' },
      include: {
        receiver: {
          select: { id: true, displayName: true, avatarUrl: true },
          include: { profile: { select: { username: true } } },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /** Search users for friend adding. */
  async searchUsers(userId: string, query: string, limit = 20) {
    const users = await this.prisma.userProfile.findMany({
      where: {
        OR: [
          { username: { contains: query, mode: 'insensitive' } },
          { user: { displayName: { contains: query, mode: 'insensitive' } } },
        ],
        userId: { not: userId },
      },
      include: {
        user: {
          select: { id: true, displayName: true, avatarUrl: true, status: true },
        },
      },
      take: limit,
    });

    // Check friendship status for each result
    const results = await Promise.all(
      users.map(async (profile) => {
        const friendUserId = profile.user.id;
        const friendship = await this.findFriendship(userId, friendUserId);
        const pendingRequest = await this.prisma.friendRequest.findFirst({
          where: {
            OR: [
              { senderId: userId, receiverId: friendUserId, status: 'PENDING' },
              { senderId: friendUserId, receiverId: userId, status: 'PENDING' },
            ],
          },
        });

        return {
          userId: profile.user.id,
          username: profile.username,
          displayName: profile.user.displayName,
          avatarUrl: profile.user.avatarUrl,
          xp: profile.xp,
          isFriend: !!friendship,
          hasPendingRequest: !!pendingRequest,
          requestDirection: pendingRequest
            ? pendingRequest.senderId === userId ? 'sent' : 'received'
            : null,
        };
      }),
    );

    return results;
  }

  /** Get mutual friends between two users. */
  async getMutualFriends(userId: string, otherUserId: string) {
    const myFriends = await this.getFriendIds(userId);
    const theirFriends = await this.getFriendIds(otherUserId);
    const mutualIds = myFriends.filter((id) => theirFriends.includes(id));

    if (mutualIds.length === 0) return [];

    return this.prisma.user.findMany({
      where: { id: { in: mutualIds } },
      select: { id: true, displayName: true, avatarUrl: true },
    });
  }

  // ── Private helpers ─────────────────────────────────────────────

  private async findFriendship(userA: string, userB: string) {
    const [a, b] = [userA, userB].sort();
    return this.prisma.friendship.findUnique({
      where: { userAId_userBId: { userAId: a, userBId: b } },
    });
  }

  private async getFriendIds(userId: string): Promise<string[]> {
    const friendships = await this.prisma.friendship.findMany({
      where: { OR: [{ userAId: userId }, { userBId: userId }] },
      select: { userAId: true, userBId: true },
    });
    return friendships.map((f) =>
      f.userAId === userId ? f.userBId : f.userAId,
    );
  }
}
