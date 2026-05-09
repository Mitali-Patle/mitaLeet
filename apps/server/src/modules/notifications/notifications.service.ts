import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../core/prisma/prisma.service';
import { EventsGateway, WS_EVENTS } from '../../core/events/events.gateway';
import { NotificationType } from '@prisma/client';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private prisma: PrismaService,
    private events: EventsGateway,
  ) {}

  /** Create a notification and push via WebSocket + FCM. */
  async create(
    userId: string,
    type: NotificationType,
    title: string,
    body: string,
    data?: Record<string, unknown>,
  ) {
    const notification = await this.prisma.notification.create({
      data: { userId, type, title, body, data: (data ?? undefined) as any },
    });

    // Realtime push via WebSocket
    this.events.emitToUser(userId, WS_EVENTS.NOTIFICATION, notification);

    // TODO: Send FCM push notification to device tokens
    // await this.sendPushNotification(userId, title, body, data);

    return notification;
  }

  /** Get notifications for a user. */
  async getByUser(userId: string, limit = 50) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  /** Mark a notification as read. */
  async markRead(userId: string, notificationId: string) {
    return this.prisma.notification.updateMany({
      where: { id: notificationId, userId },
      data: { read: true },
    });
  }

  /** Mark all notifications as read. */
  async markAllRead(userId: string) {
    return this.prisma.notification.updateMany({
      where: { userId, read: false },
      data: { read: true },
    });
  }

  /** Get unread count. */
  async getUnreadCount(userId: string) {
    return this.prisma.notification.count({
      where: { userId, read: false },
    });
  }

  // ── FCM Push (placeholder) ─────────────────────────────────────────

  // private async sendPushNotification(
  //   userId: string,
  //   title: string,
  //   body: string,
  //   data?: Record<string, unknown>,
  // ) {
  //   const tokens = await this.prisma.deviceToken.findMany({
  //     where: { userId },
  //     select: { token: true },
  //   });
  //   if (tokens.length === 0) return;
  //
  //   // Use firebase-admin messaging.sendEachForMulticast(...)
  // }
}
