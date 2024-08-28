import { SharedArray } from 'k6/data'

export const WEB_URL = 'https://projetoumportodostodosporum.org'

// from sitemap.xml
export const WEB_PAGES = new SharedArray('web_pages', () => [
    '', // main page
    'about-us',
    'about-us/authors-credentials',
    'about-us/authors-credentials',
    'about-us/authors-management',
    'about-us/meet-the-author',
    'about-us/services',
    'about-us/talking-about-the-project',
    'fields',
    'fields/churches-in-unity',
    'fields/collaborators',
    'fields/collected-offers',
    'fields/offeror-families',
    'fields/offeror-families/all',
    'fields/offeror-families/specific',
    'fields/recovery-houses',
    'fields/reports',
    'fields/volunteers',
    'fields/welcomed-families',
    'how-to-participate',
    'how-to-participate/administrative-documents',
    'how-to-participate/as-autonomous-collaborator',
    'how-to-participate/as-church-in-unity',
    'how-to-participate/as-recovery-house',
    'how-to-participate/as-volunteer-family',
])