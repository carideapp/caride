# UI Rule: Button Styling & Shadows

## Invariants:
1. **No Glowing or Ambient Shadows on Buttons**:
   - Primary action buttons must not have glowing or heavy drop shadow effects (avoid `AppShadows.glowDark` or ambient spread shadows on buttons).
   - `PrimaryButton` defaults to `showShadow = false`. Do not re-enable glowing ambient shadows on standard buttons.
2. **Flat & Clean Aesthetic**:
   - Maintain the minimal, flat design system aesthetic: solid or subtle gradient fill, clean rounded corners (radius 8–12), with crisp contrast.
   - Do not add custom `boxShadow` or elevation to standard buttons unless explicitly requested by the user.
