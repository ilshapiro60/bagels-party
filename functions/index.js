const crypto = require("crypto");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret, defineString } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");

const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");
const emailOtpHmacSecret = defineSecret("EMAIL_OTP_HMAC_SECRET");
/** Resend API key (https://resend.com). Empty in emulator logs the code instead. */
const resendApiKey = defineString("RESEND_API_KEY", { default: "" });
const resendFrom = defineString("RESEND_FROM", {
  default: "ZumiTok <onboarding@resend.dev>",
});

initializeApp();

const db = getFirestore();

function normalizeEmail(email) {
  if (typeof email !== "string") return "";
  return email.trim().toLowerCase();
}

function isValidEmail(email) {
  const n = normalizeEmail(email);
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(n);
}

function hmacOtpCode(secret, email, code) {
  return crypto.createHmac("sha256", secret).update(`${normalizeEmail(email)}:${code}`).digest("hex");
}

function randomSixDigitString() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

async function sendSignInCodeEmail({ to, code }) {
  const apiKey = resendApiKey.value();
  if (!apiKey) return false;
  const from = resendFrom.value();
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [to],
      subject: "Your ZumiTok sign-in code",
      html:
        `<p style="font-size:16px">Your sign-in code is:</p>` +
        `<p style="font-size:28px;font-weight:700;letter-spacing:8px;font-family:monospace">${code}</p>` +
        `<p style="color:#666;font-size:14px">It expires in 15 minutes. If you did not request this, you can ignore this email.</p>`,
    }),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Resend ${res.status}: ${t}`);
  }
  return true;
}

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
  { secrets: [stripeSecretKey], region: "us-central1" },
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

// ---------------------------------------------------------------------------
// 7. Email sign-in — 6-digit OTP (callable → Resend + custom token)
// ---------------------------------------------------------------------------

exports.requestEmailSignInCode = onCall(
  {
    secrets: [emailOtpHmacSecret],
    region: "us-central1",
    // Pre-auth callables: Cloud Run must allow the Firebase client to invoke the URL.
    invoker: "public",
    // Do not require App Check here — debug builds often lack a registered token;
    // console "enforce" for Functions would otherwise block before this handler runs.
    enforceAppCheck: false,
  },
  async (request) => {
    const emailRaw = request.data?.email;
    if (!isValidEmail(emailRaw)) {
      throw new HttpsError("invalid-argument", "Enter a valid email address.");
    }
    const email = normalizeEmail(emailRaw);
    const docRef = db.collection("emailSignInCodes").doc(email);
    const now = Date.now();
    const snap = await docRef.get();
    const d = snap.exists ? snap.data() : {};

    const lastMs = d.lastSentAt?.toMillis?.() ?? 0;
    if (now - lastMs < 60_000) {
      throw new HttpsError(
        "resource-exhausted",
        "Please wait about a minute before requesting another code.",
      );
    }

    let windowStart = d.rateHourStartedAt?.toMillis?.() ?? now;
    let sendCount = d.rateHourSendCount ?? 0;
    if (now - windowStart >= 3_600_000) {
      windowStart = now;
      sendCount = 0;
    }
    if (sendCount >= 5) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many codes were sent to this email. Try again in about an hour.",
      );
    }

    const code = randomSixDigitString();
    const secret = emailOtpHmacSecret.value();
    const codeHash = hmacOtpCode(secret, email, code);

    await docRef.set({
      codeHash,
      expiresAt: Timestamp.fromMillis(now + 15 * 60 * 1000),
      verifyAttempts: 0,
      lastSentAt: FieldValue.serverTimestamp(),
      rateHourStartedAt: Timestamp.fromMillis(windowStart),
      rateHourSendCount: sendCount + 1,
    });

    const emulator = process.env.FUNCTIONS_EMULATOR === "true";
    const apiKey = resendApiKey.value();
    if (emulator && !apiKey) {
      console.log(`[requestEmailSignInCode] ${email} → code ${code} (emulator, no RESEND_API_KEY)`);
    } else if (!apiKey) {
      throw new HttpsError(
        "failed-precondition",
        "Email delivery is not configured. Set the RESEND_API_KEY parameter for Cloud Functions (see Resend.com).",
      );
    } else {
      try {
        await sendSignInCodeEmail({ to: email, code });
      } catch (e) {
        console.error("sendSignInCodeEmail", e);
        throw new HttpsError("internal", "Could not send the email. Try again later.");
      }
    }

    return { ok: true };
  },
);

exports.verifyEmailSignInCode = onCall(
  {
    secrets: [emailOtpHmacSecret],
    region: "us-central1",
    invoker: "public",
    enforceAppCheck: false,
  },
  async (request) => {
    const emailRaw = request.data?.email;
    const codeRaw = request.data?.code;
    const code = typeof codeRaw === "string" ? codeRaw.trim() : String(codeRaw ?? "").trim();
    if (!isValidEmail(emailRaw) || !/^\d{6}$/.test(code)) {
      throw new HttpsError("invalid-argument", "Enter your email and the 6-digit code.");
    }
    const email = normalizeEmail(emailRaw);
    const docRef = db.collection("emailSignInCodes").doc(email);
    const snap = await docRef.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "No active code for this email. Request a new one.");
    }
    const d = snap.data();
    const exp = d.expiresAt?.toMillis?.() ?? 0;
    if (Date.now() > exp) {
      await docRef.delete();
      throw new HttpsError("deadline-exceeded", "That code has expired. Request a new one.");
    }
    const attempts = d.verifyAttempts ?? 0;
    if (attempts >= 8) {
      await docRef.delete();
      throw new HttpsError("permission-denied", "Too many attempts. Request a new code.");
    }

    const expected = d.codeHash;
    const actual = hmacOtpCode(emailOtpHmacSecret.value(), email, code);
    if (actual !== expected) {
      await docRef.update({ verifyAttempts: FieldValue.increment(1) });
      throw new HttpsError("permission-denied", "That code is not valid.");
    }

    await docRef.delete();

    const auth = getAuth();
    let userRecord;
    try {
      userRecord = await auth.getUserByEmail(email);
    } catch (e) {
      const errCode = e.code || e.errorInfo?.code;
      if (errCode === "auth/user-not-found") {
        try {
          userRecord = await auth.createUser({ email, emailVerified: false });
        } catch (createErr) {
          console.error("verifyEmailSignInCode createUser", createErr);
          throw new HttpsError(
            "internal",
            createErr.message || "Could not create an account for this email.",
          );
        }
      } else {
        console.error("verifyEmailSignInCode getUserByEmail", e);
        throw new HttpsError(
          "internal",
          e.message || "Could not look up this email in Authentication.",
        );
      }
    }

    try {
      const customToken = await auth.createCustomToken(userRecord.uid, {
        signInVia: "email_otp",
      });
      return { customToken };
    } catch (e) {
      console.error("verifyEmailSignInCode createCustomToken", e);
      throw new HttpsError(
        "internal",
        e.message || "Could not issue a sign-in token. Check Firebase Auth and IAM for Cloud Functions.",
      );
    }
  },
);
