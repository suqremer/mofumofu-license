// うちの子免許証 Stripe Webhook
//
// 役割（design_document 8.4 / v3）: 決済成功（checkout.session.completed）を受信し、
// 署名検証のうえ Firestore `orders/{受付番号}` に paid=true を記録する「決済の真実」。
// - 受信 → 署名検証 → Firestore 書き込みのみの最小実装（メール送信はしない）。
// - 受付番号は Stripe の client_reference_id（アプリが決済URLに付与）で受け取る。
// - Admin SDK なのでセキュリティルールをバイパスして書き込む。

const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const Stripe = require("stripe");

admin.initializeApp();

// 値はデプロイ前に `firebase functions:secrets:set` で設定する（コードに埋めない）
const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");

exports.stripeWebhook = onRequest(
    {
      region: "us-east1", // Firestore/Storage(US-EAST1)に近接
      secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET],
    },
    async (req, res) => {
      const stripe = new Stripe(STRIPE_SECRET_KEY.value());
      const sig = req.headers["stripe-signature"];

      // 署名検証（Stripe からの正規リクエストであることを確認）
      let event;
      try {
        event = stripe.webhooks.constructEvent(
            req.rawBody, sig, STRIPE_WEBHOOK_SECRET.value());
      } catch (err) {
        logger.error("Stripe署名検証に失敗", {message: err.message});
        res.status(400).send(`Webhook Error: ${err.message}`);
        return;
      }

      // 決済成功イベントのみ処理
      if (event.type === "checkout.session.completed") {
        const session = event.data.object;
        const orderNumber = session.client_reference_id;

        if (!orderNumber) {
          // 受付番号が無い決済は突合できないが、再送ループを避けるため200で返す
          logger.warn("client_reference_id(受付番号)が無い決済", {
            sessionId: session.id,
          });
          res.status(200).send("no order number");
          return;
        }

        try {
          await admin.firestore().collection("orders").doc(orderNumber).set({
            paid: true,
            sessionId: session.id,
            amount: session.amount_total,
            paidAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
          logger.info("決済を記録", {
            orderNumber: orderNumber,
            sessionId: session.id,
          });
        } catch (e) {
          // 5xx を返すと Stripe が再送してくれる
          logger.error("Firestoreへの書き込みに失敗", {
            orderNumber: orderNumber,
            error: String(e),
          });
          res.status(500).send("write failed");
          return;
        }
      }

      // 受領を Stripe に通知（その他のイベントもここで200）
      res.status(200).send("ok");
    },
);
