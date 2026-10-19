# CaRide Design System & UI Specification

> **Official UI & UX Design Guide for CaRide**
>
> This document specifies the design tokens, visual rules, component standards, typography, geometry, and layout patterns across the entire CaRide application ecosystem (Customer, Driver, and Fleet Manager).

---

## 1. Brand Identity & Color System

### 1.1 Core Brand Colors (CaRide Green)
CaRide's visual identity is built around a vibrant, premium **Emerald Green**. All primary actions, interactive elements, highlights, and active states MUST use CaRide Brand Green.

| Token | Hex Value | Flutter Constant | Usage |
| :--- | :--- | :--- | :--- |
| **Brand Primary** | `#16A34A` | `AppColors.brand` / `Color(0xFF16A34A)` | Primary CTA buttons, active tabs/chips, focus borders, active switches, success emblems |
| **Brand Light / Accent** | `#22C55E` | `AppColors.brandLight` / `Color(0xFF22C55E)` | Light mode active hover, gradient highlights, badges |
| **Brand Dark** | `#15803D` | `AppColors.brandDark` / `Color(0xFF15803D)` | Pressed button state, dark accents |
| **Brand Tint (Soft)** | `#F0FDF4` | `Color(0xFFF0FDF4)` | Selected card background, notification pill backgrounds |

> [!IMPORTANT]
> **External Reference Color Isolation Rule:**
> When recreating layouts from external wireframes or reference mockups (e.g., designs with purple, pink, orange accents), **ALWAYS replace those accents with CaRide Brand Green (`AppColors.brand`)**. Treat reference images exclusively as structural, spatial, and layout guides.

---

### 1.2 Neutral & Surface Colors

#### Light Theme (Default)
| Token | Hex Value | Usage |
| :--- | :--- | :--- |
| **Background** | `#FFFFFF` | Main page background |
| **Surface Alt** | `#F9FAFB` | Section backgrounds, alternate card fills |
| **Input & Pill Fill** | `#F3F4F6` | Text fields, inactive chip fills, search bar backgrounds |
| **Borders & Dividers** | `#E5E7EB` | Hairline dividers, card outlines, subtle borders |
| **Border Secondary** | `#D1D5DB` | Secondary button outlines, unselected radio circles |

#### Dark Theme
| Token | Hex Value | Usage |
| :--- | :--- | :--- |
| **Dark Background** | `#0F172A` | Scaffold background in dark mode |
| **Dark Surface** | `#1E293B` | Cards, bottom sheets, input fills in dark mode |
| **Dark Border** | `#334155` | Hairline dividers and outlines in dark mode |

---

### 1.3 Text & Typography Colors

| Role | Light Theme | Dark Theme | Usage |
| :--- | :--- | :--- | :--- |
| **Text Primary** | `#111827` (Near Black) | `#F9FAFB` (Near White) | Page titles, card headings, primary labels |
| **Text Secondary** | `#6B7280` (Neutral Grey) | `#94A3B8` (Slate Grey) | Subtitles, helper text, descriptions, inactive icons |
| **Text Hint / Muted** | `#9CA3AF` (Light Grey) | `#64748B` | Input placeholders, character counters |
| **Text Interactive** | `#16A34A` (Brand Green) | `#22C55E` | Text links ("Forgot password ?", "Sign Up", "View all") |

---

### 1.4 Status & Feedback Colors

| Status | Primary | Soft Background | Usage |
| :--- | :--- | :--- | :--- |
| **Success** | `#16A34A` | `#DCFCE7` | Completed orders, approved status, success checks |
| **Warning / Pending**| `#F59E0B` | `#FEF3C7` | "Awaiting Pickup", in review, pending verification |
| **Error / Danger** | `#EF4444` | `#FEE2E2` | Validation errors, decline actions, cancellations |
| **Info / Active** | `#0EA5E9` | `#E0F2FE` | Active delivery status, informational alerts |

---

## 2. Geometry, Spacing & Elevation

### 2.1 Corner Radii
CaRide uses a **pill-dominant, modern rounded geometry**:

- **Pill Radius (`28px - 32px`)**:
  - Primary & Secondary Action Buttons (`BorderRadius.circular(28)`)
  - Form Input Fields (`BorderRadius.circular(28)`)
  - Filter & Category Chips (`BorderRadius.circular(24)`)
  - Search Bars (`BorderRadius.circular(28)`)
  - Status Badges & Tags (`BorderRadius.circular(20)`)
- **Card Radius (`20px - 24px`)**:
  - Order cards, address cards, vehicle cards, summary cards
- **Bottom Sheet / Modal Radius (`28px top`)**:
  - `BorderRadius.vertical(top: Radius.circular(28))`
- **Circle (`BoxShape.circle` / `50%`)**:
  - Header back buttons, profile avatars, action icons, badge counter dots

---

### 2.2 Elevation & Shadows
- **Flat & Clean**: Default to flat surfaces with soft `1px` subtle borders (`#E5E7EB` in light mode, `#334155` in dark mode).
- **Floating Modals / Bottom Sheets**:
  ```dart
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 20,
      offset: const Offset(0, -4),
    ),
  ]
  ```

---

### 2.3 Spacing Hierarchy
- **Page Padding**: `20px - 24px` horizontal padding on mobile screens.
- **Section Spacing**: `24px - 32px` between distinct functional sections.
- **Field Spacing**: `16px - 20px` vertical space between form inputs.
- **Label to Input**: `8px` vertical gap.
- **Inner Card Padding**: `16px - 20px`.

---

## 3. Typography Hierarchy

| Level | Size | Weight | Line Height | Usage |
| :--- | :--- | :--- | :--- | :--- |
| **Display / Header 1** | `28px - 32px` | `700` (Bold) | `1.2` | Screen titles ("Welcome Back", "Create Account") |
| **Header 2** | `22px - 24px` | `700` (Bold) | `1.3` | Section headings, bottom sheet titles |
| **Header 3 / Card Title**| `16px - 18px` | `600` (SemiBold) | `1.3` | Card headers, restaurant/driver names, list titles |
| **Form Label** | `14px` | `600` (SemiBold) | `1.2` | Labels above input fields |
| **Body Large** | `15px - 16px` | `400` / `500` | `1.4` | Primary body text, descriptions |
| **Body Medium / Subtitle**| `13px - 14px` | `400` / `500` | `1.4` | Subtitles, addresses, helper text |
| **Button Text** | `15px - 16px` | `600` (SemiBold) | `1.0` | CTA button labels |
| **Badge / Caption** | `11px - 12px` | `500` / `600` | `1.2` | Status tags, countdowns, timestamps |
| **Price / Number Display**| `18px - 24px` | `700` (Bold) | `1.2` | Currency values (`₦12,450`, `₦450.00`) |

---

## 4. Component Standards

### 4.1 Header & Top App Bar
- **Standard Back Button**:
  - Circular white container (`44x44px`) with subtle border `Border.all(color: Color(0xFFE5E7EB))`.
  - Icon: `Icons.arrow_back` or `Icons.arrow_back_ios_new_rounded` (`size: 20`, color: primary text).
- **Centered Title**: Clean, bold text (`18px - 20px`, `FontWeight.w600`).
- **Trailing Action**: Notification bell, heart/favorite icon, or action button inside a matching circular container.

```dart
Row(
  children: [
    Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
      ),
      child: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: primaryTextColor),
        onPressed: () => context.pop(),
      ),
    ),
    Expanded(
      child: Text(
        'Screen Title',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: primaryTextColor),
      ),
    ),
    const SizedBox(width: 44), // Balances header
  ],
)
```

---

### 4.2 Form Text Fields (Pill Input)
- **Top Label**: 14px SemiBold text (`#1F2937` / `#F9FAFB`).
- **Input Container**:
  - Height: `52px - 56px`
  - Border Radius: `BorderRadius.circular(28)`
  - Background: `#F3F4F6` (light) / `AppColors.darkSurface` (dark)
  - Content Padding: `EdgeInsets.symmetric(horizontal: 22, vertical: 16)`
  - Default Border: `BorderSide.none`
  - Focused Border: `BorderSide(color: AppColors.brand, width: 1.5)`
  - Placeholder / Hint: `#9CA3AF` (`fontSize: 14`)

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      'Email / Phone Number',
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelColor),
    ),
    const SizedBox(height: 8),
    TextFormField(
      controller: controller,
      style: TextStyle(color: primaryTextColor, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Enter email or phone number',
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
      ),
    ),
  ],
)
```

---

### 4.3 Action Buttons (CTAs)

#### Primary CTA (Brand Green Pill)
- Full width, height `54px - 56px`, `borderRadius: BorderRadius.circular(28)`
- Background: `AppColors.brand` (`#16A34A`), text white, `fontSize: 16, fontWeight: FontWeight.w600`.
- Loading State: Centered white circular spinner (`strokeWidth: 2.5`).

```dart
SizedBox(
  width: double.infinity,
  height: 56,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    onPressed: isLoading ? null : onSubmit,
    child: isLoading
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
          )
        : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
  ),
)
```

#### Secondary / Outlined Button (e.g. Google Sign-In, Decline)
- Full width, height `54px - 56px`, `borderRadius: BorderRadius.circular(28)`
- Background: White (light) / Dark Surface (dark)
- Border: `BorderSide(color: Color(0xFFD1D5DB), width: 1.2)`

---

### 4.4 Filter & Category Chips
- **Selected**: Background `AppColors.brand` (`#16A34A`), text white, `FontWeight.w600`.
- **Unselected**: Background `#F3F4F6` (or white with `#E5E7EB` outline), text `#6B7280`.
- Padding: `EdgeInsets.symmetric(horizontal: 18, vertical: 10)`.
- Shape: `RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))`.

---

### 4.5 Cards & List Items
- **Border Radius**: `20px - 24px`.
- **Background**: White (or `#F0FDF4` tint when selected/active).
- **Border**: `Border.all(color: Color(0xFFE5E7EB), width: 1.0)`.
- **Selected State**: Border `Border.all(color: AppColors.brand, width: 1.5)`.

---

### 4.6 Success & Confirmation Modals
- **Top Drag Indicator**: Grey rounded bar (`width: 48, height: 4, borderRadius: 2, color: Color(0xFFD1D5DB)`).
- **Emblem / Icon**: Scalloped star rosette badge (`64x64px` or `72x72px`) in `AppColors.brand` (`#16A34A`) with white checkmark.
- **Title**: Large bold centered text (`24px, FontWeight.w700`).
- **Subtitle**: Neutral grey centered description (`15px, color: Color(0xFF6B7280)`).
- **Action**: Full-width primary pill button ("Back to Login", "Track Order", "Continue").

---

### 4.7 Bottom Navigation Bar
- **Height**: `64px - 72px` with safe area padding.
- **Background**: Pure white (light) / `#0F172A` (dark) with top hairline border (`#E5E7EB`).
- **Items**: 5 items (Home, Activity/Orders, Messages/Support, Wallet, Profile).
- **Active Item**: Icon & label in `AppColors.brand` (`#16A34A`), filled icon style.
- **Inactive Item**: Icon & label in `#9CA3AF` / `#6B7280`.

---

### 4.8 Error Banners & Visual Feedback
- **In-View Error Banner**:
  - Position: At the top of the form / immediately below the top header.
  - Shape: `borderRadius: BorderRadius.circular(18)`
  - Colors: `#FEF2F2` (light) / `AppColors.error.withValues(alpha: 0.15)` (dark) with `Border.all(color: AppColors.error.withValues(alpha: 0.35), width: 1.2)`
  - Content: Circular error badge icon, bold *"Action Required"* headline, friendly explanation text, and dismiss (`X`) button.
- **Floating Error SnackBar**:
  - Concurrently trigger a floating `AppColors.error` SnackBar (`borderRadius: BorderRadius.circular(16)`) with icon and clear guidance for immediate feedback when scrolled.

---

## 5. Profile & Account Sub-System Standards

The CaRide Profile Sub-System (Passenger Account, Driver Profile, and Fleet Manager Profile) follows a clean, minimalist iOS-inspired layout designed for high scannability, zero visual clutter, and consistent interaction patterns:

### 5.1 Profile Header Architecture
- **Centered Circular Avatar**:
  - Size: `96x96px` container with circular shape (`BoxShape.circle`).
  - Border: `1.5px` subtle border (`#E5E7EB` in light mode, `AppColors.glassBorderDark` in dark mode).
  - Background: Soft neutral `#F3F4F6` (light) / `AppColors.darkSurface` (dark).
  - Tap Behavior: Tapping the avatar directly opens the profile detail / photo editor screen.
- **Display Name**:
  - Large bold typography: `20px`, `FontWeight.w700`, letter spacing `-0.3`.
  - Margin: `16px` vertical gap below the avatar.
- **Secondary Subtitle**:
  - Single-line muted text (`13px`, `#6B7280` light / `AppColors.textSecondaryDark` dark) displaying user phone number or email.

### 5.2 Grouped Card Structure
- **Container Geometry**:
  - Large rounded corners: `BorderRadius.circular(24)`.
  - Background: Pure white `#FFFFFF` (light) / `AppColors.darkSurface` (dark).
  - Border: `1px` subtle outline (`#E5E7EB` light / `AppColors.glassBorderDark` dark).
  - Vertical spacing between card groups: `20px`.
  - No decorative glows, drop shadows, or multi-colored gradients.
- **Clean Grouping (No Verbose Headers)**:
  - Menu cards are grouped by functional domain (e.g. Finances, Preferences, Activity, Session) without cluttering uppercase section headers.

### 5.3 Menu List Items (`_ProfileMenuItem`)
- **Single-Line Minimalist Items**:
  - Do not add subtitle descriptions or multi-line helper text under menu titles in profile cards.
  - Height / Padding: `EdgeInsets.symmetric(horizontal: 18, vertical: 14)`.
  - Ripple Shape: `BorderRadius.circular(20)`.
- **Leading Icon Badge**:
  - Uniform neutral circle: `40x40px`, `BoxShape.circle`.
  - Fill: Soft neutral `#F3F4F6` (light) / `Colors.white10` (dark).
  - Icon: `20px`, neutral color `#374151` (light) / `Colors.white70` (dark).
  - *Exception*: Destructive items (e.g. Sign Out) use `#EF4444` icon with `AppColors.error.withValues(alpha: 0.1)` background.
- **Title**:
  - Clean font: `15px`, `FontWeight.w600`, letter spacing `-0.2`.
- **Accent Badges & Trailing**:
  - Badges: Pill chip (`BorderRadius.circular(12)`), padding `horizontal: 10, vertical: 4` (e.g. wallet balance `₦518,050`, tier `GOLD`, verified status).
  - Trailing Icon: `Icons.chevron_right_rounded`, `22px`, `#9CA3AF`. (Hidden on destructive actions).
- **Hairline Inset Dividers**:
  - Inset from the left by `68px` (aligning with menu item text) and `18px` from the right.
  - Height: `1px`, color `#F3F4F6` (light) / `Colors.white10` (dark).

### 5.4 Sub-Screen Detail & Form Standards
- **Top App Bar**:
  - Circular back button: `44x44px`, `BoxShape.circle`, thin border (`#E5E7EB`).
  - Centered title: `18px - 20px`, `FontWeight.w700`.
- **Form Inputs**:
  - Pill shape: `BorderRadius.circular(28)`.
  - Fill: `#F3F4F6` (light) / `AppColors.darkSurface` (dark).
  - Content padding: `EdgeInsets.symmetric(horizontal: 22, vertical: 18)`.
- **Action Buttons**:
  - Full-width pill: `54px - 56px` height, `BorderRadius.circular(28)`, `AppColors.brand`.
- **Destructive Actions & Confirmations**:
  - Outlined button with label (no icon-only trash buttons).
  - Confirmation modals MUST use `showModalBottomSheet` with `BorderRadius.vertical(top: Radius.circular(28))`, drag handle, tinted alert circle, bold title, body, and full-width pill confirm button. Never use `AlertDialog`.

---

## 6. Admin Dashboard Web Design System (`apps/admin_dashboard`)

The CaRide Admin Dashboard adapts the clean, pill-dominant geometry and emerald brand identity to an enterprise web administrative console inspired by the `admin_UI` reference layouts:

### 6.1 Layout Shell & Dark Floating Sidebar
- **Sidebar Presentation**: Dark deep forest background (`#0A1610` in light mode, `#0B0F19` in dark mode) with rounded outer geometry (`border-radius: 20px` or floating curved rail) and clean section groupings (`MAIN`, `DRIVERS`, `FLEET PARTNERS`, `CUSTOMERS`, `FINANCE`).
- **Active Navigation Pill**: Active item is rendered as a crisp, solid white pill (`background: #FFFFFF`, text: `#0F172A`, `border-radius: 9999px`), giving ultra-high visual contrast against the dark sidebar.
- **Top Greeting & Header**: Contextual greeting ("Good Morning, [Name]" / "[Page Title]"), page subtext, circular icon buttons (search, notification bell with red pill badge count), and store/system status toggle.

### 6.2 Metric & Stat Cards
- **Solid Dark Metric Cards**: Deep solid brand background (`#064E3B` / `#0B2B1B`), rounded corners (`border-radius: 18px-20px`), white high-contrast numerical metrics, and top-right circular icon badge (`40x40px`) with subtle semi-transparent background (`rgba(255, 255, 255, 0.15)`).
- **Hero Gradient Wallet Card**: Large promotional/balance card (`background: linear-gradient(135deg, #064E3B 0%, #059669 100%)`, `border-radius: 24px`), visibility eye toggle, and a full-pill white action button (`[Request Payout]`).

### 6.3 Modern Tables & Status Badges
- **Table Container**: Large rounded card container (`border-radius: 20px-24px`), subtle border (`#E5E7EB`), soft light grey header background (`#F9FAFB`), and generous row padding.
- **Entity Thumbnails**: Thumbnail preview images with rounded corners (`12px-14px`) alongside bold titles and secondary metadata.
- **Pill Status Badges**: Soft pastel pill badges (`border-radius: 9999px`, padding `4px 12px`, `font-size: 12px`, `font-weight: 600`):
  - Paid / Approved / Success: Soft green (`#DCFCE7`, text `#16A34A`)
  - Pending / Review: Soft amber (`#FEF3C7`, text `#D97706`)
  - New / Info: Soft blue (`#DBEAFE`, text `#2563EB`)
  - Cancelled / Danger: Soft red (`#FEE2E2`, text `#DC2626`)
- **Pagination Footer**: Summary text ("Showing 1 to 8 of 129 items") on the left, circular pagination arrow buttons (`<` and `>`), and active page in a solid dark circle.

### 6.4 Pill Controls & Form Fields
- **Filter Toolbar**: Date range pill `[📅 This month ⌄]`, sort pill `[⇅ Sort by: Latest ⌄]`, pill search bar with leading icon (`border-radius: 9999px`), and export button.
- **Forms**: Full pill inputs (`border-radius: 9999px`), soft neutral fill, leading icon, and password visibility toggle.
- **Tags & Category Chips**: Rounded pill chips with trailing dismiss `x` icon (`border-radius: 9999px`).

---

## 7. Screen Implementation Checklist

When building or updating any screen in CaRide:
1. [ ] **Color Fidelity**: Use `AppColors.brand` (`#16A34A`) for all primary actions, active tabs, focus borders, and links. Never leave foreign mockup colors (e.g. purple/pink).
2. [ ] **Pill Shapes**: Ensure all primary buttons and text fields use `borderRadius: BorderRadius.circular(28)` (or `9999px` in web).
3. [ ] **Input Styling**: Soft grey `#F3F4F6` background, borderless default with `AppColors.brand` focus border.
4. [ ] **Card Geometry**: Use `20px - 24px` rounded corners with subtle `#E5E7EB` outlines.
5. [ ] **Profile Standards**: Follow the 96×96 avatar, 24px grouped cards, 40×40 neutral icon badges, and single-line menu item standard.
6. [ ] **Dark Mode Support**: Ensure every component supports both light theme and dark theme gracefully.
7. [ ] **Error Handling & Feedback**: Translate all exception codes to friendly messages, and display dual immediate visual feedback (in-view banner + floating snackbar).
8. [ ] **Validation & Verification**: Run `flutter analyze` across all workspace apps and verify web builds with `npm run build`.



