# Zhou Site

## Overview

Zhou Site is a static personal website with a minimalist design aesthetic. The site features a clean, bordered box design language with a simple navigation grid system. It includes a main landing page, a playground section with interactive games (like a football game), and bilingual support (English/Chinese).

## User Preferences

Preferred communication style: Simple, everyday language.

## System Architecture

### Frontend Architecture
- **Pure HTML/CSS/JavaScript** - No frameworks or build tools; static files served directly
- **Design Pattern**: Minimalist bordered-box aesthetic with centered layouts
- **Responsive Design**: Uses CSS clamp() functions and media queries for fluid typography and layouts
- **Grid-based Navigation**: 3-column grid system that collapses to single column on mobile

### Page Structure
- `index.html` - Main landing page with navigation grid
- `playground/index.html` - Sub-section for games and interactive content
- `playground/football.html` - Canvas-based 2-player football game
- `404.html` - Custom error page matching site design

### Internationalization (i18n)
- Client-side language switching using `data-en` and `data-zh` attributes on HTML elements
- Language preference persisted via localStorage
- Toggle buttons in fixed position (top-right corner)

### Styling Approach
- Shared stylesheet (`index_styles.css`) for common styles across pages
- Page-specific styles embedded in `<style>` tags within each HTML file
- Black and white color scheme with minimal accent colors

## External Dependencies

### Third-Party Services
- None - This is a fully self-contained static website

### APIs
- None

### Databases
- None - All content is static HTML

### CDN/External Resources
- None - All assets are local

### Hosting Requirements
- Any static file server (no server-side processing required)
- Clean URLs configured (e.g., `/playground` serves `playground/index.html`)