# CaRide Project Documentation & SOFTWARE REQUIREMENTS SPECIFICATION (SRS)
**Ride-Hailing System (Uber / InDrive Hybrid Model)**

## 1. SYSTEM OVERVIEW
A real-time ride-hailing platform that enables:
- Ride requests with dynamic price negotiation (bidding system).
- System suggests price range based on demand.
- Driver discovery and matching.
- Secure in-app payments (wallet + card + crypto).
- Real-time trip tracking.
- Fraud prevention and enforcement mechanisms.

## 2. SYSTEM COMPONENTS
### 2.1 Applications
- **Customer Mobile App** (Flutter)
- **Driver Mobile App** (Flutter)
- **Admin Dashboard** (Web)
- **Backend API Server** (Firebase)

## 3. USER ROLES
### 3.1 Customer
- Requests rides.
- System suggests price range based on demand.
- Sets their preferred ride price (with a minimum price range similar to how other ride-hailing apps calculate and display theirs).
- Pays for rides.
- Rates drivers.

### 3.2 Driver
- Accepts or negotiates ride requests.
- Completes trips.
- Earns income.

### 3.3 Admin
- Oversees platform operations.
- Manages users, rides, and finances.
- Handles fraud monitoring.

## 4. CORE SYSTEM FEATURES

### 4.1 AUTHENTICATION & USER MANAGEMENT
- Email/Phone registration
- OTP verification
- Secure login/logout
- Password reset
- Role-based access (Customer / Driver / Admin)
- Profile management

### 4.2 RIDE REQUEST & MATCHING SYSTEM
**Ride Creation:**
- Input pickup & destination.
- Calculate distance (Map API).
- Display route preview.

**BIDDING SYSTEM (CRITICAL FEATURE):**
- Customer sets initial price.
- Ride request broadcast to nearby drivers.
- Drivers can:
  - Accept price
  - Submit counter-offer

**Bid Flow:**
- Time-limited bidding window (e.g., 30–60 seconds).
- Customer receives multiple offers.
- Customer selects preferred driver.

### 4.3 REAL-TIME TRACKING
- Live driver location updates.
- Route tracking via map API.
- Driver ETA calculation.
- **Status updates:**
  - Requested
  - Bidding
  - Accepted
  - Driver En Route
  - Ride Started
  - Ride Completed

### 4.4 RIDE EXECUTION FLOW
**Driver:**
- Navigate to pickup.
- Start ride (required in-app action).
- End ride (required in-app action).

**Customer:**
- Track ride in real-time.
- Receive ride completion confirmation.

### 4.5 PAYMENT SYSTEM
**Supported Methods:**
- Wallet
- Saved Card

**Wallet System:**
- Wallet balance tracking.
- Fund wallet via:
  - Card
  - Bank transfer
  - Crypto (USDT)

**Payment Flow:**
- Payment held until ride completion.
- Auto-deduct from wallet or card.
- Transaction logging.

### 4.6 DRIVER SYSTEM
- Driver onboarding & verification.
- Vehicle registration.
- Online/offline toggle.
- Ride acceptance/counter system.

**Driver Ranking System:**
Based on:
- Completed rides
- Ratings
- Acceptance rate
- Cancellation rate

**Driver Incentives (ADVANCED):**
- Ranking (Silver, Gold, Diamond, Platinum) based on total completed rides and ratings.
- Benefits include lower commission deduction percentages depending on ranking.

### 4.7 CUSTOMER SYSTEM
- Ride history
- Favorite locations
- Saved payment methods
- Ratings & reviews

### 4.8 COMMUNICATION SYSTEM
- In-app chat
- Masked phone calling
- **Notifications:**
  - Push notifications
  - Email

### 4.9 ADMIN DASHBOARD
**User Management:**
- View/edit customers & drivers.
- Driver approval system.

**Ride Management:**
- Real-time ride tracking.
- Ride logs.

**Financial Management:**
- Transactions overview.
- Commission tracking.
- Wallet monitoring.

**Fraud Monitoring Dashboard:**
- Flag suspicious accounts.
- Monitor cancellations.
- Behavior tracking.

## 5. ANTI-FRAUD SYSTEM (CRITICAL)
To prevent off-platform transactions, a ride must be:
- Started in-app.
- Ended in-app.
- Payment is only released after ride completion.

**Fraud Detection Rules (Track):**
- Frequent cancellations after driver acceptance.
- Ride drop-offs without completion.

**Enforcement:**
- Temporary suspension
- Reduced visibility
- Account blocking

## 6. NOTIFICATION SYSTEM
**Push notifications:**
- New ride request
- Bid updates
- Driver arrival
- Ride completion

**Mail notifications:**
- New ride request
- Driver arrival 
- Ride completion 

## 7. ADVANCED FEATURES (FULL SYSTEM)
### 7.1 Promo & Referral System
- Referral codes (customers get N100 when their referrals make their first booking).

### 7.2 Surge Pricing
- System suggests price range based on demand.

### 7.4 SOS / Emergency System
- Emergency button during ride.
- Share trip with contacts.

### 7.5 Analytics Engine
- User behavior tracking.
- Ride demand analysis.

### 7.6 AI Fraud Detection (Advanced)
- Pattern recognition for suspicious activity.

## 8. NON-FUNCTIONAL REQUIREMENTS
**Performance:**
- Real-time updates (< 2 seconds delay)
- High availability

**Scalability:**
- Support for thousands of concurrent users

**Security:**
- Encrypted data transmission (HTTPS)
- Secure authentication
- Payment compliance

## 9. SYSTEM ARCHITECTURE
- **Frontend:** Flutter (Customer & Driver Apps)
- **Backend:** Node.js / Firebase
- **Database:** Firestore / MongoDB
- **Real-Time System:** WebSockets / Firebase Realtime
- **Maps:** Google Maps API
- **Payments:** Paystack / Stripe / Crypto API

## 10. DATA MODELS (ABSTRACT)
**User:**
- `id`
- `role`
- `profile_data`
- `wallet_balance`

**Driver:**
- `id`
- `vehicle_info`
- `rating`
- `stats`

**Ride:**
- `id`
- `customer_id`
- `driver_id`
- `price`
- `status`
- `timestamps`

**Bid:**
- `ride_id`
- `driver_id`
- `offered_price`
- `timestamp`

**Transaction:**
- `id`
- `amount`
- `method`
- `status`

## 11. SYSTEM CONSTRAINTS
- Mobile-first architecture
- Real-time dependency
- Third-party APIs required
