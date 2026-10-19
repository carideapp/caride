# Native Google Cloud Static IP Setup for Firebase Cloud Functions
## CaRide (Project: `caride-app` | Region: `us-east1`)

This guide routes all TransactPay outbound API calls from Firebase Cloud Functions through a **dedicated static public IPv4 address** inside your existing Google Cloud project (`caride-app`), with **no external VPS to maintain or separate credit cards required**.

---

### Step 1: Open Google Cloud Shell

1. Open your browser and go to:
   👉 **[https://console.cloud.google.com/?project=caride-app](https://console.cloud.google.com/?project=caride-app)**
2. In the top right navigation bar, click the **Activate Cloud Shell** icon (`>_` button).
3. A terminal window will open at the bottom of your browser with `gcloud` already logged into your project.

---

### Step 2: Run These 4 Commands in Cloud Shell

#### 1. Reserve a Dedicated Static External IPv4 Address
```bash
gcloud compute addresses create transactpay-static-ip \
    --region=us-east1 \
    --project=caride-app
```

#### 2. Print Your Static IP Address (Copy this for TransactPay!)
```bash
gcloud compute addresses describe transactpay-static-ip \
    --region=us-east1 \
    --project=caride-app \
    --format="value(address)"
```
> 📋 **Your Provisioned Static Public IPv4**: `34.73.230.91` — this is your dedicated static IP to send to TransactPay.

#### 3. Create Cloud Router & Cloud NAT Gateway
```bash
# Create the router
gcloud compute routers create transactpay-router \
    --network=default \
    --region=us-east1 \
    --project=caride-app

# Create the Cloud NAT attached to your static IP
gcloud compute routers nats create transactpay-nat \
    --router=transactpay-router \
    --region=us-east1 \
    --nat-all-subnet-ip-ranges \
    --nat-external-ip-pool=transactpay-static-ip \
    --project=caride-app
```

#### 4. Enable VPC Access API & Create Serverless VPC Connector
```bash
# Enable Serverless VPC Access API
gcloud services enable vpcaccess.googleapis.com --project=caride-app

# Create the connector (takes ~2 minutes)
gcloud compute networks vpc-access connectors create transactpay-connector \
    --region=us-east1 \
    --network=default \
    --range=10.8.0.0/28 \
    --min-instances=2 \
    --max-instances=3 \
    --machine-type=e2-micro \
    --project=caride-app
```

---

### Step 3: Enable the Connector in Firebase

1. In your local [`apps/caride/functions/.env`](file:///c:/Users/Administrator/Desktop/CaRide/caride/apps/caride/functions/.env), set:
```env
VPC_CONNECTOR=transactpay-connector
```

2. Deploy the functions:
```bash
cd apps/caride/functions
npm run build
firebase deploy --only functions
```

---

### Step 4: Submit the Static IP to TransactPay

Send the static IP printed in Step 2 to TransactPay:

```text
Subject: Production IP Whitelisting Request - CaRide

Hello TransactPay Support Team,

Please whitelist our dedicated production server static IPv4 address for all API calls:

- Merchant Name: CaRide
- Merchant ID: [Your TransactPay Merchant ID]
- Dedicated Outbound Static IPv4: 34.73.230.91
- Integration Endpoints: Payment Link Creation (/payment/create), Bank Transfer Orders (/payment/order/*), Status Verification (/payment/order/status), Name Enquiry (/payout/name-enquiry), and Payout Transfers (/payout/initiate).

All outbound requests from our production Cloud Functions will originate exclusively from this static IP address.

Thank you,
CaRide Engineering Team
```
