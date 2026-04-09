const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");

initializeApp();

const db = getFirestore();

/**
 * Removes tokens that FCM reports as invalid so future sends don't retry them.
 */
async function cleanupStaleTokens(uid, staleTokens) {
  if (!staleTokens.length) return;
  try {
    await db.collection("profiles").doc(uid).update({
      fcmTokens: require("firebase-admin/firestore").FieldValue.arrayRemove(staleTokens),
    });
  } catch (e) {
    console.warn("Failed to clean stale tokens for", uid, e.message);
  }
}

/**
 * Sends a notification to every device token stored on a user's profile.
 * Returns silently when the user has no tokens.
 */
async function sendToUser(uid, notification, data) {
  const profileSnap = await db.collection("profiles").doc(uid).get();
  if (!profileSnap.exists) return;

  const tokens = profileSnap.data().fcmTokens;
  if (!Array.isArray(tokens) || tokens.length === 0) return;

  const message = {
    notification,
    data: data || {},
    tokens,
  };

  const response = await getMessaging().sendEachForMulticast(message);

  const stale = [];
  response.responses.forEach((resp, idx) => {
    if (
      !resp.success &&
      resp.error &&
      (resp.error.code === "messaging/registration-token-not-registered" ||
        resp.error.code === "messaging/invalid-registration-token")
    ) {
      stale.push(tokens[idx]);
    }
  });
  await cleanupStaleTokens(uid, stale);
}

// ---------------------------------------------------------------------------
// 1. Buddy request created → notify the recipient
// ---------------------------------------------------------------------------
exports.onBuddyRequestCreated = onDocumentCreated(
  "petBuddyRequests/{requestId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    const { fromOwnerId, toOwnerId } = data;
    if (!fromOwnerId || !toOwnerId) return;

    const senderSnap = await db.collection("profiles").doc(fromOwnerId).get();
    const senderName = senderSnap.exists
      ? senderSnap.data().displayName || "Someone"
      : "Someone";

    await sendToUser(
      toOwnerId,
      {
        title: "New Paw Buddy Request!",
        body: `${senderName}'s pet wants to be buddies with yours!`,
      },
      {
        type: "buddy_request",
        requestId: event.params.requestId,
      },
    );
  },
);

// ---------------------------------------------------------------------------
// 2. Buddy request accepted → notify the original sender
// ---------------------------------------------------------------------------
exports.onBuddyRequestUpdated = onDocumentUpdated(
  "petBuddyRequests/{requestId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;

    if (before.status === "pending" && after.status === "accepted") {
      const { fromOwnerId, toOwnerId } = after;
      if (!fromOwnerId || !toOwnerId) return;

      const accepterSnap = await db.collection("profiles").doc(toOwnerId).get();
      const accepterName = accepterSnap.exists
        ? accepterSnap.data().displayName || "A pet parent"
        : "A pet parent";

      await sendToUser(
        fromOwnerId,
        {
          title: "Paw Buddy Request Accepted!",
          body: `${accepterName} accepted your buddy request!`,
        },
        {
          type: "buddy_accepted",
          requestId: event.params.requestId,
        },
      );
    }
  },
);

// ---------------------------------------------------------------------------
// 3. Direct message created → notify the other participant
// ---------------------------------------------------------------------------
exports.onDirectMessageCreated = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    const { fromUid, body, isShout } = data;
    if (!fromUid || !body) return;

    const convSnap = await db
      .collection("conversations")
      .doc(event.params.conversationId)
      .get();
    if (!convSnap.exists) return;

    const participants = convSnap.data().participants || [];
    const recipientUids = participants.filter((uid) => uid !== fromUid);
    if (recipientUids.length === 0) return;

    const senderSnap = await db.collection("profiles").doc(fromUid).get();
    const senderName = senderSnap.exists
      ? senderSnap.data().displayName || "A friend"
      : "A friend";

    const preview = body.length > 100 ? body.substring(0, 100) + "…" : body;
    const title = isShout
      ? `📢 ${senderName} shouted`
      : `${senderName}`;

    for (const recipientUid of recipientUids) {
      await sendToUser(
        recipientUid,
        { title, body: preview },
        {
          type: isShout ? "shout" : "direct_message",
          conversationId: event.params.conversationId,
          fromUid,
        },
      );
    }
  },
);

// ---------------------------------------------------------------------------
// 4. Party invite created → notify the invited guest
// ---------------------------------------------------------------------------
exports.onPartyInviteCreated = onDocumentCreated(
  "partyInvites/{inviteId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    const { hostId, guestId, meetupTitle } = data;
    if (!hostId || !guestId) return;

    const hostSnap = await db.collection("profiles").doc(hostId).get();
    const hostName = hostSnap.exists
      ? hostSnap.data().displayName || "Someone"
      : "Someone";

    const title = meetupTitle || "a party";

    await sendToUser(
      guestId,
      {
        title: "Party Invitation!",
        body: `${hostName} invited you to ${title}`,
      },
      {
        type: "party_invite",
        inviteId: event.params.inviteId,
      },
    );
  },
);

// ---------------------------------------------------------------------------
// 5. Party invite accepted → notify the host
// ---------------------------------------------------------------------------
exports.onPartyInviteUpdated = onDocumentUpdated(
  "partyInvites/{inviteId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;

    if (before.status === "pending" && after.status === "accepted") {
      const { hostId, guestId, meetupTitle } = after;
      if (!hostId || !guestId) return;

      const guestSnap = await db.collection("profiles").doc(guestId).get();
      const guestName = guestSnap.exists
        ? guestSnap.data().displayName || "A friend"
        : "A friend";

      const title = meetupTitle || "your party";

      await sendToUser(
        hostId,
        {
          title: "Invite Accepted!",
          body: `${guestName} is coming to ${title}`,
        },
        {
          type: "party_invite_accepted",
          inviteId: event.params.inviteId,
        },
      );
    }
  },
);

// ---------------------------------------------------------------------------
// 6. Stripe – create a PaymentIntent for party hosting fees
// ---------------------------------------------------------------------------
const VALID_PRODUCTS = {
  party_host_regular: 399,
  party_host_biz_small: 999,
  party_host_biz_medium: 1999,
  party_host_biz_large: 2999,
};

exports.createPaymentIntent = onCall(
  { secrets: [stripeSecretKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to continue.");
    }

    const { productId } = request.data;
    const amount = VALID_PRODUCTS[productId];
    if (!amount) {
      throw new HttpsError("invalid-argument", `Unknown product: ${productId}`);
    }

    const stripe = require("stripe")(stripeSecretKey.value());

    const customer = await stripe.customers.create({
      metadata: { firebaseUid: request.auth.uid },
    });

    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customer.id },
      { apiVersion: "2024-12-18.acacia" },
    );

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency: "usd",
      customer: customer.id,
      metadata: {
        firebaseUid: request.auth.uid,
        productId,
      },
    });

    return {
      clientSecret: paymentIntent.client_secret,
      ephemeralKey: ephemeralKey.secret,
      customerId: customer.id,
    };
  },
);
