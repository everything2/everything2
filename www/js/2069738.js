// 2069738 - HTMLToolbar
// Unknown usage

// JS QuickTags version 1.3.1
//
// Copyright (c) 2002-2008 Alex King
// http://alexking.org/projects/js-quicktags
//
// Thanks to Greg Heo <greg@node79.com> for his changes 
// to support multiple toolbars per page.
//
// Licensed under the LGPL license
// http://www.gnu.org/copyleft/lesser.html
//
// **********************************************************************
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
// **********************************************************************
//
// This JavaScript will insert the tags below at the cursor position in IE and 
// Gecko-based browsers (Mozilla, Camino, Firefox, Netscape). For browsers that 
// do not support inserting at the cursor position (older versions of Safari, 
// OmniWeb) it appends the tags to the end of the content.
//
// Pass the ID of the <textarea> element to the edToolbar and function.
//
// Example:
//
//  <script type="text/javascript">edToolbar('canvas');</script>
//  <textarea id="canvas" rows="20" cols="50"></textarea>
//

var dictionaryUrl = 'http://ninjawords.com/';

// other options include:
//
// var dictionaryUrl = 'http://www.answers.com/';
// var dictionaryUrl = 'http://www.dictionary.com/';

var edButtons = new Array();
var edLinks = new Array();
var edOpenTags = new Array();

function edButton(id, display, title, tagStart, tagEnd, access, open) {
	this.id = id;				// used to name the toolbar button
	this.display = display;		// label on button
	this.title = title;		// label on button
	this.tagStart = tagStart; 	// open tag
	this.tagEnd = tagEnd;		// close tag
	this.access = access;			// set to -1 if tag does not need to be closed
	this.open = open;			// set to -1 if tag does not need to be closed
}

edButtons.push(
	new edButton(
		'ed_strong'
		,'b'
		,'Bold'
		,'<strong>'
		,'</strong>'
		,'b'
	)
);

edButtons.push(
	new edButton(
		'ed_em'
		,'i'
		,'Italics (for emphasis)'
		,'<em>'
		,'</em>'
		,'i'
	)
);

edButtons.push(
	new edButton(
		'ed_hardlink'
		,'link'
		,'Hard link'
		,'['
		,']'
		,'a'
	)
); // special case

/*edButtons.push(
	new edButton(
		'ed_link'
		,'link'
		,'Hard link'
		,''
		,']'
		,'a'
	)
);*/ // special case (not used)

edButtons.push(
	new edButton(
		'ed_pipe_link'
		,'pipe link'
		,'Pipe link (show one thing, link another)'
		,''
		,']'
		,'e'
	)
); // special case

/* edButtons.push(
	new edButton(
		'ed_img'
		,'IMG'
		,''
		,''
		,'m'
		,-1
	)
); */ // special case - removed as long as we don't have images

edButtons.push(
	new edButton(
		'ed_ul'
		,'ul'
		,'Bulleted (unordered) list'
		,'<ul>\n'
		,'</ul>\n\n'
		,'u'
	)
);

edButtons.push(
	new edButton(
		'ed_ol'
		,'ol'
		,'Numbered (ordered) list'
		,'<ol>\n'
		,'</ol>\n\n'
		,'o'
	)
);

edButtons.push(
	new edButton(
		'ed_li'
		,'li'
		,'List item'
		,'\t<li>'
		,'</li>\n'
		,'l'
	)
);

edButtons.push(
	new edButton(
		'ed_block'
		,'b-quote'
		,'Block quote'
		,'<blockquote>'
		,'</blockquote>'
		,'q'
	)
);

var extendedStart = edButtons.length;

// below here are the extended buttons

edButtons.push(
	new edButton(
		'ed_h1'
		,'h1'
		,'Top-level heading'
		,'<h1>'
		,'</h1>\n\n'
		,'1'
	)
);

edButtons.push(
	new edButton(
		'ed_h2'
		,'h2'
		,'Second-level heading'
		,'<h2>'
		,'</h2>\n\n'
		,'2'
	)
);

edButtons.push(
	new edButton(
		'ed_h3'
		,'h3'
		,'Third-level heading'
		,'<h3>'
		,'</h3>\n\n'
		,'3'
	)
);

edButtons.push(
	new edButton(
		'ed_h4'
		,'h4'
		,'Fourth-level heading'
		,'<h4>'
		,'</h4>\n\n'
		,'4'
	)
);

edButtons.push(
	new edButton(
		'ed_p'
		,'p'
		,'Paragraph'
		,'<p>'
		,'</p>\n\n'
		,'p'
	)
);

edButtons.push(
	new edButton(
		'ed_code'
		,'code'
		,'Code'
		,'<code>'
		,'</code>'
		,'c'
	)
);

edButtons.push(
	new edButton(
		'ed_pre'
		,'pre'
		,'Pre-formatted text'
		,'<pre>'
		,'</pre>'
	)
);

edButtons.push(
	new edButton(
		'ed_dl'
		,'dl'
		,'Definition list'
		,'<dl>\n'
		,'</dl>\n\n'
	)
);

edButtons.push(
	new edButton(
		'ed_dt'
		,'dt'
		,'Definition title'

		,'\t<dt>'
		,'</dt>\n'
	)
);

edButtons.push(
	new edButton(
		'ed_dd'
		,'dd'
		,'Definition description'
		,'\t<dd>'
		,'</dd>\n'
	)
);

/* edButtons.push(
	new edButton(
		'ed_table'
		,'TABLE'
		,'<table>\n<tbody>'
		,'</tbody>\n</table>\n'
	)
);

edButtons.push(
	new edButton(
		'ed_tr'
		,'TR'
		,'\t<tr>\n'
		,'\n\t</tr>\n'
	)
);

edButtons.push(
	new edButton(
		'ed_td'
		,'TD'
		,'\t\t<td>'
		,'</td>\n'
	)
); */ // until such time as we allow tables...

edButtons.push(
	new edButton(
		'ed_ins'
		,'ins'
		,'Mark inserted text'
		,'<ins>'
		,'</ins>'
	)
);

edButtons.push(
	new edButton(
		'ed_del'
		,'del'
		,'Mark deleted (struck out) text'
		,'<del>'
		,'</del>'
	)
);

/* edButtons.push(
	new edButton(
		'ed_nobr'
		,'NOBR'
		,'<nobr>'
		,'</nobr>'
	)
);

edButtons.push(
	new edButton(
		'ed_footnote'
		,'Footnote'
		,''
		,''
		,'f'
	)
);

edButtons.push(
	new edButton(
		'ed_via'
		,'Via'
		,''
		,''
		,'v'
	)
); */

function edLink(display, URL, newWin) {
	this.display = display;
	this.URL = URL;
	if (!newWin) {
		newWin = 0;
	}
	this.newWin = newWin;
}


edLinks[edLinks.length] = new edLink('alexking.org'
                                    ,'http://www.alexking.org/'
                                    );

function edShowButton(which, button, i) {
	if (button.access) {
		var accesskey = ' accesskey = "' + button.access + '"'
	}
	else {
		var accesskey = '';
	}
	switch (button.id) {
		case 'ed_img':
			document.write('<input type="button" id="' + button.id + '" ' + accesskey + ' class="ed_button" onclick="edInsertImage(\'' + which + '\');" value="' + button.display + '" title="' + button.title + '" />');
			break;
		case 'ed_link':
			document.write('<input type="button" id="' + button.id + '" ' + accesskey + ' class="ed_button" onclick="edInsertLink(\'' + which + '\', ' + i + ');" value="' + button.display + '" title="' + button.title + '" />');
			break;
		case 'ed_pipe_link':
			document.write('<input type="button" id="' + button.id + '" ' + accesskey + ' class="ed_button" onclick="edInsertExtLink(\'' + which + '\', ' + i + ');" value="' + button.display + '" title="' + button.title + '" />');
			break;
		case 'ed_footnote':
			document.write('<input type="button" id="' + button.id + '" ' + accesskey + ' class="ed_button" onclick="edInsertFootnote(\'' + which + '\');" value="' + button.display + '" title="' + button.title + '" />');
			break;
		case 'ed_via':
			document.write('<input type="button" id="' + button.id + '" ' + accesskey + ' class="ed_button" onclick="edInsertVia(\'' + which + '\');" value="' + button.display + '" title="' + button.title + '" />');
			break;
		default:
			document.write('<input type="button" id="' + button.id + '" ' + accesskey + ' class="ed_button" onclick="edInsertTag(\'' + which + '\', ' + i + ');" value="' + button.display + '"  title="' + button.title + '" />');
			break;
	}
}

function edShowLinks() {
	var tempStr = '<select onchange="edQuickLink(this.options[this.selectedIndex].value, this);"><option value="-1" selected>(Quick Links)</option>';
	for (i = 0; i < edLinks.length; i++) {
		tempStr += '<option value="' + i + '">' + edLinks[i].display + '</option>';
	}
	tempStr += '</select>';
	document.write(tempStr);
}

function edAddTag(which, button) {
	if (edButtons[button].tagEnd != '') {
		edOpenTags[which][edOpenTags[which].length] = button;
		document.getElementById(edButtons[button].id + '_' + which).value = '/' + document.getElementById(edButtons[button].id + '_' + which).value;
	}
}

function edRemoveTag(which, button) {
	for (i = 0; i < edOpenTags[which].length; i++) {
		if (edOpenTags[which][i] == button) {
			edOpenTags[which].splice(i, 1);
			document.getElementById(edButtons[button].id + '_' + which).value = document.getElementById(edButtons[button].id + '_' + which).value.replace('/', '');
		}
	}
}

function edCheckOpenTags(which, button) {
	var tag = 0;
	for (i = 0; i < edOpenTags[which].length; i++) {
		if (edOpenTags[which][i] == button) {
			tag++;
		}
	}
	if (tag > 0) {
		return true; // tag found
	}
	else {
		return false; // tag not found
	}
}	


function edCloseAllTags(which) {
	var count = edOpenTags[which].length;
	for (o = 0; o < count; o++) {
		edInsertTag(which, edOpenTags[which][edOpenTags[which].length - 1]);
	}
}

function edQuickLink(i, thisSelect) {
	if (i > -1) {
		var newWin = '';
		if (edLinks[i].newWin == 1) {
			newWin = ' target="_blank"';
		}
		var tempStr = '<a href="' + edLinks[i].URL + '"' + newWin + '>' 
		            + edLinks[i].display
		            + '</a>';
		thisSelect.selectedIndex = 0;
		edInsertContent(edCanvas, tempStr);
	}
	else {
		thisSelect.selectedIndex = 0;
	}
}

function edSpell(which) {
    myField = document.getElementById(which);
	var word = '';
	if (document.selection) {
		myField.focus();
	    var sel = document.selection.createRange();
		if (sel.text.length > 0) {
			word = sel.text;
		}
	}
	else if (myField.selectionStart || myField.selectionStart == '0') {
		var startPos = myField.selectionStart;
		var endPos = myField.selectionEnd;
		if (startPos != endPos) {
			word = myField.value.substring(startPos, endPos);
		}
	}
	if (word == '') {
		word = prompt('Enter a word to look up:', '');
	}
	if (word != '') {
		window.open(dictionaryUrl + escape(word));
	}
}

/* The literalize button will automatically change specified characters
   ( currently &, < and [ ) into their HTML entities in the selected section.
   This allows users to quickly and easily change these special characters
   in e.g. code samples so they display correctly.
   Bugs go to rootbeer277
*/

function literalize(which) {
	myField = document.getElementById(which);
	var selectedText = '';
	if (document.selection) {
		myField.focus();
		var sel = document.selection.createRange();
		if (sel.text.length > 0) {
			selectedText = sel.text;
		}
	}
	else if (myField.selectionStart || myField.selectionStart == '0') {
		var startPos = myField.selectionStart;
		var endPos = myField.selectionEnd;
		if (startPos != endPos) {
			selectedText = myField.value.substring(startPos, endPos);
		}
	}
	var i = 0;
	var literalizedStr = '';
	for (i=0; i<selectedText.length; i++) {
		if (selectedText.substr(i,1) == '&') {
			literalizedStr = literalizedStr + '&amp;';
		} else if (selectedText.substr(i,1) == '<') {
			literalizedStr = literalizedStr + '&lt;';
		} else if (selectedText.substr(i,1) == '>') {
			literalizedStr = literalizedStr + '&gt;';
		} else if (selectedText.substr(i,1) == '[') {
			literalizedStr = literalizedStr + '&#91;';
		} else if (selectedText.substr(i,1) == ']') {
			literalizedStr = literalizedStr + '&#93;';
		} else {
			literalizedStr = literalizedStr + selectedText.substr(i,1);
		}
	}
	edInsertContent(which,literalizedStr);
}

function autoFormat (id)
{
  var elem = document.getElementsByName(id).item(0);
  var text = elem.value;
  var blocks = "pre|center|li|ol|ul|h1|h2|h3|h4|h5|h6" +
    "|blockquote|dd|dt|dl|p" +
    "|table|td|tr|th";

  text = '<p>' + text
    // strip out existing formatting
    .replace (new RegExp('</?p>', 'ig'), '')
    .replace (new RegExp('<br */?>', 'ig'), '')
    // Strip out leading and trailing space
    .replace (new RegExp('\\s*$', 'ig'), '')
    .replace (new RegExp('^\\s*', 'ig'), '')
    // New formatting
    .replace (new RegExp("\n", 'ig'), "<br />\n")
    .replace (new RegExp("<br />\n(<br />\n)+", 'ig'), "</p>\n\n<p>")
    + '</p>';
  text = text
    // Fix block elements
    .replace (new RegExp('<p><('+blocks+'[ >])', 'ig'), '<$1')
    .replace (new RegExp('</('+blocks+')></p>', 'ig'), '</$1>');

  elem.value = text;

}

function edToolbar(which) {
	document.write('<div id="ed_toolbar_' + which + '"><span>');
	for (i = 0; i < extendedStart; i++) {
		edShowButton(which, edButtons[i], i);
	}
	if (edShowExtraCookie()) {
		document.write(
			'<input type="button" id="ed_close_' + which + '" class="ed_button" onclick="edCloseAllTags(\'' + which + '\');" value="Close Tags" />'
			+ '<input type="button" id="ed_autoformat_' + which + '" class="ed_button" onclick="autoFormat(\'' + which + '\');" value="Line Breaks" title="Insert paragraph and line-break tags based on line breaks in the source" />'
			+ '<input type="button" id="ed_spell_' + which + '" class="ed_button" onclick="edSpell(\'' + which + '\');" value="Dict" />'
			+ '<input type="button" id="ed_extra_show_' + which + '" class="ed_button" onclick="edShowExtra(\'' + which + '\')" value="&raquo;" style="visibility: hidden;" />'
			+ '</span><br />'
			+ '<span id="ed_extra_buttons_' + which + '">'
			+ '<input type="button" id="ed_extra_hide_' + which + '" class="ed_button" onclick="edHideExtra(\'' + which + '\');" value="&laquo;" />'
			+ '<input type="button" id="ed_literalize_' + which + '" class="ed_button" onclick="literalize(\'' + which + '\');" value="Literalize"  title="Change &, <, and [ in selection into HTML entities" />'
		);
	}
	else {
		document.write(
			'<input type="button" id="ed_close_' + which + '" class="ed_button" onclick="edCloseAllTags(\'' + which + '\');" value="Close Tags" />'
			+ '<input type="button" id="ed_spell_' + which + '" class="ed_button" onclick="edSpell(\'' + which + '\');" value="Dict" />'
			+ '<input type="button" id="ed_extra_show_' + which + '" class="ed_button" onclick="edShowExtra(\'' + which + '\')" value="&raquo;" />'
			+ '</span><br />'
			+ '<span id="ed_extra_buttons_' + which + '" style="display: none;">'
			+ '<input type="button" id="ed_extra_hide_' + which + '" class="ed_button" onclick="edHideExtra(\'' + which + '\');" value="&laquo;" />'
			+ '<input type="button" id="ed_literalize_' + which + '" class="ed_button" onclick="literalize(\'' + which + '\');" value="Literalize"  title="Change &, <, and [ in selection into HTML entities" />'
		);
	}
	for (i = extendedStart; i < edButtons.length; i++) {
		edShowButton(which, edButtons[i], i);
	}
	document.write('</span>');
//	edShowLinks();
	document.write('</div>');
    edOpenTags[which] = new Array();
}

function edShowExtra(which) {
	document.getElementById('ed_extra_show_' + which).style.visibility = 'hidden';
	document.getElementById('ed_extra_buttons_' + which).style.display = 'block';
	edSetCookie(
		'js_quicktags_extra'
		, 'show'
		, new Date("December 31, 2100")
	);
}

function edHideExtra(which) {
	document.getElementById('ed_extra_buttons_' + which).style.display = 'none';
	document.getElementById('ed_extra_show_' + which).style.visibility = 'visible';
	edSetCookie(
		'js_quicktags_extra'
		, 'hide'
		, new Date("December 31, 2100")
	);
}

// insertion code

function edInsertTag(which, i) {
    myField = document.getElementById(which);
	//IE support
	if (document.selection) {
		myField.focus();
	    sel = document.selection.createRange();
		if (sel.text.length > 0) {
			sel.text = edButtons[i].tagStart + sel.text + edButtons[i].tagEnd;
		}
		else {
			if (!edCheckOpenTags(which, i) || edButtons[i].tagEnd == '') {
				sel.text = edButtons[i].tagStart;
				edAddTag(which, i);
			}
			else {
				sel.text = edButtons[i].tagEnd;
				edRemoveTag(which, i);
			}
		}
		myField.focus();
	}
	//MOZILLA/NETSCAPE support
	else if (myField.selectionStart || myField.selectionStart == '0') {
		var startPos = myField.selectionStart;
		var endPos = myField.selectionEnd;
		var cursorPos = endPos;
		var scrollTop = myField.scrollTop;
		if (startPos != endPos) {
			myField.value = myField.value.substring(0, startPos)
			              + edButtons[i].tagStart
			              + myField.value.substring(startPos, endPos) 
			              + edButtons[i].tagEnd
			              + myField.value.substring(endPos, myField.value.length);
			cursorPos += edButtons[i].tagStart.length + edButtons[i].tagEnd.length;
		}
		else {
			if (!edCheckOpenTags(which, i) || edButtons[i].tagEnd == '') {
				myField.value = myField.value.substring(0, startPos) 
				              + edButtons[i].tagStart
				              + myField.value.substring(endPos, myField.value.length);
				edAddTag(which, i);
				cursorPos = startPos + edButtons[i].tagStart.length;
			}
			else {
				myField.value = myField.value.substring(0, startPos) 
				              + edButtons[i].tagEnd
				              + myField.value.substring(endPos, myField.value.length);
				edRemoveTag(which, i);
				cursorPos = startPos + edButtons[i].tagEnd.length;
			}
		}
		myField.focus();
		myField.selectionStart = cursorPos;
		myField.selectionEnd = cursorPos;
		myField.scrollTop = scrollTop;
	}
	else {
		if (!edCheckOpenTags(which, i) || edButtons[i].tagEnd == '') {
			myField.value += edButtons[i].tagStart;
			edAddTag(which, i);
		}
		else {
			myField.value += edButtons[i].tagEnd;
			edRemoveTag(which, i);
		}
		myField.focus();
	}
}

function edInsertContent(which, myValue) {
    myField = document.getElementById(which);
	//IE support
	if (document.selection) {
		myField.focus();
		sel = document.selection.createRange();
		sel.text = myValue;
		myField.focus();
	}
	//MOZILLA/NETSCAPE support
	else if (myField.selectionStart || myField.selectionStart == '0') {
		var startPos = myField.selectionStart;
		var endPos = myField.selectionEnd;
		var scrollTop = myField.scrollTop;
		myField.value = myField.value.substring(0, startPos)
		              + myValue 
                      + myField.value.substring(endPos, myField.value.length);
		myField.focus();
		myField.selectionStart = startPos + myValue.length;
		myField.selectionEnd = startPos + myValue.length;
		myField.scrollTop = scrollTop;
	} else {
		myField.value += myValue;
		myField.focus();
	}
}

function edInsertLink(which, i, defaultValue) {
    myField = document.getElementById(which);
	if (!defaultValue) {
		defaultValue = 'http://';
	}
	if (!edCheckOpenTags(which, i)) {
		var URL = prompt('Enter the URL' ,defaultValue);
		if (URL) {
			edButtons[i].tagStart = '<a href="' + URL + '">';
			edInsertTag(which, i);
		}
	}
	else {
		edInsertTag(which, i);
	}
}

function edInsertExtLink(which, i, defaultValue) {
    myField = document.getElementById(which);
	if (!defaultValue) {
		defaultValue = '';
	}
	if (!edCheckOpenTags(which, i)) {
		var target = prompt('Enter the target' ,defaultValue);
		if (target) {
			edButtons[i].tagStart = '[' + target + '|';
			edInsertTag(which, i);
		}
	}
	else {
		edInsertTag(which, i);
	}
}

function edInsertImage(which) {
    myField = document.getElementById(which);
	var myValue = prompt('Enter the URL of the image', 'http://');
	if (myValue) {
		myValue = '<img src="' 
				+ myValue 
				+ '" alt="' + prompt('Enter a description of the image', '') 
				+ '" />';
		edInsertContent(which, myValue);
	}
}

function edInsertFootnote(which) {
    myField = document.getElementById(which);
	var note = prompt('Enter the footnote:', '');
	if (!note || note == '') {
		return false;
	}
	var now = new Date;
	var fnId = 'fn' + now.getTime();
	var fnStart = myField.value.indexOf('<ol class="footnotes">');
	if (fnStart != -1) {
		var fnStr1 = myField.value.substring(0, fnStart)
		var fnStr2 = myField.value.substring(fnStart, myField.value.length)
		var count = countInstances(fnStr2, '<li id="') + 1;
	}
	else {
		var count = 1;
	}
	var count = '<sup><a href="#' + fnId + 'n" id="' + fnId + '" class="footnote">' + count + '</a></sup>';
	edInsertContent(which, count);
	if (fnStart != -1) {
		fnStr1 = myField.value.substring(0, fnStart + count.length)
		fnStr2 = myField.value.substring(fnStart + count.length, myField.value.length)
	}
	else {
		var fnStr1 = myField.value;
		var fnStr2 = "\n\n" + '<ol class="footnotes">' + "\n"
		           + '</ol>' + "\n";
	}
	var footnote = '	<li id="' + fnId + 'n">' + note + ' [<a href="#' + fnId + '">back</a>]</li>' + "\n"
				 + '</ol>';
	myField.value = fnStr1 + fnStr2.replace('</ol>', footnote);
}

function countInstances(string, substr) {
	var count = string.split(substr);
	return count.length - 1;
}

function edInsertVia(which) {
    myField = document.getElementById(which);
	var myValue = prompt('Enter the URL of the source link', 'http://');
	if (myValue) {
		myValue = '(Thanks <a href="' + myValue + '" rel="external">'
				+ prompt('Enter the name of the source', '') 
				+ '</a>)';
		edInsertContent(which, myValue);
	}
}


function edSetCookie(name, value, expires, path, domain) {
	document.cookie= name + "=" + escape(value) +
		((expires) ? "; expires=" + expires.toGMTString() : "") +
		((path) ? "; path=" + path : "") +
		((domain) ? "; domain=" + domain : "");
}

function edShowExtraCookie() {
	var cookies = document.cookie.split(';');
	for (var i=0;i < cookies.length; i++) {
		var cookieData = cookies[i];
		while (cookieData.charAt(0) ==' ') {
			cookieData = cookieData.substring(1, cookieData.length);
		}
		if (cookieData.indexOf('js_quicktags_extra') == 0) {
			if (cookieData.substring(19, cookieData.length) == 'show') {
				return true;
			}
			else {
				return false;
			}
		}
	}
	return false;
}
