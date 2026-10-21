import { NotFoundException } from '@nestjs/common';
import { GroupMember } from '@prisma/client';
import { PrismaService } from '../../core/prisma/prisma.service';

/**
 * Throws 404 unless `userId` belongs to `groupId`.
 * 404 (not 403) so non-members cannot even learn that a private squad exists.
 */
export async function assertGroupMember(
  prisma: PrismaService,
  userId: string,
  groupId: string,
): Promise<GroupMember> {
  const member = await prisma.groupMember.findUnique({
    where: { userId_groupId: { userId, groupId } },
  });
  if (!member) throw new NotFoundException('Group not found');
  return member;
}
