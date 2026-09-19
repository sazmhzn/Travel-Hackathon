import { describe, it, expect } from 'vitest';
import { FeedService } from '../src/modules/feed/feed.service.js';

describe('FeedService Spatial Queries & Privacy Filters', () => {
  it('should filter activities by spatial radius and privacy status', async () => {
    // Center point: Kathmandu Durbar Square (85.3076, 27.7042)
    const centerLat = 27.7042;
    const centerLng = 85.3076;

    // 1. Nearby public activity (~500 meters away)
    const nearbyPublic = await FeedService.createActivity({
      userId: 'user-1',
      title: 'Kathmandu Heritage Coffee',
      visibility: 'PUBLIC',
      lat: 27.7050,
      lng: 85.3080,
      mediaUrls: ['https://minio.local/travel-media/uploads/coffee.jpg'],
    });

    // 2. Far public activity (~150km away in Pokhara: 83.9856, 28.2096)
    await FeedService.createActivity({
      userId: 'user-2',
      title: 'Pokhara Lakeside Boating',
      visibility: 'PUBLIC',
      lat: 28.2096,
      lng: 83.9856,
      mediaUrls: ['https://minio.local/travel-media/uploads/boat.jpg'],
    });

    // 3. Nearby private group activity (~1km away)
    const secretGroupActivity = await FeedService.createActivity({
      userId: 'user-3',
      groupId: 'secret-group-alpha',
      title: 'Secret Base Camp Meeting',
      visibility: 'GROUP_ONLY',
      lat: 27.7060,
      lng: 85.3090,
    });

    // Case A: Query within 5km radius without group membership
    const publicFeed = await FeedService.getSpatialFeed({
      lat: centerLat,
      lng: centerLng,
      radiusMeters: 5000,
      userGroupIds: [],
    });

    const publicIds = publicFeed.activities.map((a) => a.id);
    expect(publicIds).toContain(nearbyPublic.id);
    expect(publicIds).not.toContain(secretGroupActivity.id); // Privacy filter works!

    // Far activity should NOT be included in 5km radius
    expect(publicFeed.activities.some((a) => a.title.includes('Pokhara'))).toBe(false);

    // Case B: Query with membership in 'secret-group-alpha'
    const groupMemberFeed = await FeedService.getSpatialFeed({
      lat: centerLat,
      lng: centerLng,
      radiusMeters: 5000,
      userGroupIds: ['secret-group-alpha'],
    });

    const memberIds = groupMemberFeed.activities.map((a) => a.id);
    expect(memberIds).toContain(nearbyPublic.id);
    expect(memberIds).toContain(secretGroupActivity.id); // Included for authorized group member!
  });
});
