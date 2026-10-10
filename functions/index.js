/**
 * CapSync - Firebase Cloud Functions
 * Automatically triggers whenever a notification document is written to Firestore.
 * Dispatches an FCM push notification to the recipient's phone/browser,
 * waking up the device and displaying the notification even if the app is completely closed.
 */

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();

exports.sendPushOnNotificationCreated = onDocumentCreated(
  'notifications/{notificationId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return null;

    const data = snap.data();
    if (!data || !data.recipientUserId) {
      console.log('Skipping push: no recipientUserId found.');
      return null;
    }

    const recipientUserId = data.recipientUserId;
    const title = data.title || 'CapSync Consultation Alert';
    const message = data.message || 'You have an update in CapSync.';
    const type = data.type || 'general';

    // 1. Fetch recipient's registered FCM tokens from Firestore
    try {
      const userDoc = await admin
        .firestore()
        .collection('users')
        .doc(recipientUserId)
        .get();

      if (!userDoc.exists) {
        console.log(`User ${recipientUserId} document does not exist.`);
        return null;
      }

      const userData = userDoc.data();
      const rawTokens = userData.fcmTokens || (userData.fcmToken ? [userData.fcmToken] : []);
      const fcmTokens = Array.isArray(rawTokens)
        ? rawTokens.filter((t) => typeof t === 'string' && t.trim().length > 0)
        : [];

      if (fcmTokens.length === 0) {
        console.log(`No active FCM device tokens registered for user ${recipientUserId}.`);
        return null;
      }

      console.log(`Sending push to ${fcmTokens.length} device(s) for user ${recipientUserId}...`);

      // 2. Build multi-platform push notification payload
      const response = await admin.messaging().sendEachForMulticast({
        tokens: fcmTokens,
        notification: {
          title: title,
          body: message,
        },
        data: {
          notificationId: event.params.notificationId,
          type: type,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'capsync_alerts',
            sound: 'default',
            priority: 'max',
            defaultVibrateTimings: true,
            defaultSound: true,
          },
        },
        webpush: {
          headers: {
            Urgency: 'high',
          },
          notification: {
            title: title,
            body: message,
            icon: 'favicon.png',
            requireInteraction: true,
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: title,
                body: message,
              },
              sound: 'default',
              badge: 1,
            },
          },
        },
      });

      console.log(`FCM results: ${response.successCount} succeeded, ${response.failureCount} failed.`);
      return response;
    } catch (err) {
      console.error('Error in sendPushOnNotificationCreated:', err);
      return null;
    }
  }
);
