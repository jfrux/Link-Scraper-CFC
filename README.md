Link Scraper / Open Graph Parser CFC
=============

This CFC uses the "jsoup" java component to parse Open Graph (OG / OpenGraph) meta tags, as well as general meta data such as images on page, title, description, keywords, etc.
Returns back a clean struct containing all of the parsed information.

Compatibility
-------
Requires: 
* Railo 3.2+ or ColdFusion 9
Depends on:
* Jsoup Library (it's included CFC download) (http://jsoup.org)

USAGE / EXAMPLE
-------
The CFC assumes it's placed in the /lib/linkscraper in your webroot.

    <cfscript>
        IMPORT lib.linkscraper.LinkScraper;
    
        scraper = new lib.linkscraper.LinkScraper("http://www.youtube.com/watch?v=1D6V2VZhCSA");
        parsed = scraper.fetch();
        
        writeDump(var='#parsed#',abort=true);
    </cfscript>