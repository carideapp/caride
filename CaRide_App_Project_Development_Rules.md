# AI DEVELOPMENT GUIDELINES (FRONTEND – FLUTTER + DESIGN SYSTEM)

## 1. Design Philosophy (NON-NEGOTIABLE)
**Design style:** Minimal, Modern, Clean

**Focus on:**
- Simplicity over complexity
- Clarity over decoration
- Function over noise

**Avoid:**
- Cluttered UI
- Too many colors
- Heavy shadows or gradients everywhere
- Copying InDrive UI directly

👉 *This is inspired by InDrive, not a clone*

## 2. Brand Identity (FROM PROVIDED DESIGN)
**Primary Colors** (From your branding image):
- **Primary Green:** `#16A34A` (main brand color)
- **Dark Green:** `#0B6B2E`
- **Accent Yellow:** `#FACC15`
- **Black/Dark:** `#0F172A`
- **Light Background:** `#F8FAFC`

**Color Usage Rules:**
- **Green** → Primary actions (buttons, highlights)
- **Yellow** → Accent only (NOT dominant)
- **Black/Dark** → Text & strong contrast
- **Light background** → Main UI background

🚫 **DO NOT:**
- Mix random colors
- Overuse yellow
- Use gradients everywhere

## 3. Typography System
**Font:** Clean modern sans-serif (e.g., Inter, SF Pro, or similar)

**Use hierarchy:**
| Type | Usage |
|---|---|
| **Heading** | Bold, large |
| **Subheading** | Medium weight |
| **Body** | Regular |
| **Caption** | Small, subtle |

🚫 *No random font sizes—define in `app_theme.dart`*

## 4. Spacing System (CRITICAL FOR CLEAN UI)
Use consistent spacing scale:
- `4px`
- `8px`
- `12px`
- `16px`
- `24px`
- `32px`

👉 *All padding/margin must follow this scale*

## 5. UI Component Style
**Buttons:**
- Rounded corners (8–12 radius)
- Primary = Green background + white text
- Secondary = Outline or light background
- Flat & clean: strictly NO glowing or ambient shadows on buttons (showShadow = false)

**Cards:**
- Soft elevation or very light shadow
- Rounded corners
- Clean spacing

**Inputs:**
- Minimal borders
- Focus state uses brand green

## 6. Theme Enforcement (STRICT)
- All styling must come from `app_theme.dart`
- Theme must define:
  - Colors
  - Typography
  - Spacing
  - Border radius
  - Navigation components (Bottom Nav / Tabs)
  - Light & Dark mode

🚫 *No hardcoded styles anywhere*

## 6.1 Bottom Navigation (CURRENT DESIGN SPEC — NON-NEGOTIABLE)
The bottom navigation must match the approved UI style (clean, flat, minimal) and be controlled via theme defaults.

**Tab structure (Customer app):**
- `Home`
- `Services`
- `Activity`
- `Account`

**Visual style:**
- **Background**: flat, no gradients
- **Top divider**: subtle 1px separator line
- **No selection pill/indicator**: keep indicator fully transparent
- **Labels always visible**: no “icon-only” mode
- **Icon size**: `24`
- **Label size**: `12`
- **Selected state**: strong contrast (dark in light mode, white in dark mode)
- **Unselected state**: muted opacity (do not introduce new colors)

**Implementation rules:**
- Use Material 3 `NavigationBar` (not a custom-painted nav).
- All styling must come from `NavigationBarThemeData` in `app_theme.dart`.
- Only screen-level allowed addition is the **top border** (divider) wrapper.

## 7. Light & Dark Mode (MANDATORY)
Each screen must:
- Support both modes
- Maintain readability
- Adjust colors properly

*Example:*
- **Light** → white background
- **Dark** → near black background

## 8. Layout Behavior
- Use lots of white space
- Keep UI breathable
- Prioritize:
  - Map view (main feature)
  - Ride actions
  - Clear CTA buttons

## 9. Screen Responsiveness (NON-NEGOTIABLE)
UI must adapt to:
- Small phones
- Large phones
- Tablets

**Use:**
- `MediaQuery`
- `LayoutBuilder`
- Flexible widgets (`Expanded`, `Flexible`)

**Avoid:**
- Fixed widths/heights unless necessary
- Overflow errors

## 10. Animation & Interaction
Keep it subtle and smooth:
- Button tap feedback
- Screen transitions
- Loading indicators

🚫 *No excessive animations*

## 11. UX Principles
- Booking a ride should take minimal steps
- Always show:
  - Current status
  - Clear next action
- *Examples:*
  - "Set your price" → obvious
  - "Choose driver" → simple

## 12. Feature-Based Structure (REINFORCED)
```text
lib/
 ├── core/
 │   ├── theme/
 │   ├── constants/
 │   ├── utils/
 │
 ├── features/
 │   ├── auth/
 │   │    ├── screens/
 │   │    ├── widgets/
 │   
 │   ├── ride/
 │   ├── wallet/
 │   ├── profile/
 │
 ├── shared/
 │   ├── widgets/
 │   ├── components/
```

**Rules:**
- Login & Signup → `features/auth/`
- Each feature must be isolated
- No random files in root

## 13. Reusable Components (DON’T DUPLICATE CODE)
Common UI elements must be reusable:
- Buttons
- Input fields
- Cards
- Modals

**Store in:** `shared/widgets/`
- No repeated UI logic across screens

## 14. Development Focus (PRODUCTION-READY — STRICT)
- **Current phase:** Full Production
- Always build complete end-to-end production implementations, never test/mock fallbacks.
- Live backend integration, cloud functions, webhooks, and real ledger crediting are mandatory.

## 15. Code Reusability & Scalability
- Build robust production code with strict type safety and error handling.
- Real backend API contracts, atomic database transactions, and idempotency.

## 16. Loading & Error States (MANDATORY UX)
Every async UI must handle:
- Loading state (skeleton screens & optimistic UI)
- Error state (user-friendly message)
- Empty state (if no data)

## 17. Form Handling & Validation
All forms must include:
- Input validation
- Error messages
- *No raw TextFields without validation*

## 18. Navigation Structure
- Use a centralized routing system: `core/navigation/`
- Avoid hardcoded navigation everywhere
- The app must support dynamic theme switching (System, Light, Dark) with a focus on high-contrast and premium dark mode (OLED black).

19. **Status Bar Integration**:
- All screens must extend into the status bar area (edge-to-edge).
- Status bar icons and background colors must dynamically update based on the current theme (e.g., dark icons on light theme, light icons on dark theme).

20. **Production-First Implementation Standard (NON-NEGOTIABLE)**:
- **Always implement for live production, never for testing or placeholders.**
- For payment gateways (TransactPay, etc.):
  - Implement the real Cloud Functions connecting through static IP proxy.
  - Build live HTTP Webhook handlers (`onRequest`) to asynchronously credit incoming deposits with signature verification.
  - Execute atomic database transactions (`FieldValue.increment`, transaction receipts, wallet ledgers).
  - Deployable and production-ready from day one.