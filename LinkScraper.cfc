/**
  * Copyright 2012 Joshua F. Rountree
  * Author: Joshua Rountree (joshua@swodev.com)
  *
  * Licensed under the Apache License, Version 2.0 (the "License"); you may
  * not use this file except in compliance with the License. You may obtain
  * a copy of the License at
  * 
  *  http://www.apache.org/licenses/LICENSE-2.0
  *
  * Unless required by applicable law or agreed to in writing, software
  * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
  * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
  * License for the specific language governing permissions and limitations
  * under the License.
  *
  * @displayname Link Scraper CFC
  * @hint A library to scrape basic meta data and open graph data about a given link.
  * 
 **/

component accessors="true" {
	/**
	* @getter true
	* @setter false
	* @hint This is a universal unique identifier for this component. It cannot be modified.
	**/
	property string uuid;
	
	/**
     * 
	 * @hint Holds the link for this instance of scraper object
	 * @getter true
	 * @setter true
	 **/
	property string link;
	
	/**
     * 
	 * @hint There are base Open Graph schema's based on type, this is just a map so that the schema can be obtained
	 * @getter true
	 * @setter true
	 **/
	property struct OpenGraphTypes;
	
	/**
     * @description Holds all the parsed values we've parsed from a page
	 * @hint 
	 * @getter false
	 * @setter true
	 **/
	property struct values;
	
	/**
     * @description Holds original HTML markup found from link.
	 * @hint 
	 * @getter true
	 * @setter true
	 **/
	property struct content;
	
	/**
     * @description Holds original HTML markup found from link.
	 * @hint
	 * @defaultValue = {'maxImages':5}
	 * @getter true
	 * @setter true
	 **/
	property struct settings;
	
	/**
     * @description jsoup component holder
	 * @hint 
	 * @getter true
	 * @setter true
	 **/
	property object jsoup;
	
	/**
     * @description javaloader component holder
	 * @hint 
	 * @getter false
	 * @setter true
	 **/
	property object javaLoader;
	
	variables._position = 0;
	
	/**
	 * @description Open Graph Constructor
	 * @hint Requires correct path to jsoup jar
	 **/
	
	public Any function init(
		required String link,
		String javaLoaderPath = 'lib.linkscraper.javaloader.JavaLoader',
		String jsoupPath = expandPath('/lib/linkscraper/jsoup-1.6.1.jar'),
		Struct settings)
	{
		setLink(arguments.link);
		
		variables.javaLoader = createObject("component",javaLoaderPath).init([jsoupPath]);
		variables.jsoup = variables.javaLoader.create("org.jsoup.Jsoup");
		
		if(structKeyExists(arguments,'settings')) {
			setSettings(structAppend(getSettings(),arguments.settings,true));
		}
		
		setOpenGraphTypes({
				'activity'=['activity', 'sport'],
				'business'= ['bar', 'company', 'cafe', 'hotel', 'restaurant'],
				'group'= ['cause', 'sports_league', 'sports_team'],
				'organization'= ['band', 'government', 'non_profit', 'school', 'university'],
				'person'= ['actor', 'athlete', 'author', 'director', 'musician', 'politician', 'public_figure'],
				'place'= ['city', 'country', 'landmark', 'state_province'],
				'product'= ['album', 'book', 'drink', 'food', 'game', 'movie', 'product', 'song', 'tv_show'],
				'website'= ['blog', 'website']
				});
		
		return this;
	}
	
	/**
	* @description Fetches a URI sets content property, returns false on error.
	* @hint
	* @param $URI URI to page to parse for requested info
	* @return OpenGraph
	**/
	
	public function fetch() {
		var Jsoup = getJsoup();
		
    	var conn = Jsoup.connect(getLink());
	    	conn.timeout(12000);
	        conn.userAgent(cgi.user_agent);
			conn.ignoreContentType(true);
		var doc = conn.get();
		var contentType = conn.response().contentType();
		var parsed = _parse(doc,contentType);
		
		return parsed;
	}
	
	/**
	* @description Parses HTML and extracts data, this assumes the document is at least well formed.
	*
	* @param $HTML HTML to parse
	* @return OpenGraph
	**/
	private function _parse(required Object doc,String contentType) {
		var values = {};
		values['opengraph'] = {};
		values['title'] = getLink();
		values['description'] = getLink();
		values['keywords'] = '';
		values['images'] = [];
		values['videos'] = [];
		values['meta'] = [];
		
		values.title = doc.title();
		
		var metaTags = doc.select('meta');
		var imgTags = doc.select('img');
		var body = doc.select('body');
		
		for (metaTag in metaTags) {
			metaAttrs = {};
			for (metaAttr IN metaTag.attributes().asList()) {
				metaAttrs[metaAttr.getKey()] = metaAttr.getValue();
			}
			values.meta.add(metaAttrs);
			/* keywords */
			if(metaTag.hasAttr('name') AND metaTag.attr('name') EQ 'keywords') {
				values.keywords = metaTag.attr('content');
			}
			
			/* description */
			if(metaTag.hasAttr('name') AND metaTag.attr('name') EQ 'description') {
				values.description = metaTag.attr('content');
			}
			
			/* open graph */
			if (metaTag.hasAttr('property') AND metaTag.attr('property') CONTAINS 'og:') {
				if(isBoolean(values.opengraph)) { values.opengraph = {}; };
				
				key = right(metaTag.attr('property'),len(metaTag.attr('property'))-3);
				keyPrefix = listFirst(key,':');
				
				if(listFindNoCase('image,video',keyPrefix,',')) {
					keyPrefixPlural = keyPrefix & "s";
					if(NOT structKeyExists(values.opengraph,keyPrefixPlural)) { values.opengraph[keyPrefixPlural] = []; };
					keyProps = {};
					
					if(listLen(key,':') GT 1) {
						/* og:image:property */
						/* most recent image added */
						keyProps[listLast(key,':')] = metaTag.attr('content');
						
						if(arrayLen(values.opengraph[keyPrefixPlural]) GT 0) {
							lastKey = values.opengraph[keyPrefixPlural][arrayLen(values.opengraph[keyPrefixPlural])];
							
							lastKey = structAppend(lastKey,keyProps,true);
						}
					} else {
						/* og:image */
						keyProps['src'] = metaTag.attr('content');
						
						values.opengraph[keyPrefixPlural].add(keyProps);
					}
				} else {
					values.opengraph[key] = metaTag.attr('content');
				}
			}
		}
		
		if(len(trim(values.description)) EQ 0) {
			values.description = trim(left(body.text(),255));
		}
		
		if(len(trim(values.keywords)) EQ 0) {
			values.keywords = replace(trim(values.description),' ',',','ALL');
		}
		
		for (imgTag in imgTags) {
			if(imgTag.attr('abs:src') DOES NOT CONTAIN "pixel") {
				imgAttrs = {};
				
				for (imgAttr IN imgTag.attributes().asList()) {
					if(imgAttr.getKey() EQ "src") {
						imgAttrKey = "abs:src";
					} else {
						imgAttrKey = imgAttr.getKey();
					}
					imgAttrs[imgAttr.getKey()] = imgTag.attr(imgAttrKey);
				}
				values.images.add(imgAttrs);
			}
		}
		
		/* overwrite title with og:title (if exists) */
		if(isStruct(values.opengraph) AND structKeyExists(values.opengraph,'title') AND len(trim(values.opengraph.title)) GT 0) {
			values.title = values.opengraph.title;
		}
		
		/* overwrite description with og:description (if exists) */
		if(isStruct(values.opengraph) AND structKeyExists(values.opengraph,'description') AND len(trim(values.opengraph.description)) GT 0) {
			values.description = values.opengraph.description;
		}
		
		/* overwrite images with og:images (if exists) */
		if(isStruct(values.opengraph) AND structKeyExists(values.opengraph,'images') AND arrayLen(values.opengraph.images) GT 0) {
			values.images = values.opengraph.images;
		}
		
		/* overwrite images with og:videos (if exists) */
		if(isStruct(values.opengraph) AND structKeyExists(values.opengraph,'videos') AND arrayLen(values.opengraph.videos) GT 0) {
			values.videos = values.opengraph.videos;
		}
		
		/* if it's an image link */
		if(listFindNoCase("image/gif,image/jpeg,image/pjpeg,image/png",arguments.contentType)) {
			values['title'] = getLink();
			values['description'] = getLink();
			values['keywords'] = '';
			values['images'] = [];
			img = {};
			img['src'] = getLink();
			values.images.add(img);
		} else if(arguments.contentType NEQ "text/html") {
			values['title'] = getLink();
			values['description'] = getLink();
			values['keywords'] = '';
			values['images'] = [];
		}
		
		/*$doc->loadHTML($HTML);
		*/
		/*libxml_use_internal_errors($old_libxml_error);
		
		$tags = $doc->getElementsByTagName('meta');
		
		if (!$tags || $tags->length === 0) {
			return false;
		}
		
		$page = new self();
		
		foreach ($tags AS $tag) {
			if ($tag->hasAttribute('property') &&
				strpos($tag->getAttribute('property'), 'og:') === 0) {
				$key = strtr(substr($tag->getAttribute('property'), 3), '-', '_');
				$page->_values[$key] = $tag->getAttribute('content');
			}
		}
		
		if (empty($page->_values)) { return false; }
		
		return $page;*/
		
		return values;
	}
}