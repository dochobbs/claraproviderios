# Clara Provider App - Design System

**Version:** 1.0
**Last Updated:** November 8, 2025
**Purpose:** Design specifications for Clara provider dashboard (iOS + Web)

---

## Typography

### Font Family
**Primary:** Rethink Sans
**Fallback:** System rounded font (San Francisco Rounded on iOS, system-ui on Web)

**Available Weights:**
- Regular (400)
- Medium (500)
- SemiBold (600)
- Bold (700)
- ExtraBold (800)

**Download:** [Google Fonts - Rethink Sans](https://fonts.google.com/specimen/Rethink+Sans)

### Font Sizing Scale

| Element | Size | Weight | CSS |
|---------|------|--------|-----|
| Title | 22px | Bold | `font: 700 22px/1.2 'Rethink Sans'` |
| Headline | 17px | Bold | `font: 700 17px/1.3 'Rethink Sans'` |
| Body | 17px | Regular | `font: 400 17px/1.5 'Rethink Sans'` |
| Subheadline | 15px | Regular | `font: 400 15px/1.4 'Rethink Sans'` |
| Caption | 12px | Regular | `font: 400 12px/1.3 'Rethink Sans'` |
| Badge | 12px | Bold | `font: 700 12px/1.2 'Rethink Sans'` |

---

## Color Palette

### Brand Colors

```css
/* Primary accent - coral */
--color-primary-coral: #FF5A33;
--color-primary-coral-rgb: rgb(255, 90, 51);

/* Secondary accent - teal */
--color-flagged-teal: #4ECDC4;
--color-flagged-teal-rgb: rgb(78, 205, 196);
```

### Background Colors (Light Mode)

```css
/* Base layer - warm beige paper texture */
--color-paper-background: #F2EDE0;
--color-paper-background-rgb: rgb(242, 237, 224);

/* User message bubbles - slightly darker beige */
--color-user-bubble: #EFE7D2;
--color-user-bubble-rgb: rgb(239, 231, 210);

/* Cards and elevated surfaces - lighter beige */
--color-secondary-background: #F6F1E2;
--color-secondary-background-rgb: rgb(246, 241, 226);

/* Tertiary layer - more visible separation */
--color-tertiary-background: #F2EDDE;
--color-tertiary-background-rgb: rgb(242, 237, 222);
```

### Background Colors (Dark Mode)

```css
/* Use system defaults for dark mode */
--color-background-dark: #000000;
--color-secondary-background-dark: #1C1C1E;
--color-tertiary-background-dark: #2C2C2E;
```

### Text Colors

```css
/* Light mode text */
--color-text-primary: #333333;
--color-text-primary-rgb: rgb(51, 51, 51);

--color-text-secondary: #666666;
--color-text-secondary-rgb: rgb(102, 102, 102);

/* Dark mode text - use system defaults */
--color-text-primary-dark: #FFFFFF;
--color-text-secondary-dark: #EBEBF5;
```

### Status Colors

```css
/* Pending */
--color-status-pending: #FF9500;
--color-status-pending-rgb: rgb(255, 149, 0);

/* Responded */
--color-status-responded: #4ECDC4;
--color-status-responded-rgb: rgb(78, 205, 196);

/* Escalated */
--color-status-escalated: #FF3B30;
--color-status-escalated-rgb: rgb(255, 59, 48);

/* Dismissed */
--color-status-dismissed: #8E8E93;
--color-status-dismissed-rgb: rgb(142, 142, 147);

/* Flagged indicator (separate from status) */
--color-flag-indicator: #FF9500;
--color-flag-indicator-rgb: rgb(255, 149, 0);
```

### Triage Outcome Colors

```css
/* Emergency - ER/911 */
--color-triage-emergency: #FF3B30;
--color-triage-emergency-rgb: rgb(255, 59, 48);

/* Urgent visit */
--color-triage-urgent: #FF9500;
--color-triage-urgent-rgb: rgb(255, 149, 0);

/* Routine visit */
--color-triage-routine: #FF5A33;
--color-triage-routine-rgb: rgb(255, 90, 51);

/* Home care */
--color-triage-home: #34C759;
--color-triage-home-rgb: rgb(52, 199, 89);
```

---

## Components

### Status Badge

**Purpose:** Shows conversation workflow status
**States:** Pending, Responded, Escalated, Dismissed

```css
.status-badge {
    display: inline-block;
    padding: 4px 8px;
    border-radius: 6px;
    font: 700 12px/1.2 'Rethink Sans';
    color: white;
    text-transform: capitalize;
}

.status-badge--pending {
    background-color: #FF9500;
}

.status-badge--responded {
    background-color: #4ECDC4;
}

.status-badge--escalated {
    background-color: #FF3B30;
}

.status-badge--dismissed {
    background-color: #8E8E93;
}
```

**HTML Example:**
```html
<span class="status-badge status-badge--responded">Responded</span>
```

### Flag Badge

**Purpose:** Indicates conversation is flagged (independent of status)
**Appearance:** Orange flag icon with background

```css
.flag-badge {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 3px 5px;
    border-radius: 4px;
    background-color: #FF9500;
    color: white;
    font-size: 10px;
}

.flag-badge--large {
    padding: 4px 6px;
    font-size: 12px;
}
```

**HTML Example:**
```html
<span class="flag-badge">
    <svg><!-- flag icon --></svg>
</span>
```

### Triage Badge

**Purpose:** Shows triage recommendation with colored background
**States:** ER - Call 911, ER - Drive, Urgent Visit, Routine Visit, Home Care

```css
.triage-badge {
    display: inline-block;
    padding: 4px 8px;
    border-radius: 6px;
    font: 400 12px/1.3 'Rethink Sans';
}

.triage-badge--emergency {
    color: #FF3B30;
    background-color: rgba(255, 59, 48, 0.1);
}

.triage-badge--urgent {
    color: #FF9500;
    background-color: rgba(255, 149, 0, 0.1);
}

.triage-badge--routine {
    color: #FF5A33;
    background-color: rgba(255, 90, 51, 0.1);
}

.triage-badge--home {
    color: #34C759;
    background-color: rgba(52, 199, 89, 0.1);
}
```

### Provider Review Box

**Purpose:** Shows provider response with status-specific styling
**States:** Responded (teal), Escalated (red), Dismissed (gray)

```css
.provider-review {
    padding: 12px;
    border-radius: 16px;
    border: 1px solid;
}

.provider-review--responded {
    background-color: rgba(78, 205, 196, 0.1);
    border-color: rgba(78, 205, 196, 0.3);
}

.provider-review--escalated {
    background-color: rgba(255, 59, 48, 0.1);
    border-color: rgba(255, 59, 48, 0.3);
}

.provider-review--dismissed {
    background-color: rgba(142, 142, 147, 0.1);
    border-color: rgba(142, 142, 147, 0.3);
}

.provider-review__header {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 8px;
}

.provider-review__status {
    font: 700 15px/1.3 'Rethink Sans';
}

.provider-review__timestamp {
    font: 400 12px/1.3 'SF Mono', monospace;
    color: var(--color-text-secondary);
}

.provider-review__content {
    font: 400 14px/1.5 'SF Mono', monospace;
    color: var(--color-text-primary);
}

.provider-review__flag-reason {
    margin-top: 12px;
    padding-top: 12px;
    border-top: 1px solid rgba(0, 0, 0, 0.1);
}

.provider-review__flag-reason-header {
    display: flex;
    align-items: center;
    gap: 6px;
    font: 600 12px/1.3 'SF Mono', monospace;
    color: #FF9500;
    margin-bottom: 6px;
}
```

### Message Bubble

**Purpose:** Chat message display for patient and Clara messages

```css
/* Patient messages - right aligned, beige bubble */
.message-bubble--patient {
    margin-left: auto;
    max-width: 80%;
    padding: 10px 14px;
    background-color: #EFE7D2;
    border-radius: 16px;
    font: 400 17px/1.5 'Rethink Sans';
}

/* Clara messages - left aligned, plain text */
.message-bubble--clara {
    margin-right: auto;
    max-width: 100%;
    font: 400 17px/1.5 'Rethink Sans';
    color: var(--color-text-primary);
}

/* Provider messages - right aligned, coral tint */
.message-bubble--provider {
    margin-left: auto;
    max-width: 80%;
    padding: 12px;
    background-color: rgba(255, 90, 51, 0.2);
    border-radius: 16px;
    font: 400 17px/1.5 'Rethink Sans';
}
```

### Filter Button (Status Tabs)

**Purpose:** Navigation for filtering conversations by status

```css
.filter-button {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    padding: 8px 16px;
    border-radius: 8px;
    background-color: var(--color-secondary-background);
    border: none;
    cursor: pointer;
    transition: background-color 0.2s ease;
}

.filter-button--active {
    background-color: #FF5A33;
    color: white;
}

.filter-button__title {
    font: 400 15px/1.3 'Rethink Sans';
}

.filter-button--active .filter-button__title {
    font-weight: 700;
}

.filter-button__count {
    font: 400 12px/1.2 'Rethink Sans';
}

.filter-button:hover {
    background-color: rgba(255, 90, 51, 0.1);
}

.filter-button--active:hover {
    background-color: #FF5A33;
}
```

### Card Component

**Purpose:** Elevated surface for stats, lists, and content blocks

```css
.card {
    padding: 16px;
    background-color: var(--color-secondary-background);
    border-radius: 12px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
}

.card--dark {
    background-color: var(--color-secondary-background-dark);
}
```

---

## Spacing Scale

Use consistent spacing throughout:

```css
--spacing-xs: 4px;
--spacing-sm: 8px;
--spacing-md: 12px;
--spacing-lg: 16px;
--spacing-xl: 20px;
--spacing-2xl: 24px;
--spacing-3xl: 32px;
```

---

## Border Radius Scale

```css
--radius-sm: 6px;   /* Badges, small buttons */
--radius-md: 8px;   /* Filter buttons */
--radius-lg: 12px;  /* Cards */
--radius-xl: 16px;  /* Message bubbles, review boxes */
```

---

## Shadows

```css
/* Light subtle shadow for cards */
--shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.05);

/* Medium shadow for elevated surfaces */
--shadow-md: 0 2px 8px rgba(0, 0, 0, 0.1);

/* Strong shadow for modals/popups */
--shadow-lg: 0 4px 16px rgba(0, 0, 0, 0.15);
```

---

## Dark Mode Strategy

**Approach:** System-based dark mode with automatic color adaptation

```css
@media (prefers-color-scheme: dark) {
    :root {
        --color-background: var(--color-background-dark);
        --color-secondary-background: var(--color-secondary-background-dark);
        --color-tertiary-background: var(--color-tertiary-background-dark);
        --color-text-primary: var(--color-text-primary-dark);
        --color-text-secondary: var(--color-text-secondary-dark);
    }

    /* Keep brand colors the same in dark mode */
    /* Adjust opacity for better contrast if needed */
}
```

---

## Icon System

**Recommendation:** Use SF Symbols on iOS, or use the [SF Symbols Web Equivalent](https://github.com/yourusername/sf-symbols-web)

**Key Icons:**
- Flag: `flag.fill` (flagged) / `flag` (unflagged)
- Document: `doc.text.magnifyingglass` (review)
- Person: `person.circle.fill` (patient)
- Status indicators: Colored circles (8px diameter)
- Triage: Based on outcome type

---

## Responsive Breakpoints

```css
/* Mobile first approach */
--breakpoint-sm: 640px;   /* Large phones */
--breakpoint-md: 768px;   /* Tablets */
--breakpoint-lg: 1024px;  /* Desktop */
--breakpoint-xl: 1280px;  /* Large desktop */
```

---

## Design Principles

1. **Warmth & Trust:** Beige/paper backgrounds create warmth, coral accent adds energy
2. **Clarity:** High contrast text, clear status indicators, obvious interactive elements
3. **Separation:** Flags and status are visually and functionally separate
4. **Consistency:** Same colors mean same things across all views
5. **Accessibility:** WCAG AA contrast ratios, clear focus states, readable font sizes

---

## Implementation Notes

### Web CSS Setup

```css
@import url('https://fonts.googleapis.com/css2?family=Rethink+Sans:wght@400;500;600;700;800&display=swap');

:root {
    /* Import all CSS variables from this doc */
}

* {
    box-sizing: border-box;
}

body {
    font-family: 'Rethink Sans', -apple-system, system-ui, sans-serif;
    background-color: var(--color-paper-background);
    color: var(--color-text-primary);
    line-height: 1.5;
}
```

### React/Tailwind Setup

If using Tailwind CSS, extend the theme:

```js
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        'primary-coral': '#FF5A33',
        'flagged-teal': '#4ECDC4',
        'paper-bg': '#F2EDE0',
        'user-bubble': '#EFE7D2',
        // ... add all colors
      },
      fontFamily: {
        'sans': ['Rethink Sans', 'system-ui', 'sans-serif'],
      },
      borderRadius: {
        'sm': '6px',
        'md': '8px',
        'lg': '12px',
        'xl': '16px',
      }
    }
  }
}
```

---

**For questions or clarifications, reference:**
- iOS app source: `/clara-provider-app/Views/ColorExtensions.swift`
- iOS app fonts: `/clara-provider-app/Views/FontExtensions.swift`
- Component examples: `/clara-provider-app/Views/ConversationListView.swift`
