import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Trigger 1: onNewDirectMessage
 * Fires when a new message is added to conversations/{convId}/messages/{msgId}.
 * Sends a push notification to the recipient (the participant who is not the sender).
 */
export const onNewDirectMessage = functions.firestore.onDocumentCreated(
  'conversations/{convId}/messages/{msgId}',
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const messageData = snapshot.data();
    if (messageData.isDeleted) return;

    const senderId = messageData.senderId;
    const convId = event.params.convId;

    // 1. Get the conversation document to find the recipient
    const convDoc = await db.collection('conversations').doc(convId).get();
    if (!convDoc.exists) return;

    const participants = convDoc.data()?.participants || [];
    const recipientId = participants.find((uid: string) => uid !== senderId);

    if (!recipientId) return;

    // 2. Get the sender's display name
    const senderDoc = await db.collection('users').doc(senderId).get();
    const senderName = senderDoc.data()?.displayName || 'Someone';

    // 3. Get the recipient's FCM token
    const recipientDoc = await db.collection('users').doc(recipientId).get();
    const fcmToken = recipientDoc.data()?.fcmToken;

    if (!fcmToken) {
      console.log(`No FCM token for user ${recipientId}`);
      return;
    }

    // 4. Send the notification
    const payload = {
      token: fcmToken,
      notification: {
        title: senderName,
        body: messageData.text?.substring(0, 100) || 'Sent a message',
      },
      data: {
        type: 'direct_message',
        route: '/messages',
        convId: convId,
      },
    };

    try {
      await messaging.send(payload);
      console.log(`Push notification sent to ${recipientId} for conv ${convId}`);
    } catch (error) {
      console.error('Error sending direct message push:', error);
    }
  }
);

/**
 * Trigger 2: onNewSeatRequest
 * Fires when a rider requests a seat.
 * Sends a push notification to the driver.
 */
export const onNewSeatRequest = functions.firestore.onDocumentCreated(
  'schools/{schoolId}/groups/{groupId}/trips/{tripId}/requests/{riderId}',
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const schoolId = event.params.schoolId;
    const groupId = event.params.groupId;
    const tripId = event.params.tripId;
    const riderId = event.params.riderId;

    // 1. Get the trip document to find the driver
    const tripDoc = await db
      .collection('schools')
      .doc(schoolId)
      .collection('groups')
      .doc(groupId)
      .collection('trips')
      .doc(tripId)
      .get();

    if (!tripDoc.exists) return;
    
    const driverId = tripDoc.data()?.driverId;
    if (!driverId) return;

    // 2. Get rider name
    const riderDoc = await db.collection('users').doc(riderId).get();
    const riderName = riderDoc.data()?.displayName || 'Someone';

    // 3. Get driver token
    const driverDoc = await db.collection('users').doc(driverId).get();
    const fcmToken = driverDoc.data()?.fcmToken;

    if (!fcmToken) return;

    const payload = {
      token: fcmToken,
      notification: {
        title: 'New seat request 🚗',
        body: `${riderName} wants to join your trip`,
      },
      data: {
        type: 'seat_request',
        route: '/community',
        schoolId: schoolId,
        groupId: groupId,
        tripId: tripId,
      },
    };

    try {
      await messaging.send(payload);
    } catch (error) {
      console.error('Error sending seat request push:', error);
    }
  }
);

/**
 * Trigger 3: onSeatRequestUpdated
 * Fires when a seat request is accepted or declined.
 * Sends a push notification back to the rider.
 */
export const onSeatRequestUpdated = functions.firestore.onDocumentUpdated(
  'schools/{schoolId}/groups/{groupId}/trips/{tripId}/requests/{riderId}',
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    if (!beforeData || !afterData) return;

    // Only notify if status changed from pending -> accepted/declined
    if (beforeData.status !== 'pending' || afterData.status === 'pending') {
      return;
    }

    const riderId = event.params.riderId;
    const isAccepted = afterData.status === 'accepted';

    const riderDoc = await db.collection('users').doc(riderId).get();
    const fcmToken = riderDoc.data()?.fcmToken;

    if (!fcmToken) return;

    const title = isAccepted ? 'Seat confirmed! 🎉' : 'Seat request update';
    const body = isAccepted
      ? 'Your request to join the trip was accepted'
      : 'Your request to join the trip was not accepted';

    const payload = {
      token: fcmToken,
      notification: { title, body },
      data: {
        type: 'seat_response',
        route: '/community',
        schoolId: event.params.schoolId,
        groupId: event.params.groupId,
        tripId: event.params.tripId,
      },
    };

    try {
      await messaging.send(payload);
    } catch (error) {
      console.error('Error sending seat response push:', error);
    }
  }
);
