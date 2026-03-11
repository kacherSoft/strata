# Strata Landing Page - Design Specification

> **Project:** Strata - AI Productivity Utility for Mac
> **Designer:** UI/UX Designer Agent
> **Date:** February 25, 2026
> **Version:** 1.0

---

## Executive Summary

Premium, dark-mode-first landing page with liquid glass aesthetic. Single-page scroll design optimized for conversion. Target audience: freelancers, consultants, AI power users who value privacy and productivity.

---

## Design System

### Color Palette

```
Primary Brand Colors (Dark Mode)
--------------------------------
--bg-primary:       #0A0E17     // Deep space black
--bg-secondary:     #111827     // Elevated surface
--bg-tertiary:      #1F2937     // Card backgrounds
--bg-elevated:      #252F3F     // Hover states

Accent Gradient
--------------------------------
--accent-start:     #6366F1     // Indigo 500
--accent-mid:       #8B5CF6     // Violet 500
--accent-end:       #A855F7     // Purple 500
--accent-glow:      #818CF8     // Indigo 400 (glow effects)

Text Colors
--------------------------------
--text-primary:     #F9FAFB     // Gray 50 - headings
--text-secondary:   #D1D5DB     // Gray 300 - body
--text-muted:       #9CA3AF     // Gray 400 - captions
--text-accent:      #A5B4FC     // Indigo 300 - highlights

Semantic Colors
--------------------------------
--success:          #10B981     // Emerald 500
--warning:          #F59E0B     // Amber 500
--error:            #EF4444     // Red 500
--info:             #3B82F6     // Blue 500

Glass Effect Colors
--------------------------------
--glass-bg:         rgba(17, 24, 39, 0.7)
--glass-border:     rgba(255, 255, 255, 0.1)
--glass-highlight:  rgba(255, 255, 255, 0.05)
```

### Typography

```css
/* Font Stack - Mac-native feel with Google Fonts fallback */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap');

--font-primary: 'Inter', -apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif;
--font-mono: 'SF Mono', 'Fira Code', 'Monaco', monospace;

/* Type Scale */
--text-xs:    0.75rem;     /* 12px */
--text-sm:    0.875rem;    /* 14px */
--text-base:  1rem;        /* 16px */
--text-lg:    1.125rem;    /* 18px */
--text-xl:    1.25rem;     /* 20px */
--text-2xl:   1.5rem;      /* 24px */
--text-3xl:   1.875rem;    /* 30px */
--text-4xl:   2.25rem;     /* 36px */
--text-5xl:   3rem;        /* 48px */
--text-6xl:   3.75rem;     /* 60px */
--text-7xl:   4.5rem;      /* 72px */

/* Line Heights */
--leading-tight:   1.1;
--leading-snug:    1.25;
--leading-normal:  1.5;
--leading-relaxed: 1.625;
```

### Spacing System

```
4px base unit (tailwind-like)
--------------------------------
--space-1:   4px
--space-2:   8px
--space-3:   12px
--space-4:   16px
--space-5:   20px
--space-6:   24px
--space-8:   32px
--space-10:  40px
--space-12:  48px
--space-16:  64px
--space-20:  80px
--space-24:  96px
--space-32:  128px
--space-40:  160px

Section Padding
--------------------------------
--section-py:  var(--space-24) to var(--space-32)
--section-px:  var(--space-6) (mobile) to var(--space-20) (desktop)
```

### Border Radius

```
--radius-sm:   6px
--radius-md:   8px
--radius-lg:   12px
--radius-xl:   16px
--radius-2xl:  24px
--radius-full: 9999px
```

### Shadows & Effects

```css
/* Glow Effects */
--glow-accent:    0 0 40px rgba(99, 102, 241, 0.3);
--glow-accent-sm: 0 0 20px rgba(99, 102, 241, 0.2);
--glow-success:   0 0 30px rgba(16, 185, 129, 0.3);

/* Glass Card */
.glass-card {
  background: rgba(17, 24, 39, 0.7);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 16px;
  box-shadow:
    0 4px 30px rgba(0, 0, 0, 0.3),
    inset 0 1px 0 rgba(255, 255, 255, 0.05);
}

/* Liquid Glass (Premium) */
.liquid-glass {
  background: linear-gradient(
    135deg,
    rgba(99, 102, 241, 0.1) 0%,
    rgba(139, 92, 246, 0.05) 50%,
    rgba(168, 85, 247, 0.1) 100%
  );
  backdrop-filter: blur(40px) saturate(150%);
  border: 1px solid rgba(255, 255, 255, 0.15);
  box-shadow:
    0 8px 32px rgba(0, 0, 0, 0.4),
    inset 0 1px 0 rgba(255, 255, 255, 0.1),
    inset 0 -1px 0 rgba(0, 0, 0, 0.1);
}
```

---

## Section-by-Section Specification

---

### 1. NAVIGATION BAR

**Position:** Fixed, top of page
**Height:** 64px (desktop), 56px (mobile)
**Background:** Glass effect with blur

```
Layout (Desktop):
┌──────────────────────────────────────────────────────────────────┐
│  [Logo]  Strata    Features  Pricing  FAQ   [Download]  [CTA]    │
│  (left)           (center links)              (right buttons)    │
└──────────────────────────────────────────────────────────────────┘

Layout (Mobile):
┌────────────────────────────────┐
│  [Logo]  Strata      [≡ Menu]  │
└────────────────────────────────┘
```

**Elements:**
- **Logo:** Strata wordmark + icon (left)
  - Icon: Layered geometric shape (representing "strata")
  - Color: Gradient accent on hover
- **Navigation Links:** Features, Pricing, FAQ (center, desktop only)
- **Primary CTA:** "Download for Mac" button (pill shape, accent gradient)
- **Secondary:** "Watch Demo" text link with play icon

**Behavior:**
- Glass background with subtle border-bottom
- Logo scales down 10% on scroll
- Background opacity increases on scroll (0.7 → 0.95)
- Mobile: Hamburger menu slides in from right

**CSS Reference:**
```css
.navbar {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  height: 64px;
  padding: 0 var(--space-6);
  background: rgba(10, 14, 23, 0.8);
  backdrop-filter: blur(20px);
  border-bottom: 1px solid rgba(255, 255, 255, 0.05);
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.cta-button {
  background: linear-gradient(135deg, var(--accent-start), var(--accent-mid));
  padding: var(--space-2) var(--space-5);
  border-radius: var(--radius-full);
  font-weight: 600;
  font-size: var(--text-sm);
  color: white;
  transition: all 0.3s ease;
  box-shadow: var(--glow-accent-sm);
}

.cta-button:hover {
  transform: translateY(-2px);
  box-shadow: var(--glow-accent);
}
```

---

### 2. HERO SECTION (Above the Fold)

**Layout:** Full viewport height (100vh) with centered content
**Background:** Animated gradient mesh + subtle noise texture

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│     [Animated gradient orbs in background - subtle movement]     │
│                                                                  │
│              Your AI, Anywhere on Your Mac                       │
│              ────────────────────────────                        │
│                                                                  │
│         Press Cmd+Opt+E to enhance text in ANY app.              │
│       Like Grammarly, but with YOUR AI models.                   │
│                                                                  │
│     [Download for Mac]     [Watch Demo ▶]                        │
│                                                                  │
│         ⌘⌥E works in Mail, Notes, Slack, everywhere             │
│                     [App icons row]                              │
│                                                                  │
│              [Hero Product Screenshot/Video]                     │
│           (Liquid glass app window with glow)                    │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Headline:**
- "Your AI, Anywhere on Your Mac"
- Font: 72px / 4.5rem (desktop), 40px (mobile)
- Weight: 800 (extra bold)
- Gradient text effect (white to indigo)
- Letter spacing: -0.02em

**Subheadline:**
- "Press Cmd+Opt+E to enhance text in ANY app. Like Grammarly, but with YOUR AI models."
- Font: 20px / 1.25rem
- Weight: 400
- Color: var(--text-secondary)
- Max-width: 600px
- Centered

**CTA Buttons:**
- Primary: "Download for Mac" (accent gradient, glow effect)
- Secondary: "Watch Demo" (glass outline, play icon)

**Social Proof Bar:**
- Text: "Trusted by 1,000+ professionals"
- Small avatar stack (3-5 circular avatars)
- Star rating: 4.9 (5 stars)

**Hero Visual:**
- **Concept:** Animated mockup showing Inline Enhance in action
- **Frame 1:** User typing in Mail app with rough text selected
- **Frame 2:** ⌘⌥E pressed, subtle glow animation
- **Frame 3:** Text transforms to polished version
- **Style:** Liquid glass window with realistic macOS chrome
- **Animation:** Subtle float animation (3s ease-in-out loop)
- **Glow:** Soft indigo glow emanating from app window

**Background Animation:**
- 3 gradient orbs moving slowly (CSS animation)
- Colors: Indigo, violet, purple with low opacity (10-15%)
- Blur: 100px
- Movement: 20-30s duration, different timing for each

**CSS Reference:**
```css
.hero {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: var(--space-32) var(--space-6) var(--space-20);
  position: relative;
  overflow: hidden;
}

.hero-title {
  font-size: var(--text-7xl);
  font-weight: 800;
  line-height: var(--leading-tight);
  letter-spacing: -0.02em;
  background: linear-gradient(135deg, #fff 0%, #A5B4FC 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  margin-bottom: var(--space-6);
}

.hero-visual {
  margin-top: var(--space-16);
  position: relative;
  animation: float 6s ease-in-out infinite;
}

@keyframes float {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-20px); }
}

/* Background orbs */
.orb {
  position: absolute;
  border-radius: 50%;
  filter: blur(100px);
  opacity: 0.15;
  animation: drift 25s ease-in-out infinite;
}

.orb-1 {
  width: 600px;
  height: 600px;
  background: var(--accent-start);
  top: -200px;
  left: -200px;
}

.orb-2 {
  width: 500px;
  height: 500px;
  background: var(--accent-mid);
  bottom: -150px;
  right: -150px;
  animation-delay: -10s;
}

.orb-3 {
  width: 400px;
  height: 400px;
  background: var(--accent-end);
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  animation-delay: -5s;
}
```

---

### 3. LOGO BAR / TRUST STRIP

**Layout:** Full-width, subtle section below hero
**Height:** 80px
**Background:** Slightly lighter than base

```
┌──────────────────────────────────────────────────────────────────┐
│     Works with your favorite apps (logo grayscale → color)       │
│                                                                  │
│  [Apple Mail] [Notes] [Slack] [Notion] [VS Code] [Safari] [Arc]  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Behavior:**
- Logos in grayscale by default
- Colorize on hover
- Infinite scroll animation on mobile
- Label: "Works everywhere you type"

---

### 4. SOCIAL PROOF SECTION

**Layout:** Two-column on desktop, stacked on mobile
**Padding:** 96px vertical

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│   ┌─────────────────────┐   ┌───────────────────────────────┐   │
│   │  Testimonial Card   │   │  Stats Grid                   │   │
│   │  (Glass card)       │   │                               │   │
│   │                     │   │  1,000+    4.9★    100%       │   │
│   │  "Quote from user   │   │  Users     Rating   Local     │   │
│   │   about Strata..."  │   │                               │   │
│   │                     │   │  Your    No      Privacy-     │   │
│   │  - Name, Title      │   │  Data     Cloud   First       │   │
│   │  [Avatar]           │   │                               │   │
│   └─────────────────────┘   └───────────────────────────────┘   │
│                                                                  │
│   [● ○ ○ ○ ○]  Testimonial dots navigation                       │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Testimonial Card (Left):**
- Glass card with border
- Large quotation marks (accent color, low opacity)
- Quote text: 18px, italic
- Author info: Name, Title, Company
- Circular avatar (48px)
- Auto-rotate every 5s with fade transition

**Stats Grid (Right):**
- 3 columns, 2 rows
- Large number (48px, gradient)
- Label below (14px, muted)
- Icons above numbers

**Trust Badges:**
- "No Cloud Storage" icon
- "Local-First" badge
- "Apple Silicon Native" chip

**CSS Reference:**
```css
.testimonial-card {
  background: var(--glass-bg);
  backdrop-filter: blur(20px);
  border: 1px solid var(--glass-border);
  border-radius: var(--radius-xl);
  padding: var(--space-8);
  position: relative;
}

.testimonial-quote {
  font-size: var(--text-lg);
  font-style: italic;
  color: var(--text-secondary);
  line-height: var(--leading-relaxed);
}

.stat-number {
  font-size: var(--text-5xl);
  font-weight: 800;
  background: linear-gradient(135deg, var(--accent-start), var(--accent-end));
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
```

---

### 5. FEATURE SHOWCASE (Primary Section)

**Layout:** Alternating image/text rows (zigzag)
**Pattern:** Feature → Visual → Feature → Visual
**Padding:** 128px vertical

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│   Killer Features                                                │
│   ───────────────                                                │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  FEATURE 1: Inline Enhance (Hero Feature)                    ││
│  │                                                              ││
│  │  [Text Left]                    [Visual Right]               ││
│  │                                                               ││
│  │  ⌘⌥E = Magic                  [Animated GIF/Video]          ││
│  │  Enhance text in ANY app      showing text being            ││
│  │  - Works everywhere            enhanced in Mail              ││
│  │  - Your AI models              with glowing effect           ││
│  │  - No copy-paste                                            ││
│  │                                                              ││
│  │  [Try Demo Button]                                          ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  FEATURE 2: BYOK (Bring Your Own Key)                        ││
│  │                                                              ││
│  │  [Visual Left]                  [Text Right]                 ││
│  │                                                               ││
│  │  [Illustration of             Your API Key. Your Control.   ││
│  │   key entering app]           - Use Gemini, z.ai, any LLM   ││
│  │                               - Cost transparency            ││
│  │                               - No data to us                ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  FEATURE 3: Custom AI Modes                                   ││
│  │  ... (continues)                                             ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  FEATURE 4: Privacy Architecture                              ││
│  │  ... (continues)                                             ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Feature Cards Structure:**
- Each feature takes full width
- Content and visual alternate sides
- Glass card container for each
- Scroll-triggered animations (fade + slide)

**Feature 1: Inline Enhance (Highlighted)**
- Larger visual treatment
- Animated demo (GIF/video loop)
- Keyboard shortcut prominently displayed
- Glow effect around visual

**Feature 2: BYOK**
- Visual: Key illustration with provider logos
- Emphasis on "Your Key, Your Control"
- Cost comparison visual (optional)

**Feature 3: Custom AI Modes**
- Visual: Mode cards UI mockup
- Show preset modes: Correct Me, Enhance Prompt, Explain
- Custom mode creation flow

**Feature 4: Privacy Architecture**
- Visual: Data flow diagram (local only)
- Icons: Lock, shield, local storage
- Emphasis: "Nothing leaves your Mac"

**CSS Reference:**
```css
.feature-section {
  padding: var(--space-32) var(--space-6);
}

.feature-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--space-16);
  align-items: center;
  margin-bottom: var(--space-24);
}

.feature-row:nth-child(even) .feature-visual {
  order: -1;
}

.feature-badge {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  background: rgba(99, 102, 241, 0.1);
  border: 1px solid rgba(99, 102, 241, 0.3);
  padding: var(--space-1) var(--space-3);
  border-radius: var(--radius-full);
  font-size: var(--text-sm);
  color: var(--accent-glow);
  margin-bottom: var(--space-4);
}

.feature-title {
  font-size: var(--text-4xl);
  font-weight: 700;
  margin-bottom: var(--space-4);
}

.feature-list {
  list-style: none;
  padding: 0;
}

.feature-list li {
  display: flex;
  align-items: flex-start;
  gap: var(--space-3);
  margin-bottom: var(--space-3);
  color: var(--text-secondary);
}

.feature-list li::before {
  content: "✓";
  color: var(--success);
  font-weight: 600;
}
```

---

### 6. HOW IT WORKS (3-Step Flow)

**Layout:** Horizontal 3-column on desktop, vertical on mobile
**Padding:** 96px vertical

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│                    How It Works                                  │
│                    ─────────────                                 │
│                                                                  │
│   ┌─────────┐       ┌─────────┐       ┌─────────┐              │
│   │    1    │  ───► │    2    │  ───► │    3    │              │
│   │         │       │         │       │         │              │
│   │ [Icon]  │       │ [Icon]  │       │ [Icon]  │              │
│   │  Add    │       │ Press   │       │  Done!  │              │
│   │ Your    │       │ ⌘⌥E     │       │         │              │
│   │ API Key │       │         │       │ Text    │              │
│   │         │       │         │       │ Enhanced│              │
│   └─────────┘       └─────────┘       └─────────┘              │
│                                                                  │
│              [Interactive Demo - Try It Now]                     │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Step Cards:**
- Number badge (gradient circle)
- Icon illustration (64px)
- Title (20px, bold)
- Description (16px, muted)
- Connecting arrows between cards (desktop)

**Interactive Demo Concept:**
- Text input field
- User types rough text
- "Enhance" button with shortcut hint
- Animated transformation to polished text
- Mode selector dropdown

**CSS Reference:**
```css
.step-card {
  text-align: center;
  padding: var(--space-8);
  position: relative;
}

.step-number {
  width: 48px;
  height: 48px;
  background: linear-gradient(135deg, var(--accent-start), var(--accent-end));
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: var(--text-xl);
  font-weight: 700;
  margin: 0 auto var(--space-6);
  box-shadow: var(--glow-accent-sm);
}

.step-connector {
  position: absolute;
  top: 50%;
  right: -32px;
  width: 64px;
  height: 2px;
  background: linear-gradient(90deg, var(--accent-start), transparent);
}
```

---

### 7. COMPARISON SECTION

**Layout:** Feature comparison table
**Padding:** 96px vertical

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│            Why Choose Strata?                                    │
│            ─────────────────                                     │
│                                                                  │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                    Strata vs Others                       │  │
│   ├─────────────────┬──────────┬──────────┬─────────────────┤  │
│   │ Feature         │ Strata   │ Grammarly│ ChatGPT App     │  │
│   ├─────────────────┼──────────┼──────────┼─────────────────┤  │
│   │ Works in ANY app│    ✓     │    ✓     │       ✗         │  │
│   │ BYOK            │    ✓     │    ✗     │       ✗         │  │
│   │ Local storage   │    ✓     │    ✗     │       ✗         │  │
│   │ No subscription │    ✓     │    ✗     │       ✗         │  │
│   │ Custom modes    │    ✓     │    ✗     │       Partial   │  │
│   │ Privacy-first   │    ✓     │    ✗     │       ✗         │  │
│   │ One-time option │    ✓     │    ✗     │       ✗         │  │
│   └─────────────────┴──────────┴──────────┴─────────────────┘  │
│                                                                  │
│   Strata column highlighted with gradient background             │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Table Design:**
- Strata column has gradient background highlight
- Checkmarks in accent color (green)
- X marks in muted red
- Alternating row backgrounds
- Sticky header on scroll

**Visual Comparison (Alternative):**
- Side-by-side app mockups
- "Others" show cloud icons, data flowing out
- Strata shows lock icon, data staying local

**CSS Reference:**
```css
.comparison-table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  border-radius: var(--radius-xl);
  overflow: hidden;
}

.comparison-table th {
  background: var(--bg-tertiary);
  padding: var(--space-4) var(--space-6);
  text-align: left;
  font-weight: 600;
}

.comparison-table td {
  padding: var(--space-4) var(--space-6);
  border-bottom: 1px solid var(--glass-border);
}

.comparison-table tr:nth-child(even) td {
  background: rgba(255, 255, 255, 0.02);
}

.comparison-table .highlight-col {
  background: linear-gradient(
    180deg,
    rgba(99, 102, 241, 0.1) 0%,
    rgba(139, 92, 246, 0.1) 100%
  );
  border-left: 2px solid var(--accent-start);
  border-right: 2px solid var(--accent-start);
}

.check-icon { color: var(--success); }
.x-icon { color: #6B7280; }
```

---

### 8. PRICING SECTION

**Layout:** 3-tier cards, center highlighted
**Padding:** 128px vertical

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│              Simple, Transparent Pricing                         │
│              ────────────────────────                            │
│                                                                  │
│   ┌────────────┐  ┌────────────────────┐  ┌────────────┐        │
│   │   FREE     │  │   PRO (Popular)    │  │    VIP     │        │
│   │   $0       │  │   $4.99/mo         │  │   $99.99   │        │
│   │   Forever  │  │   or $39.99/yr     │  │   Once     │        │
│   │            │  │   [33% saved]      │  │            │        │
│   │ ────────── │  │ ────────────────── │  │ ────────── │        │
│   │ ✓ Tasks    │  │ ✓ Everything in    │  │ ✓ Everything│        │
│   │ ✓ Tags     │  │   Free +           │  │   in Pro   │        │
│   │ ✓ Search   │  │ ✓ Inline Enhance   │  │ ✓ Lifetime  │        │
│   │ ✓ Calendar │  │ ✓ Kanban           │  │ ✓ Early     │        │
│   │ ✓ Basic AI │  │ ✓ Custom Fields    │  │   features  │        │
│   │ ✓ Local    │  │ ✓ Recurring        │  │ ✓ Priority  │        │
│   │            │  │ ✓ AI Attachments   │  │   support   │        │
│   │ [Get Free] │  │ [Start Trial]      │  │ [Get VIP]   │        │
│   └────────────┘  └────────────────────┘  └────────────┘        │
│                         (Elevated/Glowing)                       │
│                                                                  │
│   "No credit card required for free tier. 7-day Pro trial."     │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Card Design:**
- **Free:** Glass card, standard styling
- **Pro (Highlighted):** Elevated with glow, "Most Popular" badge
- **VIP:** Glass card with gold/amber accent hints

**Pro Card Special Treatment:**
- Transform: scale(1.05)
- Box shadow: glow effect
- Border: gradient border
- Badge: "Most Popular" floating above

**Price Display:**
- Large price number (48px)
- Period below (14px, muted)
- Annual savings badge for yearly

**Feature Lists:**
- Checkmarks for included
- Muted text for not included (or omit)
- "Everything in [tier] +" for higher tiers

**CTA Buttons:**
- Free: Outline button
- Pro: Gradient filled, prominent
- VIP: Gradient with gold accent

**CSS Reference:**
```css
.pricing-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-6);
  align-items: start;
  max-width: 1100px;
  margin: 0 auto;
}

.pricing-card {
  background: var(--glass-bg);
  backdrop-filter: blur(20px);
  border: 1px solid var(--glass-border);
  border-radius: var(--radius-2xl);
  padding: var(--space-8);
  text-align: center;
}

.pricing-card.featured {
  transform: scale(1.05);
  background: linear-gradient(
    180deg,
    rgba(99, 102, 241, 0.15) 0%,
    rgba(17, 24, 39, 0.9) 100%
  );
  border: 1px solid rgba(99, 102, 241, 0.3);
  box-shadow: var(--glow-accent);
  z-index: 1;
}

.pricing-badge {
  position: absolute;
  top: -12px;
  left: 50%;
  transform: translateX(-50%);
  background: linear-gradient(135deg, var(--accent-start), var(--accent-end));
  padding: var(--space-1) var(--space-4);
  border-radius: var(--radius-full);
  font-size: var(--text-sm);
  font-weight: 600;
  white-space: nowrap;
}

.pricing-price {
  font-size: var(--text-5xl);
  font-weight: 800;
  margin: var(--space-4) 0;
}

.pricing-price .gradient-text {
  background: linear-gradient(135deg, #fff, var(--accent-glow));
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
```

---

### 9. FAQ SECTION

**Layout:** Accordion, max-width 800px, centered
**Padding:** 96px vertical

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│                    Frequently Asked Questions                    │
│                    ─────────────────────────────                 │
│                                                                  │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │ ▼ What apps does Inline Enhance work with?               │  │
│   ├──────────────────────────────────────────────────────────┤  │
│   │   Inline Enhance works in virtually ANY app on your Mac: │  │
│   │   Mail, Notes, Safari, Chrome, Slack, Notion, VS Code,   │  │
│   │   Figma, and hundreds more. If you can select text,      │  │
│   │   you can enhance it.                                    │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │ ► Do I need an API key?                                  │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │ ► Is my data sent to your servers?                       │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │ ► What AI providers are supported?                       │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │ ► Can I use Strata without an internet connection?       │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │ ► What's the difference between Pro and VIP?             │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │ ► Is there a free trial?                                 │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Key Questions to Address:**
1. What apps does Inline Enhance work with?
2. Do I need an API key?
3. Is my data sent to your servers?
4. What AI providers are supported?
5. Can I use Strata offline?
6. What's the difference between Pro and VIP?
7. Is there a free trial?
8. How do I cancel my subscription?
9. Will there be an iOS app?
10. Is Strata native on Apple Silicon?

**Accordion Design:**
- Question row with chevron icon
- Expanded state shows answer with fade-in
- Only one open at a time (optional)
- Smooth height animation

**CSS Reference:**
```css
.faq-container {
  max-width: 800px;
  margin: 0 auto;
}

.faq-item {
  border-bottom: 1px solid var(--glass-border);
}

.faq-question {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-5) 0;
  cursor: pointer;
  font-weight: 500;
  font-size: var(--text-lg);
  color: var(--text-primary);
  transition: color 0.2s;
}

.faq-question:hover {
  color: var(--accent-glow);
}

.faq-answer {
  max-height: 0;
  overflow: hidden;
  transition: max-height 0.3s ease-out, padding 0.3s ease-out;
  color: var(--text-secondary);
  line-height: var(--leading-relaxed);
}

.faq-item.open .faq-answer {
  max-height: 500px;
  padding-bottom: var(--space-5);
}

.faq-icon {
  transition: transform 0.3s;
}

.faq-item.open .faq-icon {
  transform: rotate(180deg);
}
```

---

### 10. CTA SECTION (Final Push)

**Layout:** Full-width, centered content
**Background:** Gradient overlay with animated particles
**Padding:** 128px vertical

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│              [Animated particle background]                      │
│                                                                  │
│         Ready to Supercharge Your Productivity?                  │
│                                                                  │
│         Join 1,000+ professionals already using Strata           │
│         to enhance their workflow with AI.                       │
│                                                                  │
│         [Download for Mac - Free]     [View Pricing]             │
│                                                                  │
│         Requires macOS 13.0 or later • Apple Silicon Native      │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Design:**
- Gradient background (darker version of brand gradient)
- Floating particle animation (subtle)
- Large headline (36px)
- Two CTAs: Primary (filled), Secondary (outline)
- System requirements in small text

---

### 11. FOOTER

**Layout:** Multi-column with bottom bar
**Background:** Slightly darker than base (#050810)
**Padding:** 64px top, 32px bottom

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  [Logo]  Strata                                                 │
│                                                                  │
│  Product         Resources        Company         Legal         │
│  ────────        ─────────        ────────         ─────         │
│  Features        Documentation    About            Privacy       │
│  Pricing         API Guide        Blog             Terms         │
│  Changelog       Help Center      Contact          EULA          │
│  Roadmap         Community        Press            Cookies       │
│                                                                  │
│  ─────────────────────────────────────────────────────────────  │
│                                                                  │
│  © 2026 KacherSoft. All rights reserved.    [Social Icons]      │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Columns:**
- Product: Features, Pricing, Changelog, Roadmap
- Resources: Documentation, Help Center, API Guide, Community
- Company: About, Blog, Contact, Press
- Legal: Privacy Policy, Terms, EULA, Cookies

**Social Icons:**
- Twitter/X, GitHub, Discord (or community link)
- 24px, hover accent color

**Bottom Bar:**
- Copyright text (left)
- Social icons (right)
- Subtle border-top

---

## Animation Specifications

### Scroll Animations

```css
/* Fade Up (Default) */
.fade-up {
  opacity: 0;
  transform: translateY(30px);
  transition: opacity 0.6s ease-out, transform 0.6s ease-out;
}

.fade-up.visible {
  opacity: 1;
  transform: translateY(0);
}

/* Stagger children */
.stagger-children > * {
  opacity: 0;
  transform: translateY(20px);
  transition: opacity 0.5s ease-out, transform 0.5s ease-out;
}

.stagger-children.visible > *:nth-child(1) { transition-delay: 0.1s; }
.stagger-children.visible > *:nth-child(2) { transition-delay: 0.2s; }
.stagger-children.visible > *:nth-child(3) { transition-delay: 0.3s; }
.stagger-children.visible > *:nth-child(4) { transition-delay: 0.4s; }

.stagger-children.visible > * {
  opacity: 1;
  transform: translateY(0);
}
```

### Hover Effects

```css
/* Button hover */
.btn-primary:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 30px rgba(99, 102, 241, 0.4);
}

/* Card hover */
.card:hover {
  transform: translateY(-4px);
  border-color: rgba(99, 102, 241, 0.3);
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
}

/* Link hover */
.nav-link:hover {
  color: var(--accent-glow);
}

/* Icon hover */
.icon-hover:hover {
  transform: scale(1.1);
  color: var(--accent-start);
}
```

### Micro-interactions

1. **Keyboard Shortcut Display**
   - Each key has subtle 3D effect
   - On hover: slight press animation
   - Glow pulse on page load

2. **CTA Button**
   - Shimmer effect on hover (gradient moving across)
   - Scale: 1.0 → 1.02 on hover
   - Subtle bounce on click

3. **Feature Cards**
   - Border glow on hover
   - Icon subtle rotation (5deg)
   - Text color shift

4. **Testimonial Rotation**
   - Fade out current (300ms)
   - Fade in new (300ms)
   - Dots animate to match

---

## Responsive Breakpoints

```css
/* Mobile First */
:root {
  --container-max: 1200px;
}

/* Small devices (landscape phones) */
@media (min-width: 640px) {
  .hero-title { font-size: var(--text-5xl); }
  .pricing-grid { grid-template-columns: 1fr; }
}

/* Medium devices (tablets) */
@media (min-width: 768px) {
  .hero-title { font-size: var(--text-6xl); }
  .feature-row { grid-template-columns: 1fr; }
  .pricing-grid { grid-template-columns: repeat(2, 1fr); }
}

/* Large devices (desktops) */
@media (min-width: 1024px) {
  .hero-title { font-size: var(--text-7xl); }
  .feature-row { grid-template-columns: 1fr 1fr; }
  .pricing-grid { grid-template-columns: repeat(3, 1fr); }
  .footer-grid { grid-template-columns: repeat(4, 1fr); }
}

/* Extra large devices */
@media (min-width: 1280px) {
  .container { max-width: var(--container-max); }
}
```

---

## Accessibility Considerations

1. **Color Contrast**
   - All text meets WCAG 2.1 AA (4.5:1 minimum)
   - Large text: 3:1 minimum
   - Interactive elements: 3:1 against background

2. **Focus States**
   - Visible focus ring on all interactive elements
   - Focus ring color: accent color with offset

3. **Motion**
   - Respect `prefers-reduced-motion`
   - Disable animations for users who prefer reduced motion

4. **Semantic HTML**
   - Proper heading hierarchy (h1 → h2 → h3)
   - ARIA labels for icons
   - Alt text for images

5. **Keyboard Navigation**
   - All interactive elements focusable
   - Skip to main content link
   - Logical tab order

```css
/* Reduced motion */
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}

/* Focus visible */
:focus-visible {
  outline: 2px solid var(--accent-glow);
  outline-offset: 2px;
}
```

---

## Asset Requirements

### Images

| Asset | Size | Format | Description |
|-------|------|--------|-------------|
| Logo (Icon) | 32x32, 64x64, 128x128 | SVG/PNG | Layered geometric icon |
| Logo (Wordmark) | Vector | SVG | "Strata" text |
| Hero Screenshot | 1200x800 | PNG/WebP | App mockup with glow |
| Feature GIFs | 800x600 | GIF/WebM | Inline enhance demo |
| Testimonial Avatars | 96x96 | PNG/WebP | Circular, optimized |
| App Icons Grid | 400x80 | SVG/PNG | Compatible apps |

### Icons

Use Lucide Icons or Phosphor Icons (consistent style):
- `command`, `option` - for keyboard shortcuts
- `sparkles`, `wand` - for AI features
- `lock`, `shield`, `key` - for security/privacy
- `check`, `x` - for comparison table
- `chevron-down`, `chevron-right` - for navigation/accordion
- `download`, `play` - for CTAs

---

## Implementation Notes

### Tech Stack Recommendations
- **Framework:** Next.js 14+ (App Router) or Astro
- **Styling:** Tailwind CSS with custom config
- **Animations:** Framer Motion or CSS animations
- **Icons:** Lucide React
- **Fonts:** Inter (Google Fonts)

### Performance Targets
- Lighthouse Performance: 90+
- First Contentful Paint: < 1.5s
- Largest Contentful Paint: < 2.5s
- Cumulative Layout Shift: < 0.1

### SEO Considerations
- Semantic HTML structure
- Meta tags (title, description, og:image)
- Schema.org markup for software app
- Sitemap generation

---

## Unresolved Questions

1. Should we include a live interactive demo of Inline Enhance in the hero section?
2. What's the exact pricing for Pro monthly/annual and VIP one-time?
3. Do we have real testimonials yet, or should we use placeholder quotes?
4. Should the comparison section compare against specific competitors by name?
5. What's the download URL structure (direct .dmg or landing page)?
6. Should we include a video demo or animated GIFs for feature showcase?
7. Is there a referral program or affiliate structure to highlight?

---

## File References

- Design tokens: This document
- Brand colors: `#6366F1` → `#8B5CF6` → `#A855F7` gradient
- Typography: Inter font family
- Icons: Lucide Icons library

---

*Document created: February 25, 2026*
*Designer: UI/UX Designer Agent*
