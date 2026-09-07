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

## 5. Screen Implementation Checklist

When building or updating any screen in CaRide:
1. [ ] **Color Fidelity**: Use `AppColors.brand` (`#16A34A`) for all primary actions, active tabs, focus borders, and links. Never leave foreign mockup colors (e.g. purple/pink).
2. [ ] **Pill Shapes**: Ensure all primary buttons and text fields use `borderRadius: BorderRadius.circular(28)`.
3. [ ] **Input Styling**: Soft grey `#F3F4F6` background, borderless default with `AppColors.brand` focus border.
4. [ ] **Card Geometry**: Use `20px - 24px` rounded corners with subtle `#E5E7EB` outlines.
5. [ ] **Dark Mode Support**: Ensure every component supports both light theme and dark theme gracefully.
6. [ ] **Error Handling & Feedback**: Translate all exception codes to friendly messages, and display dual immediate visual feedback (in-view banner + floating snackbar).
7. [ ] **Validation & Verification**: Run `flutter analyze` across all workspace apps after any changes.

