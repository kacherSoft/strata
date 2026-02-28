# Strata Design Guidelines

> **Version:** 1.0
> **Last Updated:** February 25, 2026
> **Status:** Active

---

## Brand Overview

**Strata** is an AI Productivity Utility for Mac that emphasizes privacy, local-first data, and user control. The brand personality is professional yet approachable, technical but not intimidating, with a premium Mac-native feel.

**Core Values:**
- Privacy-focused & trustworthy
- Technical excellence without intimidation
- Premium, Mac-native experience
- User empowerment through BYOK

---

## Color System

### Primary Palette (Dark Mode - Primary)

| Token | Hex | Usage |
|-------|-----|-------|
| `--bg-primary` | `#0A0E17` | Main background |
| `--bg-secondary` | `#111827` | Elevated surfaces |
| `--bg-tertiary` | `#1F2937` | Card backgrounds |
| `--bg-elevated` | `#252F3F` | Hover states |

### Accent Gradient

| Token | Hex | Position |
|-------|-----|----------|
| `--accent-start` | `#6366F1` | Indigo 500 |
| `--accent-mid` | `#8B5CF6` | Violet 500 |
| `--accent-end` | `#A855F7` | Purple 500 |
| `--accent-glow` | `#818CF8` | Indigo 400 |

**Gradient Usage:**
```css
/* Primary gradient */
background: linear-gradient(135deg, #6366F1, #8B5CF6, #A855F7);

/* Glow effect */
box-shadow: 0 0 40px rgba(99, 102, 241, 0.3);
```

### Text Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `--text-primary` | `#F9FAFB` | Headings, emphasis |
| `--text-secondary` | `#D1D5DB` | Body text |
| `--text-muted` | `#9CA3AF` | Captions, labels |
| `--text-accent` | `#A5B4FC` | Highlights, links |

### Semantic Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `--success` | `#10B981` | Success states, checkmarks |
| `--warning` | `#F59E0B` | Warnings |
| `--error` | `#EF4444` | Errors |
| `--info` | `#3B82F6` | Information |

---

## Typography

### Font Stack

```css
--font-primary: 'Inter', -apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif;
--font-mono: 'SF Mono', 'Fira Code', 'Monaco', monospace;
```

### Type Scale

| Token | Size | Usage |
|-------|------|-------|
| `--text-xs` | 12px | Small labels |
| `--text-sm` | 14px | Secondary text |
| `--text-base` | 16px | Body text |
| `--text-lg` | 18px | Large body |
| `--text-xl` | 20px | Subheadings |
| `--text-2xl` | 24px | Section titles |
| `--text-3xl` | 30px | Large titles |
| `--text-4xl` | 36px | Hero subtext |
| `--text-5xl` | 48px | Large headings |
| `--text-6xl` | 60px | Display text |
| `--text-7xl` | 72px | Hero headlines |

### Line Heights

| Token | Value | Usage |
|-------|-------|-------|
| `--leading-tight` | 1.1 | Headlines |
| `--leading-snug` | 1.25 | Subheadings |
| `--leading-normal` | 1.5 | Body text |
| `--leading-relaxed` | 1.625 | Long-form text |

---

## Spacing

### Base Unit: 4px

| Token | Size |
|-------|------|
| `--space-1` | 4px |
| `--space-2` | 8px |
| `--space-3` | 12px |
| `--space-4` | 16px |
| `--space-5` | 20px |
| `--space-6` | 24px |
| `--space-8` | 32px |
| `--space-10` | 40px |
| `--space-12` | 48px |
| `--space-16` | 64px |
| `--space-20` | 80px |
| `--space-24` | 96px |
| `--space-32` | 128px |

---

## Border Radius

| Token | Size | Usage |
|-------|------|-------|
| `--radius-sm` | 6px | Small elements |
| `--radius-md` | 8px | Buttons, inputs |
| `--radius-lg` | 12px | Cards |
| `--radius-xl` | 16px | Large cards |
| `--radius-2xl` | 24px | Feature cards |
| `--radius-full` | 9999px | Pills, avatars |

---

## Effects

### Glass Effect

```css
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
```

### Liquid Glass (Premium)

```css
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
    inset 0 1px 0 rgba(255, 255, 255, 0.1);
}
```

### Glow Effects

```css
/* Accent glow */
--glow-accent: 0 0 40px rgba(99, 102, 241, 0.3);
--glow-accent-sm: 0 0 20px rgba(99, 102, 241, 0.2);

/* Success glow */
--glow-success: 0 0 30px rgba(16, 185, 129, 0.3);
```

---

## Components

### Buttons

```css
/* Primary CTA */
.btn-primary {
  background: linear-gradient(135deg, var(--accent-start), var(--accent-mid));
  padding: var(--space-2) var(--space-5);
  border-radius: var(--radius-full);
  font-weight: 600;
  font-size: var(--text-sm);
  color: white;
  transition: all 0.3s ease;
  box-shadow: var(--glow-accent-sm);
}

.btn-primary:hover {
  transform: translateY(-2px);
  box-shadow: var(--glow-accent);
}

/* Secondary / Outline */
.btn-secondary {
  background: transparent;
  border: 1px solid rgba(255, 255, 255, 0.2);
  padding: var(--space-2) var(--space-5);
  border-radius: var(--radius-full);
  font-weight: 600;
  color: var(--text-primary);
  transition: all 0.3s ease;
}

.btn-secondary:hover {
  border-color: var(--accent-glow);
  color: var(--accent-glow);
}
```

### Cards

```css
.card {
  background: var(--glass-bg);
  backdrop-filter: blur(20px);
  border: 1px solid var(--glass-border);
  border-radius: var(--radius-xl);
  padding: var(--space-6);
  transition: all 0.3s ease;
}

.card:hover {
  transform: translateY(-4px);
  border-color: rgba(99, 102, 241, 0.3);
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
}
```

### Keyboard Shortcuts

```css
.kbd {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 24px;
  height: 24px;
  padding: 0 var(--space-2);
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: var(--radius-sm);
  font-family: var(--font-mono);
  font-size: var(--text-xs);
  color: var(--text-secondary);
  box-shadow:
    0 2px 0 rgba(0, 0, 0, 0.3),
    inset 0 1px 0 rgba(255, 255, 255, 0.1);
}
```

---

## Animation Guidelines

### Durations

| Type | Duration |
|------|----------|
| Fast | 150ms |
| Normal | 300ms |
| Slow | 500ms |
| Page transitions | 600ms |

### Easing

```css
--ease-default: cubic-bezier(0.4, 0, 0.2, 1);
--ease-in: cubic-bezier(0.4, 0, 1, 1);
--ease-out: cubic-bezier(0, 0, 0.2, 1);
--ease-bounce: cubic-bezier(0.34, 1.56, 0.64, 1);
```

### Scroll Animations

```css
.fade-up {
  opacity: 0;
  transform: translateY(30px);
  transition: opacity 0.6s ease-out, transform 0.6s ease-out;
}

.fade-up.visible {
  opacity: 1;
  transform: translateY(0);
}
```

---

## Accessibility

### Contrast Requirements
- Normal text: 4.5:1 minimum (WCAG AA)
- Large text: 3:1 minimum
- Interactive elements: 3:1 against background

### Focus States
```css
:focus-visible {
  outline: 2px solid var(--accent-glow);
  outline-offset: 2px;
}
```

### Reduced Motion
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

---

## Icon Guidelines

**Recommended Icon Sets:**
- Lucide Icons (primary)
- Phosphor Icons (alternative)

**Style:**
- Stroke-based, 2px weight
- 24x24 default size
- Rounded caps and joins

**Common Icons for Strata:**
- `command`, `option` - keyboard shortcuts
- `sparkles`, `wand-2` - AI features
- `lock`, `shield`, `key` - privacy/security
- `check`, `x` - comparison, status
- `chevron-down`, `chevron-right` - navigation

---

## Responsive Breakpoints

| Breakpoint | Width | Target |
|------------|-------|--------|
| sm | 640px | Landscape phones |
| md | 768px | Tablets |
| lg | 1024px | Desktops |
| xl | 1280px | Large desktops |
| 2xl | 1536px | Extra large |

---

## Logo Usage

### Icon
- Layered geometric shape representing "strata"
- Gradient accent on hover
- Minimum size: 16px
- Clear space: 1x icon height

### Wordmark
- Use provided SVG
- White on dark backgrounds
- Gradient on accent backgrounds

---

## Voice & Tone

### Brand Voice
- Professional but approachable
- Technical but not intimidating
- Clear and concise
- Empowering

### Writing Guidelines
- Use active voice
- Keep sentences short
- Avoid jargon when possible
- Lead with benefits, not features

### Example Copy
- "Your AI, Anywhere on Your Mac"
- "Press Cmd+Opt+E to enhance text in ANY app"
- "Your data. Your control. Your Mac."

---

*Document created: February 25, 2026*
