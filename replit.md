# Zhou Site

## Overview

Zhou Site is a static personal website with a minimalist design aesthetic. The site features a clean, bordered visual style with bilingual support (English and Chinese). It serves as a personal landing page with a navigation grid linking to different sections, including a "Playground" area that contains interactive browser-based games.

## User Preferences

Preferred communication style: Simple, everyday language.

## System Architecture

### Frontend-Only Static Site
- **Structure**: Pure HTML/CSS/JavaScript static website with no backend
- **Rationale**: Simple personal site with no dynamic data requirements; static hosting is sufficient
- **Styling**: Custom CSS with responsive design using CSS Grid, clamp() functions, and media queries
- **Internationalization**: Client-side language switching between English (EN) and Chinese (ZH) using data attributes

### Page Organization
- **Root level**: Main landing page (index.html) and 404 error page
- **Playground section**: Nested directory containing games and interactive content
- **Shared styles**: Common stylesheet (index_styles.css) imported across pages

### Design Patterns
- **Component-based icons**: CSS-drawn icons for navigation items (playground-icon with playground-frame, flag, lines)
- **Responsive grid layout**: 3-column grid that collapses to single column on mobile (600px breakpoint)
- **Language toggle**: Fixed-position language switcher with active state styling

### Interactive Games
- **Football game**: Canvas-based browser game with touch controls for mobile devices
- **Touch support**: Mobile-specific controls with touch-action handling and -webkit-user-select for iOS compatibility

## External Dependencies

### Third-Party Services
- None currently integrated

### APIs
- None currently integrated

### Databases
- None - this is a static site with no data persistence

### CDN/External Resources
- None - all assets are self-hosted