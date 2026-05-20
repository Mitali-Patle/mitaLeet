import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../../core/prisma/prisma.service';
import { EventsGateway, WS_EVENTS } from '../../core/events/events.gateway';
import { NotificationType } from '@prisma/client';
import * as admin from 'firebase-admin';

@Injectable()
export class NotificationsService implements OnModuleInit {
  private readonly logger = new Logger(NotificationsService.name);
  private fcmEnabled = false;

  constructor(
    private prisma: PrismaService,
    private events: EventsGateway,
  ) {}

  onModuleInit() {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const privateKey = process.env.FIREBASE_PRIVATE_KEY;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;

    if (
      !projectId ||
      !privateKey ||
      !clientEmail ||
      projectId.startsWith('your-') ||
      clientEmail.includes('your-project')
    ) {
      this.logger.warn('Firebase env vars not set — FCM push disabled');
      return;
    }

    try {
      if (admin.apps.length === 0) {
        admin.initializeApp({
          credential: admin.credential.cert({
            projectId,
            privateKey: privateKey.replace(/\\n/g, '\n'),
            clientEmail,
          }),
        });
      }

      this.fcmEnabled = true;
      this.logger.log('Firebase Admin initialized — FCM push enabled');
    } catch (err) {
      this.logger.warn(`Firebase init failed — FCM push disabled: ${err}`);
    }
  }

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

    this.events.emitToUser(userId, WS_EVENTS.NOTIFICATION, notification);

    if (this.fcmEnabled) {
      await this.sendPushNotification(userId, title, body, data);
    }

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

  private async sendPushNotification(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, unknown>,
  ) {
    const tokens = await this.prisma.deviceToken.findMany({
      where: { userId },
      select: { token: true },
    });
    if (tokens.length === 0) return;

    const stringData: Record<string, string> = {};
    if (data) {
      for (const [k, v] of Object.entries(data)) {
        stringData[k] = String(v);
      }
    }

    try {
      const result = await admin.messaging().sendEachForMulticast({
        tokens: tokens.map((t) => t.token),
        notification: { title, body },
        data: stringData,
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default', badge: 1 } } },
      });

      const failed = result.responses.filter((r) => !r.success);
      if (failed.length > 0) {
        this.logger.warn(`FCM: ${failed.length}/${tokens.length} messages failed`);
      }
    } catch (err) {
      this.logger.error(`FCM sendEachForMulticast error: ${err}`);
    }
  }
}
