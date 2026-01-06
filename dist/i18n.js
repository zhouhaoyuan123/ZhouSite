function setLang(lang) {
    document.documentElement.lang = lang;
    document.querySelectorAll('[data-en]').forEach(el => {
        const translation = el.getAttribute('data-' + lang);
        if (translation !== null) {
            el.textContent = translation;
        }
    });
    
    // Update active state of language buttons
    document.querySelectorAll('.lang-btn').forEach(btn => {
        // Try matching by id (btn-en, btn-zh) or by text content
        const isMatch = btn.id === 'btn-' + lang || 
                        btn.getAttribute('onclick')?.includes(`'${lang}'`) ||
                        btn.textContent.toLowerCase() === lang;
        btn.classList.toggle('active', isMatch);
    });

    localStorage.setItem('preferred_lang', lang);
}

function getPreferredLanguage() {
    const language = navigator.language.substring(0, 2) || 
                   (navigator.languages && navigator.languages[0].substring(0, 2)) || 
                   "en";
    return language.split(",")[0];
}

// Initial language setup
document.addEventListener('DOMContentLoaded', () => {
    const savedLang = localStorage.getItem('preferred_lang') || getPreferredLanguage();
    setLang(savedLang);
});
