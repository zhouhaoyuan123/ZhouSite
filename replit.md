# Zhou Site

## Overview

Zhou Site is a static personal website with a bilingual (English/Chinese) interface. The site serves as a portal with a main landing page and a "Playground" section containing interactive web games. The architecture is intentionally simple, using vanilla HTML, CSS, and JavaScript without any build tools or frameworks.

## User Preferences

Preferred communication style: Simple, everyday language.

## System Architecture

### Frontend Architecture
- **Pure Static Site**: No build process, bundlers, or frameworks. All pages are standalone HTML files with inline or linked CSS/JavaScript.
- **Vanilla Stack**: HTML5, CSS3, and plain JavaScript handle all functionality including language switching and game logic.
- **Component Pattern**: Reusable styles defined in `index_styles.css` and imported across pages for consistent styling.

### Internationalization (i18n)
- **Client-Side Language Toggle**: Language switching handled via JavaScript with `data-en` and `data-zh` attributes on elements.
- **Persistent Preference**: Language selection stored in browser (likely localStorage) and applied across page navigation.
- **Two Languages**: English (EN) as default, Chinese (ZH) as secondary option.

### Page Structure
- **Root Level**: Main landing page (`index.html`), shared styles (`index_styles.css`), and error handling (`404.html`).
- **Subdirectories for Sections**: Each major section (e.g., `/playground/`) has its own directory with an `index.html` and related files.
- **Navigation Pattern**: Grid-based navigation with icon-styled links pointing to different sections.

### Interactive Content
- **Canvas-Based Games**: The playground section includes HTML5 Canvas games (e.g., football game) with touch and keyboard controls.
- **Mobile Support**: Games include mobile-specific controls with touch button overlays and responsive canvas sizing.

## External Dependencies

### Third-Party Services
- **None**: The site is entirely self-contained with no external APIs, databases, or CDN dependencies.

### Assets
- **Favicon**: Custom favicon at `/favicon.ico`.
- **No External Fonts or Libraries**: All styling uses system fonts (Arial) and custom CSS.

### Hosting Considerations
- **Static File Hosting**: Site requires only basic static file serving with proper 404 handling configured to serve `404.html`.
- **No Server-Side Logic**: No backend, database, or server-side rendering required.