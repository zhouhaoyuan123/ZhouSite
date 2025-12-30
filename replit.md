# replit.md

## Overview

Zhou Site is a static personal website with a minimalist design aesthetic. The site features a home page with navigation to different sections, a playground area with interactive games (including a football game), and bilingual support for English and Chinese. The project uses pure HTML, CSS, and JavaScript without any build tools or frameworks.

## User Preferences

Preferred communication style: Simple, everyday language.

## System Architecture

### Frontend Architecture
- **Pure Static HTML/CSS/JS**: The site consists of standalone HTML files with embedded or linked CSS and JavaScript. No frontend frameworks or build systems are used.
- **Design Pattern**: Minimalist, border-box design with black-and-white aesthetics and clean typography.
- **Responsive Design**: Uses CSS `clamp()` functions and media queries for fluid, responsive layouts across device sizes.

### Routing Structure
- **File-based Routing**: Navigation is handled through direct HTML file links (e.g., `/playground/index.html`, `/playground/football.html`).
- **Custom 404 Page**: A styled 404.html provides user-friendly error handling for missing pages.

### Internationalization (i18n)
- **Client-side Language Switching**: Implemented via `data-en` and `data-zh` attributes on elements, with JavaScript toggling visibility based on user selection.
- **Language Persistence**: Uses localStorage or session-based preference storage via JavaScript.

### Interactive Features
- **Canvas-based Games**: The football game uses HTML5 Canvas for rendering, with touch and keyboard input support for mobile and desktop.
- **Touch Optimization**: Mobile-specific controls with touch event handling and CSS touch-action properties.

## External Dependencies

### Third-Party Services
- **None**: The site is fully self-contained with no external APIs, databases, or CDN dependencies.

### Hosting Requirements
- **Static File Server**: Requires only a basic static file server to serve HTML, CSS, and JavaScript files.
- **No Backend**: No server-side processing, databases, or authentication systems are used.