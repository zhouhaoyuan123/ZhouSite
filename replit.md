# Zhou Site

## Overview

Zhou Site is a static personal website featuring a minimalist design with a bilingual interface (English/Chinese). The site includes a main landing page with navigation and a playground section containing interactive browser-based games like a football game built with HTML5 Canvas.

## User Preferences

Preferred communication style: Simple, everyday language.

## System Architecture

### Frontend Architecture
- **Pure Static Site**: No build tools or frameworks - just vanilla HTML, CSS, and JavaScript
- **CSS Structure**: Shared styles in `index_styles.css` with page-specific inline styles for customization
- **Responsive Design**: Uses CSS Grid, Flexbox, and `clamp()` functions for fluid layouts across devices
- **Internationalization**: Client-side language switching between English (EN) and Chinese (ZH) using `data-en` and `data-zh` attributes on elements

### Directory Structure
- Root level: Main landing page (`index.html`), shared styles (`index_styles.css`), and error page (`404.html`)
- `/playground/`: Subsite for interactive games and experiments

### Interactive Features
- **Football Game**: HTML5 Canvas-based two-player game with keyboard controls (WASD vs Arrow keys)
- **Language Toggle**: Persistent language switching using JavaScript with active state styling

### Design Patterns
- **Minimalist UI**: Black and white color scheme with bordered elements
- **Consistent Navigation**: Each subpage includes back links to parent sections
- **Mobile-First Responsive**: Grid layouts collapse to single column on small screens

## External Dependencies

This project has no external dependencies. It uses:
- Vanilla HTML5
- Vanilla CSS3
- Vanilla JavaScript
- HTML5 Canvas API for games

No package managers, build systems, databases, or third-party services are required.