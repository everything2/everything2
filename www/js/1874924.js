// 1874924.js "default javascript"
// Used on every pageload

// This function finds the message box and adds in a the chatterbox shortcut
// to send a private message. It is only used in the chatterbox variants 
function replyToCB(s, onlineonly) {
        var mbox = jQuery('#message')[0] ;
        mbox.value = ( onlineonly ? '/msg? ' : '/msg ' ) + s + " ";
        // move the cursor to the end of the text box
        if (mbox.createTextRange) { // IE
                var r = mbox.createTextRange();
                r.moveStart('character', mbox.value.length);
                r.select();
        } else { // other, in particular webkit
                mbox.focus();
                if (mbox.setSelectionRange)
                        mbox.setSelectionRange(mbox.value.length, mbox.value.length);
        }
}

// jQuery BBQ deparam shim
    function e2URL (url) {
      this.url = url;
      this._parse_param_string =
        function(url)
        {
          if(url === undefined)
          {
            return "";
          }

          var get_params_start = url.indexOf("?");
          if(get_params_start == -1)
          {
            return "";
          }else{
            return [url.slice(0,get_params_start),url.slice(get_params_start+1)];
          }
        };

      this._make_param_array = function(param_string)
        {
          var param_hash = {};
          if(param_string === undefined || param_string == "")
          {
            return param_hash;
          }

          var param_chunks = param_string.split("&");
          for (var i = 0; i < param_chunks.length; i++)
          {
            var this_param = param_chunks[i].split("=");
            param_hash[decodeURIComponent(this_param[0])] = decodeURIComponent(this_param[1]);
          }

          return param_hash;
        };
        var _parse_param_string_output = this._parse_param_string(this.url);
        this.url_head = _parse_param_string_output[0];
        this.param_string = _parse_param_string_output[1];
        this.params = this._make_param_array(this.param_string);

        this.make_url = function(){
          var _new_encoded_params = [];
          var _param_keys = Object.keys(this.params);
          if(_param_keys.length == 0)
          {
            return this.url_head;
          }
          for(var i = 0; i < _param_keys.length; i++)
          {
            _new_encoded_params.push(encodeURIComponent(_param_keys[i])+"="+encodeURIComponent(this.params[_param_keys[i]]));
          }
          return this.url_head + "?" + _new_encoded_params.join("&");
        }
      }

// End jQuery BBQ deparam shim

//Begin contents of boilerplate javascript

$.extend(e2, {
	fxDuration: (e2.fxDuration || 200) - 1, // fx off is stored as 1
	isChatterlight: /^Chatterlight/i.test(document.title) && (e2.autoChat = true),
	collapsedNodelets: e2.collapsedNodelets || '',
	
	tinyMCESettings: {
		// add mode before use
		theme: 'advanced',
		plugins: 'table',
		theme_advanced_buttons3_add_before: 'tablecontrols,|',
		theme_advanced_disable: 'styleselect,image,anchor,link,unlink,row_props,cell_props',
		theme_advanced_statusbar_location: 'bottom',
		theme_advanced_resizing: true,
		element_format: 'html',
		remove_linebreaks: false,
		forced_root_block: '',
		inline_styles: false,
		entity_encoding: 'raw',
		invalid_elements: 'a,img,div,span',
		extended_valid_elements: 'big,small,i,b,tt,p[align],hr[width]',
		formats: {
			alignleft:    { selector: 'p', attributes : { align: "left" } },
			alignright:   { selector: 'p', attributes : { align: "right" } },
			aligncenter:  { selector: 'p', attributes : { align: "center" } }
		}
	},
	
	timeout: 20, //seconds
	defaultUpdatePeriod: 3.5, // minutes
	sleepAfter: 17 // minutes
});

jQuery.fx.interval = 40; // 25 frames/second: assume user is human. (Default = 13 => ~80Hz == daft)
if (e2.fxDuration == 0) jQuery.fx.off = true;

// End old contents of boilerplate javascript

$(function(){
	// full text search

	var disableOtherChecks = function(setDisable) {
		var checks = $('#search_form input[type=checkbox]:not(#full_text)');
		checks.attr('disabled', setDisable);
	};

	$('#searchbtngroup').append(
		'<span><label title="Search for text within writeups">'+
		'<input name="full_text" value="1" id="full_text" type="checkbox">Full Text</label></span>'
	);
        $('#search_form').bind('submit', function(){
		if ( ! $('#full_text:checked').length ) return;
		disableOtherChecks(true);
		$('#search_form')
		.attr('action', '/node/superdoc/E2+Full+Text+Search')
		.append(
			'<input type="hidden" name="cx" value="017923811620760923756:pspyfx78im4">'+
			'<input type="hidden" name="cof" value="FORID:9">'+
			'<input type="hidden" name="sa" value="Search">'
		);
		$('#node_search').attr('name', 'q');
	});

        $('#testdrive').bind('focus click', function(){
	this.href = this.href.replace('&noscript=1' , '');
        });

	$('#full_text')
	.bind('change', function(){
		if ($(this).is(':checked')) {
			disableOtherChecks(true);
		} else {
			disableOtherChecks(false);
		}
	});

	// can be useful to know where we really are
	var link = $('head link[rel=canonical]');
	e2.pageUrl = (link.length ? link[0].href : 'none');

	// may have cached a version of a page with the wrong domain in the form
	// make submit go to the proper place, but without query params which might have ops
	var submitHref = location.href.replace( /\?.*/ , "" );
	$('#epicenter form, #signin form').attr('action', submitHref);
	e2.activate();
});

// turn e2 object into a handy flexible function and extend it
e2 = $.extend( function(x){return e2.shortFunctions[typeof x].apply(this, arguments);}, e2, {

	// e2.inclusiveSelect(selector): jQuery(selector).
	// e2.inclusiveSelect(selector, x): select elements in and including x matching
	// selector in the context of the whole document
	inclusiveSelect: function(selector, x){
		if (!x) return $(selector);
		return $.merge($(x).filter(selector), $('*', x).filter(selector));
	},

	instructions: [],
	
	// e2.add(selector, fn, args): do $(selector).fn(args) on page load and
	// on elements added by ajax update, with selector applied in document context
	add: function(selector, fn, args){
		// guest doesn't get/need jQuery.ui. Otherwise don't hide missing functions.
		if (!$.fn[fn] && (e2.guest || e2.ignoreMissingLibraries)) return;
		if (!$.isArray(args)) args = [args];
		e2.instructions.push({selector: selector, fn: fn, args: args});
	},
	
	// e2.activate(el): run/bind all e2.instructions for elements in and including
	// el (default = document) that match their selectors in document context
	activate: function(el){
		var hadFocus = e2.getFocus(el);
		for (var i = 0, n; n = e2.instructions[i]; i++){
			$.fn[n.fn].apply(e2.inclusiveSelect(n.selector, el), n.args);
		}
		if (hadFocus) $('#'+hadFocus).focus();
	},
	
	// define functioning of e2() function for different argument types
	shortFunctions: {
		// e2(selector, function): e2.add(selector, 'each', function)
		// e2(selector, fnName, x): e2.add(selector, fnName, x)
		// e2(selector, x): e2.inclusiveSelect(selector, x)
		// e2(selector): jQuery(selector)
		'string': function(selector, x, y){
			if (typeof x == 'function') return e2.add.call(this, selector, 'each', x);
			if (typeof x == 'string') return e2.add.apply(this, arguments);
			return e2.inclusiveSelect.apply(this, arguments);
		},
	
		// e2(object): activate e2 js functions for single element or all elements in jQuery object
		object: function(x){
			if (x.tagName){
				return e2.activate(this);
			}else if (x.length){ // jQuery object
				return x.each(function(){e2.activate(this);});
			}
		},
	
		// e2(function): provide a couple of useful metafunctions found in Prototype:
		//	 e2(function).delay( delay, argument1, argument2, ... )
		//	 e2(function).defer( arguments )
		'function': function(fn){
			$.extend(fn, {
				delay: function(){
					var context = this, args = $.makeArray(arguments), secs = args.shift();
					return setTimeout(function(){fn.apply(context, args);}, secs*1000)
				},
				defer: function(){
					var args = $.makeArray(arguments);
					args.unshift(0.01);
					return fn.delay.apply(this, args);
				}
			});
			return fn;
		}
	},
	
	// UTILITY FUNCTIONS
	
	getUniqueId: function(){
		if (!e2.idCounter) e2.idCounter = e2.now();
		return 'e2-'+(e2.idCounter++).toString();
	},
	
	// wrapper for setInterval, similar to/callable like Prototype's PeriodicalExecuter,
	// but with automatic expiry function
	// new e2.periodical( callback, period(seconds), expire after (seconds), callback when expired )
	// period < 0 to set it up to start later or to stop it and disable restart() without a new period
	periodical: function(callback, period, expireAfter, expired){
		var timer, reaper, executing,
			p = this,
			lastTime = e2.now();
		function execute(late){
			if (executing || late/1000 > period*0.85) return;
			executing = true;
			try{
				callback.call(p);
			}catch(e){
			}finally{
				if (executing != 'sleep') executing = false; // could be told to sleep while executing
				lastTime = e2.now() - late;
			}
		}
		this.stop = function(){
			if (timer) clearInterval(timer);
			if (reaper) clearTimeout(reaper);
			timer = reaper = false;
		};
		this.die = function(){
			p.stop();
			if (expired) expired.call(p);
		};
		(this.restart = function(newPeriod, newExpireAfter, newExpired){
			if (timer) p.stop();
			period = newPeriod || period;
			expireAfter = newExpireAfter || expireAfter;
			expired = newExpired || expired;
			if (period > 0) timer = setInterval(execute, period * 1000);
			if (timer && expireAfter) reaper = setTimeout(p.die, expireAfter * 1000);
		})();
		this.sleep = function(){
			executing = 'sleep';
		};
		this.wake = function(){
			if (executing == 'sleep') executing = false;
			if (!timer || // can't wake the dead
				e2.now() < lastTime + period * 1000) return p; // can keep old rhythm
			execute(0);
			p.restart(); // establish new rhythm
		};
	},
	
	now: function(){
		return (new Date()).getTime();
	},
	
	getCookie: function(name){
		var myCookie = (new RegExp(name+ '=\\s*([^;\\s]*)')).exec(document.cookie) ;
		return myCookie && myCookie[1];
	},
	
	setCookie: function(name, value, days){
		var dateString = '';
		if (days){
			var date = new Date();
			date.setTime(date.getTime()+(days*24*60*60*1000));
			dateString = ";expires=" + date.toGMTString()
		}
		document.cookie = name + "=" + value + ";path=/" + dateString;
	},
	
	deleteCookie: function(name){
		document.cookie = name + "=;path=/;expires=Thu, 26 Aug 2010 16:00:00 GMT";
	},

	// e2.getFocus(el): if the focus is el or in el, return its id. Otherwide false.
	// if focussed element has no id, give it one.
	getFocus: function(el){
		var ae = document.activeElement;
		if (ae && ae.tagName.toLowerCase() != 'body' &&
				( ae.id || (ae.id = e2.getUniqueId()) ) && e2('#'+ae.id, el).length)
			return ae.id ;
		return false ;
	},
	
	getSelectedText: function(){
		var el=document.activeElement;
		if (el && el.selectionEnd)
			return el.value.slice(el.selectionStart, el.selectionEnd); // textarea/input
		if(window.getSelection) return window.getSelection().toString(); // not IE
		if(document.selection) return document.selection.createRange().text; // IE
		return ''; // ack! Unknown browser error
	},
	
	heightToScrollHeight: function(x, otherHeight) {
		var init = otherHeight || x.scrollHeight;
		x.style.height = init.toString() + 'px';
		var diff = x.scrollHeight - init; // find discrepancy,
		// and remove it twice because this repeats it:
		x.style.height = ( x.scrollHeight - 2*diff ).toString() + 'px';
	},
	
	startText: function(field, text){ // for, e.g., message reply links
		var mbox = $('#'+field)[0];
		mbox.value = text;
		// move the cursor to the end of the text box
		if (mbox.createTextRange) { // IE
			var r = mbox.createTextRange();
			r.moveStart('character', mbox.value.length);
			r.select();
		} else { // other, in particular webkit
			mbox.focus();
			if (mbox.setSelectionRange)
				mbox.setSelectionRange(mbox.value.length, mbox.value.length);
		}
	},

	vanish: function($thing){
		e2(function(){
			$thing.fadeTo(e2.fxDuration, 0, function(){
				$thing.slideUp(e2.fxDuration, function(){
					$thing.remove();
				})
			});
		}).delay(e2.fxDuration/1000);
	},

	setLastnode: function(lastnode){
		var REPLACE_PARAMS = 2;
		var oldHref = this.href;
		// this function is why we need jquery bbq
		// deparam does not deal well with no query string, so provide a blank one
		if (oldHref.indexOf('?') == -1) {
			oldHref = oldHref.replace( /(#.*|$)/ , "?$1" );
		}
		// don't encode an anchor
		var newHref = oldHref.split('#');
		var newurl = new e2URL(newHref[0]);
		if (lastnode === undefined) {
			delete newurl.params['lastnode_id'];
		} else {
			newurl.params["lastnode_id"] = lastnode;
		}
		newHref[0] = newurl.make_url();
		this.href = newHref.join('#');
	},

	// confirmop framework
	confirmop: function(event){
		if ( !confirm( "Really " + this.title + "?" ) ) {
			event.preventDefault();
		}else{
			if (this.href){
				var parname = /\bnotanop\b=([^?&]*)/.exec( this.href ) || 'op';
				if (parname.index){ // notanop
					parname = parname[1] ;
					this.href = this.href.replace( /\bnotanop\b=([^?&]*)/ , '');
					this.href = this.href.replace( /([?&])&|&$/ , "$1" ) ;
				}
				this.href = this.href.replace( /\bconfirmop=/ , parname + '=' );
			}else{
				this.name = this.form.notanop ? this.form.notanop.value : 'op';
			}
		}
	},
	
	// jQuery.append() calls scripts with AJAX and runs them, which doesn't always work (version 1.4.3):
	// it fails on load for JS QuickTags HTML toolbar and on run for tinyMCE 2.0, for example. So:
	loadScript: function(x){
		// x is an url or a bogus script element made with jQuery('...') ('bogus' = fails except in FF)
		var scr = document.createElement('script');
		scr.setAttribute('type', 'text/javascript');
		scr.setAttribute('src', (typeof x == 'string' ? x : x.src));
		$('head')[0].appendChild(scr);
	},
	
	// load a script and then do something with it: robuster than AJAX
	// (jQuery.getScript() fails with tinyMCE 2.0, for example)
	// callback runs when 'success' is true
	doWithLibrary: function(url, success, callback, ack){
		if (!window[success]){
			e2.loadScript(url);
			var started = e2.now();
		}
		wait();
	
		function wait(){
		// can't use the onload event on the inserted script element because IE won't play
			if (!window[success]){
				if (e2.now() - started < e2.timeout*1000/2) return setTimeout(wait, 100);
				if (ack) ack();
			}
			callback()
		}
	},
	
	// 3rd party code (tinyMCE 2 and QuickTags) uses document write. Subvert it...
	divertWrite: function(place){
		e2.divertWrite.writeTo = place;
		dump();
	
		// initialise
		if (typeof e2.divertWrite.buffer != 'string'){
			e2.divertWrite.buffer = '';
			document.write = function(y){
				e2.divertWrite.buffer = e2.divertWrite.buffer + y.toString();
				dump();
			};
		}
	
		function dump(){
			if (!e2.divertWrite.writeTo || !e2.divertWrite.buffer) return;
			var z = $(e2.divertWrite.buffer);
			e2.divertWrite.buffer = '';
			var fn = (/head|body/i.test(e2.divertWrite.writeTo.tagName) ? 'append' : 'before');
			z.each(function(){
				// don't let jQuery at the scripts...
				if (this.tagName.toLowerCase() == 'script' && this.src) return e2.loadScript(this);
				$(e2.divertWrite.writeTo)[fn](this);
			});
		}
	},
	
	// activate tinyMCE if preferred, otherwise JS QuickTags,
	// and provide switch to toggle to the other
	htmlFormattingAids: (function(){
		var initial = (e2.settings_useTinyMCE ? 'WYSIWYG editor' : 'HTML toolbar');
                //HTMLToolbar is now: 2069738
		var aids = {
			active: {},

			'HTML toolbar': {
				library: 'https://s3-us-west-2.amazonaws.com/jscssw.everything2.com/2069738.js',
				test: 'edToolbar',
	
				stop: function(id){
					$('#' + 'ed_toolbar_' + id).slideUp(e2.fxDuration);
				},
	
				go: function(id){
					if (!$('#' + 'ed_toolbar_' + id).length){
						e2.divertWrite(null); // save it up until finished
						edToolbar(id);
						e2.divertWrite($('#'+id)[0]);
					}
					$('#' + 'ed_toolbar_' + id).hide().slideDown(e2.fxDuration);
				}
			},

			'WYSIWYG editor': {
				library: 'https://s3-us-west-2.amazonaws.com/jscssw.everything2.com/tiny_mce/tiny_mce.js?a=1',
				test: 'tinyMCE',
	
				stop: function(id){ // don't use mceToggleEditor, it loses changes afterwards
					tinyMCE.execCommand('mceRemoveControl', false, id);
					e2.setCookie('settings_useTinyMCE', '0');
				},
	
				go: function(id){
					if (!aids['WYSIWYG editor'].initted){
						tinymce.dom.Event.domLoaded = true; // Hah!
						tinyMCE.init($.extend(e2.tinyMCESettings,{
							mode: 'exact',
							elements: id
	    				}));
	    				aids['WYSIWYG editor'].initted = true;
			  		}else{
						tinyMCE.execCommand('mceAddControl', false, id);
					}
					e2.setCookie('settings_useTinyMCE', '1');
				}
			}
		};

		function toggle(e){
			e.preventDefault();
			var id = this.targetId;
			var $this = $(this);
			var active = aids.active[id] || initial;
			var other = 'WYSIWYG editorHTML toolbar'.replace(active, '');
	
			$this.addClass('pending');
			e2.doWithLibrary(aids[other].library, aids[other].test, doToggle, function(){
				alert('Ack! Failed to load library for ' + other + '.');});
	
			function doToggle(){
				$this.removeClass('pending');
				aids[active].stop(id);
				e2(aids[other].go).defer(id); // drop errors
				$this.find('span').text('offon'.replace($this.find('span').text(), ''));
				aids.active[id] = other;
			}
		}
	
		return function(){
			if (!this.id) this.id = e2.getUniqueId();
			var id = this.id;
			e2.doWithLibrary(aids[initial].library,
				aids[initial].test,
				function(){aids[initial].go(id);});

			$('<p><button type="button" id="' + id + '_switch" href="#">Turn <span>'+
				(e2.settings_useTinyMCE ? 'off' : 'on') +
				'</span> <abbr title="What you see is what you get">WYSIWYG</abbr> '+
				'editing.</button></p>')
			.insertBefore(this)
			.find('button').click(toggle)
			[0].targetId = id;
		}
	})(),
	
	// fix IE <= 7 form button fail. (innerHTML is submitted instead of value)
	iebuttonfix: function(){
		$('<input type="hidden" name="'+this.name+'" value="'+this.cloneNode().value+'">').insertAfter(this);
		this.name = 'iebutton';
	}

// END e2 = $.extend(function(){..} , e2, { ...
});

// NOW DO STUFF:

e2('.formattable', e2.htmlFormattingAids);

// message reply links
e2('.privmsg .action', 'show');

// confirmop
e2("a.action[href*='confirmop='], form button[name=confirmop], form :submit[name=confirmop]", 'click', e2.confirmop);

// expandable inputs/textareas
(function(){
	function textareaEvent(e){
		e.stopImmediatePropagation(); // i.e. only do this once. or IE may go crazy
		if (this.replaces){ // i.e. is a replacement for an input element
			// replace pasted newlines:
			if (/[\r\n]/.test(this.value)) this.value = this.value.replace(/[\r\n]+/g , ' ');
			if (e.which == 13 || // don't let return do anything
				(this.maxlength && this.value.length >= this.maxlength && // if at limit, then:
					( e.which > 47 || e.which == 32 ) && // stop real character key...
					( !(e.ctrlKey && !e.altKey) && !e.metaKey ) && // with no unreal modifier...
					e2.getSelectedText().length == 0) // ...unless it deletes old text
					){
				e.preventDefault();
				// only react to one event per keything, keydown works in all browsers:
				if (e.which == 13 && e.type == 'keydown'){
					if ( this.form.onsubmit && !this.form.onsubmit() ) return ;
					$(this.form).submit() ;
				}
			}
		}
		if (this.maxlength && this.value.length > this.maxlength) // possible if excess pasted in
			this.value = this.value.substr(0, this.maxlength);
		e2.heightToScrollHeight(this);
	}

	function copyInputStyles(source, destination){
		var list=[ 'marginTop' , 'marginBottom' , 'marginLeft' , 'marginRight' ,
		'paddingTop' , 'paddingBottom' , 'paddingLeft' , 'paddingRight' ,
		'fontFamily' , 'height', 'width']; // haven't found a way to get fontSize right in IE...
		if (!source[0].currentStyle) list[list.length] = 'fontSize';
		for (var i=0; list[i]; i++){
			destination.css(list[i], source.css(list[i]) ); }
	}

	function expandableTextarea(){
		this.style.overflow = 'hidden' ;
		if ( !this.getAttribute('rows') ) this.setAttribute( 'rows' , '2' ) ;
		$(this).bind('keydown keypress keyup textInput', textareaEvent);
		$(this).focus(function(){e2.heightToScrollHeight(this);});
	}

	function expandableInput(){
		var replacement = document.createElement( 'textarea' ) ;
		replacement.replaces = true;
		replacement.innerHTML = this.value ;
		for ( var atts = this.attributes , i=0 ; atts[i] ; i++ )
			if ( !this.outerHTML || this.outerHTML.indexOf( atts[i].name + '=' ) > -1 ) // filter for IE8
				if ( !/size|type/.test( atts[i].name ) )
					replacement.setAttribute( atts[i].name , atts[i].value ) ;
		if ( this.getAttribute( 'maxlength' ) ) replacement.maxlength = this.getAttribute( 'maxlength' ) ;
		replacement.setAttribute('rows', 1) ;
		replacement.setAttribute('columns', this.getAttribute('size')) ;
		expandableTextarea.call(replacement);
		copyInputStyles($(this), $(replacement));
		replacement.originalHeight = replacement.style.height;
		replacement.style.verticalAlign = 'top' ;
		this.parentNode.replaceChild( replacement , this );
		if (!replacement.form[replacement.name]){ // fix occasional IE7 fail
			replacement.form[replacement.name]=$('[name='+replacement.name+']',replacement.form)[0];
		}
		e2.heightToScrollHeight( replacement ) ;
	}

	e2('textarea.expandable', expandableTextarea);
	e2('input.expandable', expandableInput);
})();

// widgets. After expandables so replaced inputs aren't display:none and so have dimensions to transfer.
e2('.showwidget', function(){
	var classtest = /\bwidget\b/ ;
	for ( var j=0 , family = [ this , this , this ] ,
		relations = [ 'previousSibling' , 'nextSibling' , 'parentNode' ]; family[2] ; j=(j+1)%3 ){
		if ( family[j] ) family[j] = family[j][ relations[j] ] ;
		if ( family[j] && classtest.test( family[j].className ) ) {
			this.removeAttribute( 'href' ) ;
			$(this).click(showhide);
			var w = this.targetwidget = family[j] ;
			if ( w.parentNode != w.offsetParent )
				w.parentNode.style.position = "relative" ;
			if ( j == 2 || j == 5 ) break ; // it's inside the widget: closes only
			w.style.marginTop = '0'; // widget has a top margin for the noscript version
			w.style.display = 'block'; // IE8 needs this explicit
			w.openedBy = this ;
			adjust(w);
			if (!/MSIE \d/.test(navigator.userAgent)) $(window).bind('resize',function(){
				if (w.style.display == 'none') return;
				adjust(w); //IE8 puts it a few thousand pixels to the right here
			});
			if ( !/\bopen\b/.test( this.className ) ) {
				// widgets served with display:block but visibility:hidden for positioning in
				// buggy browsers and so expandable inputs will have width and height (2009):
				$(w).hide();
				this.className = this.className + ' closed' ;
			}
			$(w).css('visibility', 'visible');
			break ;
		}
	}

	function showhide(){
		var w = this.targetwidget ;
		if (typeof(w) == 'undefined') return alert('Sorry, this widget opener has lost its widget.') ;
		if (w.style.display == 'none') w.openedBy = this ;
		$(w.openedBy).toggleClass('open').toggleClass('closed');
		if (!/MSIE \d/.test(navigator.userAgent))
			$(w).slideToggle(e2.fxDuration);
		else // slideToggle generally fails on positioned elements in IE8
			w.style.display = 'blocknone'.replace(w.style.display||'block','');
		adjust(w);
		if (w.style.display == 'block') $('textarea', w).focus();
	}

	function adjust(widget){ // put the widget in the right place
		widget.style.top = ''+(widget.openedBy.offsetHeight)+'px'; // directly under opener
		widget.style.left = widget.style.marginLeft = 0;
		var opener = $(widget.openedBy);
		widget=$(widget);
		var adjust = opener.offset().left-widget.offset().left;
		widget.css('left',adjust); // left-aligned to opener...
		adjust = $(window).width()-widget.offset().left-widget.outerWidth(true);
		if (adjust<0) widget.css('margin-left', adjust); // or right-aligned to window if it would overflow
	}
});

// browsers don't spell-check read-only form elements,
// so editors' view of the source of review drafts is not readonly.
// -> stop edits before they can cause confusion:
e2('textarea.readonly', function(){
	$(this).bind('keydown keypress keyup textInput', function(e){
//		for(i=this.value.length; i>=0; i--){this.setSelectionRange(i, i);} // provoke spell-check in webkit
		this.originalValue = this.value;
		if (e.which > 47 || e.which == 32){ // only stop real character keys...
			e.stopImmediatePropagation();
			e.preventDefault();
			this.value = this.originalValue; // but make sure.
		}
	});
});

e2('.wuformaction', 'click', function(){
	// elements of class wuformaction need a different op in the big form enclosing writeups.
	// to avoid duplication of names and other Bad Stuff in category and weblog forms in writeups, we only give
	// their controls the right attributes when their button is clicked.
	// this becomes redundant and is removed for some (but not all) elements with active ajax.
	if (this.form.onsubmit && !this.form.onsubmit()) return ;
	if (!this.form.op) $(this.form).append('<input type="hidden" name="op" value="vote">');
	this.form.op.value=this.value ;
	var nodeid = this.name.replace( /[^0-9]+/ , '' ) ;
	for ( var i = 0 , names = [ "nid" , "cid" , "target" , "source" ] ; names[i] ; i++ )
		if ( this.form[ names[i] + nodeid ] )
			this.form[ names[i] + nodeid ].name = names[i] ;
	$(this.form).submit();
	this.form.op.value = 'vote';
});

// Wrapper so we can have a named function to avoid dozens of identical anonymous functions
(function(){

	var MIDDLE_MOUSE = 2;

	function addLastnode() {
		e2.setLastnode.call(this, e2.lastnode_id);
	}

	function addLastnodeMouseup(e) {
		if (e.which != MIDDLE_MOUSE) return;
		addLastnode.call(this);
	}

	e2('body.writeuppage #mainbody .item .content a'
		+ ', body.writeuppage #softlinks a'
		+ ', body#findings #mainbody li a'
		, function(index, el) {
			// Don't put a lastnode_id on external links
			if (!$(el).hasClass('externalLink')) {
				e2.setLastnode.call(el);
				$(el).click(addLastnode).mouseup(addLastnodeMouseup);
			}
		}
	);

})();

// extensible unload warning setup: jQuery bind() won't hack it (fails in version 1.3, later (?<1.8) have IE9 problems)
e2.beforeunload = {};
window.onbeforeunload = function(e){
	var events = 'focusin focus keydown keypress scroll click'
	  , things = $(document).add(window)
	  , jQUiStyle = $('<link id="jQueryUiStylesheet" rel="stylesheet" href="https://ajax.googleapis.com/ajax/libs/jqueryui/1.8.14/themes/smoothness/jquery-ui.css">');


	for (var fn in e2.beforeunload){
		var func = e2.beforeunload[fn];
		var str = func(e);
		if (str){
			if (!$('#jQueryUiStylesheet', 'head')[0]) $('head').append(jQUiStyle);
			$('<div id="unloadWarning">'+str+'</div>')
			.dialog({
			  position: { my: "center top", at: "center top", of: window }
			});
			things.bind(events, cleanUp);
			return (e.returnValue = str);
		}
	}

	function cleanUp(e){
		$('#unloadWarning').remove();
		things.unbind(events, cleanUp);
	}
};

// warn about unsaved edits in textareas
(function(){
	var events = 'keydown keypress keyup textInput';

	function markUnsaved(){
		$(this).addClass('unsaved');
		$(this.form).bind('submit', function(){
			// added long after pageload: fires after any possibility of stopping submission
			$('textarea', this).removeClass('unsaved');
		});
		$(this).unbind(events, markUnsaved);
	}

	e2('textarea[name*="_doctext"]', 'bind', [events, markUnsaved]);

	e2.beforeunload.saveedits = function(e){
		var opus = $('textarea.unsaved')[0];
		if (!opus) return;
		var what = opus.getAttribute('id') == 'writeup_doctext'
			? 'your writeup/draft'
			: 'a text area';
		return 'You have made changes to ' + what + ' which will be lost if you leave this page now.';
	};
})();

// Begin contents of old Zen Nodelet Collapser code
if(! e2.nonodeletcollapser )
{
  e2.nodeletCollapser = {
	save: (e2.ajax && !e2.guest ?
		function(id){
			if (id) $('#'+id).addClass('pending');
			e2.ajax.varChange('collapsedNodelets', e2.collapsedNodelets || '0', function(){
				if (id) $('#'+id).removeClass('pending');
			}) ;
		}
		:
		function(){
			e2.setCookie('collapsedNodelets', e2.collapsedNodelets, 7); //days
	  	}
	),
	
	existing: '',

	activate: function(){
		var nodelet_id = this.parentNode.id;
		var re = new RegExp( '\\b'+nodelet_id+'\\b' );
		if(re.test(e2.collapsedNodelets)) {
			$('#'+nodelet_id+' .nodelet_content').hide();
			$(this).addClass('closed');
			e2.nodeletCollapser.existing = e2.nodeletCollapser.existing + nodelet_id + '!';
		} else {
			$(this).addClass('open');
		}

		$(this).css('cursor', 'pointer')

		.click(function(e){
			var nodelet_id = this.parentNode.id;
			$('#'+nodelet_id+' .nodelet_content').slideToggle(e2.fxDuration);
			$(this).toggleClass('open').toggleClass('closed');
			var re =new RegExp( '\\b'+nodelet_id+'!' );
			if (re.test(e2.collapsedNodelets)){
				e2.collapsedNodelets = e2.collapsedNodelets.replace( re , '' );
			}else{
				e2.collapsedNodelets = e2.collapsedNodelets + nodelet_id + '!';
			}
			e2.nodeletCollapser.save(nodelet_id);
			if (e.ctrlKey) $('.nodelet_title.' + ($(this).hasClass('open') ? 'closed' : 'open')).click();
		});
	}
  };

  e2('#sidebar '+(e2.guest ? '#signin ' : '')+'.nodelet_title', e2.nodeletCollapser.activate);
 
  $(function(){
	if (!$('#sidebar')[0] || $('#sidebar').hasClass('pagenodelets')) return;
	if (e2.collapsedNodelets.split('!').length != e2.nodeletCollapser.existing.split('!').length){
		e2.collapsedNodelets = e2.nodeletCollapser.existing;
		e2.nodeletCollapser.save();
	}
  });
}

//End contents of old Zen nodelet collapsed code

//Begin contents of Everything2 AJAX 

if(! e2.noquickvote)
{
  $.ajaxSetup({
	type: 'POST',
	url: window.location.protocol+'//'+window.location.hostname+((window.location.port != "")?(":"):(""))+window.location.port+"/index.pl",
	// hostname included for Guest User on non-canonical domain with canonical base element in html head
	cache: false,
	dataType: 'text',
	timeout: e2.timeout * 1000
  });

  e2.ajax = {
  // legacy non-production E2AJAX.functions are in [Additional Everything2 Ajax] (in Javascript Repository)

  // ======================= Utility

	pending: {},
	htmlcode: function(htmlcode, params, callback, pendingId){
	// htmlcode is the name of an htmlcode. See [ajax update page] for security requirements.
	// params is comma-separated args for htmlcode, or an object optionally containing query
	// parameters (query), htmlcode args (args) and/or ajax parameters (ajax)
		if (typeof params != 'object') params = {args: (params || '').toString()};
		var ajax = params.ajax || {};
		ajax.data = ajax.data || params.query || {};
		ajax.data.args = ajax.data.args || params.args || '';
		ajax.data.htmlcode = htmlcode ;
		ajax.data.node_id = ajax.data.node_id || e2.node_id;
		ajax.data.displaytype = 'ajaxupdate';
		ajax.complete = ajax.complete || ajaxFinished;

		if (pendingId && !ajax.data.ajaxIdle)
			e2.ajax.pending[pendingId] = {htmlcode: htmlcode, query: ajax.data};
		$.ajax(ajax);

		function ajaxFinished(request, statusText){
			if (pendingId) delete e2.ajax.pending[pendingId];
			if (!callback) return;
			var success = statusText == 'success' && (ajax.dataType=='json' ||
				/<[!]-- AJAX OK/.test(request.responseText)); // [!] = fix for brain-dead GPRS network
			if (success)
				var str = request.responseText.replace( /<[!]-- AJAX OK[\s\S]*/ , '' );
			else if (statusText == 'success')
				statusText = 'incomplete response';
	   		else if (statusText != 'timeout')try{
				if (request.status==0)
					throw 'sometimes even the test throws an exception';
				else if (request.status >= 500)
					statusText = 'server error';
			}catch(e){
				statusText = 'connection error';
			}
			callback((success ? str : request), success, statusText || '(unknown error)');
		}
	},

	update: function(id, htmlcode, args, replaceID, callback) {
		var ol = $('#'+id), nu;
		if (!ol[0]) return;
		if (replaceID == null) replaceID = 1;
		e2.ajax.htmlcode(htmlcode, args, ajaxFinished, id);

		function ajaxFinished(result, success, statusText){
			if (success){
				if (replaceID) {
					nu = $($.parseHTML(result));
					ol.replaceWith(nu);
				}else{
					ol.html(result);
					nu = $('*', ol);
				}
				e2(nu);
			}
			if (callback) callback(result, success, statusText);
		}
	},

	varChange: function(name, value, callback){
	// NB: name and value have to pass check in htmlcode ajaxVar
		e2.ajax.htmlcode('ajaxVar', name+','+value, callback);
		e2.deleteCookie(name);
	},

	starRateNode: function (node_rate, weight, seed, nonce) {
		$.ajax({data:{
			op : "starRate",
			rating_node : node_rate,
			rating: weight,
			starrating_seed: seed,
			starrating_nonce: nonce,
			displaytype: 'ajaxupdate'
		}});
	},

  // ======================= Sleep/wake

	addRobot: function(x){
		// first time called, set up sleep and wake. Subsequent times just add x to list.
		e2.ajax.addRobot = function(y){ robots.push(y); };

		e2.inactiveWindowMarker = e2.inactiveWindowMarker || '';
		var	windowId = e2.getUniqueId(),
			lastActive = e2.now(),
			lastZzz = 'wake',
			wakeEvents = 'focusin focus mouseenter mousemove mousedown keydown keypress scroll click',
			wakeWatch = $(document).add(window).bind(wakeEvents, wake).blur(monitor),
			robots = [new e2.periodical(monitor, 60), x]; // monitor will put itself to sleep

		function monitor(){
			wakeWatch.unbind(wakeEvents, wake).bind(wakeEvents, wake);
			var myCookie = e2.getCookie('lastActiveWindow');
			if (e2.now() - lastActive > e2.sleepAfter * 60000 ||
				(!e2.isChatterlight && myCookie && myCookie != windowId)) zzz('sleep');
		}

		function wake(e){
			// anything this event should do inside the page has been done. Once is enough for this:
			e && e.stopImmediatePropagation();
			wakeWatch.unbind(wakeEvents, wake); // once a minute is enough
			lastActive = e2.now();
			e2.setCookie('lastActiveWindow', windowId);
			zzz('wake');
		}

		function zzz(z){
			if (lastZzz == z) return;
			$(robots).each(function(){this[z]();});
			lastZzz = z;
			titleLength = document.title.length - e2.inactiveWindowMarker.length;
			document.title = (z == 'sleep' ? document.title + e2.inactiveWindowMarker
				: document.title.substr(0, titleLength));
		}
	},

  // ======================= list management

	lists: {},

	addList: function(listName, listSpec){
		e2.ajax.lists[listName] = listSpec;
		e2('#'+listName, function(){
			if (!e2.ajax.lists[this.id].manager){
				e2.ajax.lists[this.id].manager = new e2.ajax.listManager(this.id);
			}else{
				e2.ajax.lists[this.id].manager.restart();
			}
		});
	},

	listManager: function(listName){
		function updateThisList(){
			e2.ajax.updateList(listName);
		}
		e2.periodical.call(this, updateThisList,
			e2.ajax.lists[listName].period || e2.defaultUpdatePeriod * 60,
			e2.ajax.lists[listName].stopAfter, e2.ajax.lists[listName].die);
		e2.ajax.addRobot(this);
	},

	updateList: function(listName, query, callback){
		var container = $('#'+listName);
		var list = e2.ajax.lists[listName];
		if (!container[0] || !list) return;
		$('.markedForRemovalNextTime', container).remove();
		if (query == null) query = {ajaxIdle: 1}; // query only passed if user action causes update
		var listCallback = false;
		e2.ajax.htmlcode(list.getJSON,
			{args: list.args, query: query, ajax:{dataType: 'json', success: doJSON}}, callback);

		function doJSON(data){
			for (var i = 1, keep = {}; data[i]; i++){
				var id = list.idGroup + data[i].id;
				keep[id] = true;
				if (!$('#'+id)[0]){
					var el = $(data[i].value);
					if (!el.attr('id'))
						el.attr('id', id);
					if (data[i].timestamp)
						el.addClass('timestamp_' + data[i].timestamp);
					e2.ajax.insertListItem(container, el, data[i].timestamp, list.ascending);
					listCallback = list.callback;
				}
			}
			container.children().each(function(){
				if (!keep[this.id] && this.id.indexOf(list.idGroup)==0 &&
					(!list.preserve || !e2(list.preserve, this)[0])){
					listCallback = list.callback;
					e2.ajax.removeListItem(this);
				}
			});
			if (listCallback) e2(listCallback).defer();
		}
	},

	insertListItem: function(container, content, timestamp, ascending){
		content.hide();
		if (ascending || timestamp){
			container.append(content);
		}else{
			container.prepend(content);
		}
		if (timestamp){
			var dir = (ascending ? 1 : -1 );
			// place above first younger (ascending) or older (descending) item in list
			// if none found, it belongs below them all, where it is
			container.children().each(function(){
				var match = /\btimestamp_(\d+)\b/.exec(this.className);
				if (match && dir*match[1] > dir*timestamp){
					$(this).before(content);
					return false;
				}
			});
		}
		// defer here & in removeListItem so it all happens at once: smoother
		// e2ify content after revealing so expandable inputs have dimensions
		e2(function(){
			content.slideDown(e2.fxDuration, function(){e2(content);});
		}).defer();
	},

	removeListItem: e2(
		function(el){
			// hide the first time, remove in updateList the next time:
			// avoid incoming list reinstating dismissed item
			$(el).slideUp(e2.fxDuration).addClass('markedForRemovalNextTime');
		}
	).defer,

	dismissListItem: function(event){
		var targetId = /\bdismiss\s+(\S+)/.exec(this.className)[1];
		// find which list we're in:
		for (var parent = this.parentNode, spec; parent; parent = parent.parentNode){
			if (parent.id && (spec = e2.ajax.lists[parent.id])) break;
		}
		if (spec && spec.dismissItem)
			e2.ajax.htmlcode(spec.dismissItem, targetId.replace(/\D/g, ''));
		e2.ajax.removeListItem('#'+targetId);
		event.preventDefault();
	},

  // ======================= Update Triggers

	periodicalUpdater: function(instructions, period, lifetime, expired){
		this.className = 'ajax ' + instructions ;
		e2.periodical.call(this, function(){$(this).trigger('click');}, // triggerHandler() fails
			period||e2.defaultUpdatePeriod * 60, lifetime, expired);
		e2.ajax.updateTrigger.call(this);
		e2.ajax.addRobot(this);
	},

	updateTrigger: function(){
		if (this.disabled) return;

		var tag = (this.tagName || '').toLowerCase(); // no tagName if periodical updater
		var $this = $(this);
		if (tag) var type = $this.attr('type');

		if ($this.hasClass('instant')){
			e2.ajax.triggerUpdate.call(this);
		}else if (tag == 'textarea' || type == 'hidden' || type == 'text'){
			$(this.form).unbind('.ajax').bind('submit.ajax', formTrigger);
			this.originalValue = this.value;
		}else{
			var bindEvent = (tag != 'select' ? 'click' : 'change');
			if (/[?&]confirmop=/.test(this.href) && tag != 'a')// links already done
				$this.bind(bindEvent, e2.confirmop);
			$this.bind(bindEvent, e2.ajax.triggerUpdate);
		}

		function formTrigger(event){
			var formSpec = $(this).serializeArray();
			$.each(formSpec, function(n){ // serialize() screws up encoding (1.4.3)
				// put values into object later not string now to avoid encoding snarfs
				formSpec[n] = this.name + '=/';
			});
			formSpec = formSpec.join('&');
			var nothingHappened = true;
			$('textarea.ajax, input[type=text].ajax, input[type=hidden].ajax', this)
			.each(function(){
				if (!this.value) return;
				nothingHappened = e2.ajax.triggerUpdate.call(this, event, formSpec) && nothingHappened;
			});
			return nothingHappened;
		}
	},

	triggerUpdate: function(event, formSpec){
		if (event && event.isDefaultPrevented && event.isDefaultPrevented() && !formSpec){ // confirmop may have done this
			if ( this.checked ) this.checked = false ;
			if ( this.blur ) this.blur() ;
			return false;
		}

		// earlybeforeunload for multi-step processes which will end with a page unload
		// -- don't annoy user by only warning them at the end
		if ($(this).hasClass('earlybeforeunload')){
			var msg = window.onbeforeunload({earlyCall: true});
			if (msg && !confirm(msg + '\n\nIf you continue you will end up '
			  + 'leaving the page. Do you want to continue?')) return false;
		}

		// get ajax instructions from class & chop them up
		var params = ('[0] '+this.className).split(/\bajax\s+/);
		if (!params[1]) return true; // no instructions
		params = params[1].split(/\s+/)[0].replace(/\+/g,' ').split(':');
		if (!params[1]) return true; // no htmlcode

		// target:
		var updateTarget = params[0];
		var updateOnly = (updateTarget.charAt(0) == '(');
		if (updateOnly) updateTarget = updateTarget.slice(1,-1);
		var target = $('#'+updateTarget)
			.find('.error').remove().end(); // only show most recent error
		if (!target[0]) return true;

		var args = params[2] || '';

		// htmlcode & query:
		params = params[1].split('?');
		var htmlcode = params[0];
		if (!params[1] && this.href) params = this.href.split('#')[0].split('?');
		var q = decodeURIComponent(params[1] || formSpec || '').split(/[&=]/);

		// get query values from string/form/prompt
		var query = {};
		for (var i=0; q[i]; i+=2){
			var name = q[i], value = q[i+1];
			if (value && value.charAt(0) == '/' ){
				if ( value.charAt(1) != '#' ){ // get value from form
					var el = this.form[value.substr(1) || name];
					if (el && el.length && el[0].type=='radio') el = $(el).filter(':checked')[0];
					if (el && /radio|checkbox/.test(el.type) && el.checked == false) el = null;
					value = el && el.value;
				} else { // get value from prompt
					value = prompt(value.substr(2)+':' , query[name] || '') ;
					if (!value) return false ;
				}
			}
			if (value != null)
				query[name] = (value && value.replace(
					/[^ -~]/gm, function(x) {return "&#" + x.charCodeAt(0) + ";";})
					) || query[name] || '';
		}

		// remember a couple of things for later:
		var sentValue = this.value;
		$(this).addClass('pending');
		var hadFocus = e2.getFocus(target);
		var isPeriodic = !this.tagName;

		if (!isPeriodic && htmlcode != '#'){
		// disable, but avoid disabled controls when returning from history...
			var ersatz = target.clone().addClass('pending');
			target.replaceWith(ersatz);
			(updateOnly ? $ : e2)('*', ersatz) // e2 = inclusive select: include container if it's to be replaced
			.addClass('pending')
			.each(function(){
				if (this.name){
					if (target[this.name]) this.value = target[this.name].value; // still see changed values
					 // ... by changing name on disabled controls:
					$(this).attr({disabled:'disabled', name:'xxx'});
				}
				this.disabled = true;
				if (this.href && /\bajax\s/.test(this.className)) this.href = '#';
			});
			try { e2(ersatz) } catch(e){};
		}

		// now do it
		var e = this;
		if (htmlcode == '#'){
			e2.ajax.updateList(updateTarget, query, doneUpdate);
		}else{
			if (isPeriodic) query.ajaxIdle = 1;
			e2.ajax.update(updateTarget, htmlcode,
				{query: query , args: args}, !updateOnly, doneUpdate);
		}
		if (event && event.preventDefault) event.preventDefault();
		return false;

		// tidy up/report error afterwards
		function doneUpdate(stringIfsuccessfulOrRequestIfNot, success, statusText){
			$(e).add(ersatz).removeClass('pending') ;

			if (success) {
				if ( e.originalHeight ) e.style.height = e.originalHeight ;
				if ( e.originalValue != null && e.value == sentValue ) e.value = e.originalValue ;
			} else if ( !isPeriodic ) { // periodic updater dies quietly
				var tag = target.css('display') == 'block' ? 'div' : 'span';
				target.append('<'+tag+' class="error"><strong>Error:</strong> '+statusText+'</'+tag+'>');
				if (e.htmlcode == '#') return;
				ersatz.replaceWith(target);
				e2(target); // jquery unbinds all the magic when you take it out of the DOM
			}

			if (hadFocus && $('#'+hadFocus).length)
				e2(function(){$('#'+hadFocus).focus();}).defer() ; // IE8 fails without defer
		}
	}
  // END e2.ajax = {
  };

  // automation
  if (!e2.guest){

	e2.ajax.addList('notifications_list',{ // id of list container
		getJSON: "notificationsJSON", // htmlcode for list data (required)
		args: 'wrap', // htmlcode arguments for getJSON
		idGroup: "notified_", // id stub for individual list items (required):
		// N.B.: items sent with an id keep it. If it doesn't match the idGroup they will never be removed.
		period: 45, // seconds between updates (default is above)
		dismissItem: 'ajaxMarkNotificationSeen' // htmlcode run when item dismissed. arg is id from json
	});

	e2.ajax.addList('chatterbox_messages', {
		ascending: true, // put newest at bottom (default is newest at top)
		getJSON: 'showmessages',
		args: ',j',
		idGroup: 'message_',
		preserve: 'input:checked', // don't remove list items which match or whose contents match this
		period: 23,
		callback: function(){ // called after update iff anything changed
			if ( $('#chatterbox_messages *')[0] && !$('#formcbox hr').length )
				$('#chatterbox_chatter').before('<hr width="40%">');
		}
	});

 	e2.ajax.addList('messages_messages', {
		ascending: true, // put newest at bottom (default is newest at top)
		getJSON: 'testshowmessages',
		args: ',j',
		idGroup: 'message_',
		preserve: '.showwidget .open', // don't remove list items which match or whose contents match this
		period: 23
	});
			
	e2.ajax.addList('chatterbox_chatter', {
		ascending: true,
		getJSON: 'showchatter',
		args: 'json',
		idGroup: 'chat_',
		period: e2.autoChat ? 11 : -1, // -1 creates periodical function in stopped state
  //		preserve: '.chat', // never remove chat items
		callback:(function(){
			// scroll down as chat updated.
			// NB: Without this, slide down of chat is unreliable in IE8, even without scrollbar

			var chat, userScrolled = false,

			scrollChat = new e2.periodical(function(){
				chat.scrollTop = chat.scrollHeight;
			}, -1);


			// tell scrollChat what to scroll, or not to scroll if user has scrolled up
			e2('#chatterbox_chatter', function(){
				scrollChat.restart(jQuery.fx.interval/1000, e2.fxDuration*3/1000);
				$(this)
  //				.addClass('autochat') // limits height and adds scroll bar if needed
				.scroll(function(e){
					userScrolled = (this.scrollHeight - this.scrollTop - this.clientHeight > 16);
				});
				chat = this;
			});

			return function(){
				if (!userScrolled) scrollChat.restart();
			};
		})(),

		stopAfter: e2.sleepAfter * 60, // seconds
		die: function(){
			$('#autoChat').each(function(){this.checked=false;});
			$('#chatterbox *').blur(); // '#chatterbox :focus' fails if window is not focussed
			e2.ajax.insertListItem($('#chatterbox_chatter'), $(
				'<p id="chat_stopped"><strong>Chatterbox refresh stopped.</strong></p>'),0,1);
		}
	});

	e2('.dismiss', 'click', e2.ajax.dismissListItem);

	new e2.ajax.periodicalUpdater('newwriteups:updateNodelet:New+Writeups', 300);
	new e2.ajax.periodicalUpdater('otherusers:updateNodelet:Other+Users');
  }

  // replace other inputs with push buttons
  e2('input.replace', function (){
		var label = this.parentNode ;
		if ( this.name.substr(0,6)=='vote__' &&
				( this.getAttribute( 'value' )=='0' || this.disabled ) )
			return label.parentNode.removeChild(label) ;
		var value = label.innerHTML.replace( /^(<.*>|\s)*|(<.*>|\s)*$/g , '' );
		if ( this.name.substr(0,6)=='vote__' ) value = (value=='+' ? 'Up' : 'Down');
		var b=$('<input type="button" class="' + this.className.replace( /\breplace\b/ , 'replaced' ) +
			'" name="' + this.name + '" title="' + this.title + '" value="' + value + '">')[0];
		$(label).replaceWith(b);
		if (b.outerHTML) b.outerHTML=b.outerHTML; // update DOM in IE7

		// tidy up around replaced inputs
		e2('.vote_buttons .replaced', b).each(function(){
			if (this.previousSibling && this.previousSibling.nodeType==3)
				this.parentNode.removeChild(this.previousSibling);});
  });

  // update nodelet only, not whole page
  e2('div.nodelet', function(){ // div.nodelet to filter out body on nodelet's own page
	if (!(this.nodeletName = $('h2', this)[0]) ) return; // probably a failed nodelet
	this.nodeletName = this.nodeletName.innerHTML;
	var omo = 'ajax '+this.id+':updateNodelet:'+this.nodeletName.replace(/ /g, '+');

	$('form', this).each( function(){
		if (this.onsubmit || this.ajaxTrigger || this.passwd || this.node ||
			(this.node_id && this.node_id.type != 'hidden')) return ;
		dummy = $('<input type="hidden" name="ajaxTrigger" value="1" class="'+omo+'">');
		$(this).append(dummy) ;
		if (dummy.outerHTML) dummy.outerHTML=dummy.outerHTML ; // update DOM in IE7
	});

	if (this.nodeletName == 'Master Control') return; // need pageload to see things happen
	$('a', this).each(function(){
		if (this.href.indexOf(e2.pageUrl+'?')==0 &&
				!/\bajax\b/.test(this.className) &&
				!/[&?]displaytype=|[&?]op=logout|[&?]op=randomnode/.test(this.href))
			$(this).addClass(omo);
	});
  });

  // draggable nodelets
  e2('h2.nodelet_title', 'click', function(e){
	// disables nodelet collapser when nodelet is being dropped
	if ($(this).hasClass('stopClick')) e.stopImmediatePropagation();
  });

  e2('#sidebar:not(.pagenodelets)', 'sortable', {
	axis: 'y',
	containment: 'document',
	items: 'div.nodelet',
	opacity: 0.5,
	handle: 'h2.nodelet_title',
	tolerance: 'pointer',
	cursor: 'n-resize',
	stop: function(e, ui){
		// disable nodelet collapser when nodelet is being dropped
		ui.item.find('h2').addClass('stopClick');
		e2(function(){
			ui.item.find('h2').removeClass('stopClick')
		}).defer();
	},
	update: function(e, ui){
		e2.ajax.htmlcode('movenodelet', ui.item[0].nodeletName + ',' +
			ui.item.prevAll('.nodelet').length,
			null, ui.item[0].nodeletName);
	}
  });

  // activate update triggers
  e2('.wuformaction.ajax', 'unbind'); // ajax makes function to fiddle with form values redundant
  e2('.ajax', e2.ajax.updateTrigger);

  e2.beforeunload['ajax pending'] = function(e){
	e = e || window.event || {}; // for IE/unknown fail
	if (e.earlyCall) return; // window isn't really going to unload until user has done more

	var warnings = {
	// name: htmlcode; value: code to eval to get warning. false = ignore. List from [ajax update page]
	// id = updateTarget, x = update parameters
		ilikeit: '"Your message to the author hasn\'t arrived yet"',
		writeupmessage: "'Your message is being sent'",
		zenDisplayUserInfo: "'Your message is being sent'",
		weblogform: "'A usergroup page is being updated'",
		categoryform: "'A category is being updated'",
		writeupcools: "'Your C! is being noted. You may lose it if you don\\'t let it finish'",

		updateNodelet: "'The '+x.query.args+' nodelet is updating'",
		coolit: "'This page is being ' +" +
			"(x.query.coolme ? 'dunked in liquid helium' : 'thawed')",
		bookmarkit: "(x.query.bookmark_id == e2.node_id ? 'This page' : 'A writeup') +" +
			"' is being added to your bookmarks'",

		favorite_noder: "opcode(x.query.op)",
		voteit: "opcode(x.query.op)",
		movenodelet: "'The ' + id + ' nodelet\\'s new position is being recorded'",
		// these we ignore:
		listnodecategories: 'false', // instant ajax for info/confirmation only
		nodeletsettingswidget: 'false', // user lost interest in settings
		 // these shouldn't be needed:
		changeroom: '', showmessages: '',
		showchatter: '', displaynltext2: ''
	};

	var str;
	function opcode(op){
		if (!op) return '';
		switch(op){
			case 'vote': return 'Your vote is being recorded';
			case 'favorite': str = 'added to';
			case 'unfavorite': return $('#pageheader h1').text()  +' is being ' +
				(str || 'removed from') + ' your favorite users list';
			case 'hidewriteup': str = 'hidden'; break;
			case 'unhidewriteup': str = 'unhidden'; break;
		 	case 'massacre': str ='nuked'; break;
		 	case 'insure': str = (/undo/.test($('#'+id+' a').text()) ? 'un' : '') +
			 	'insured'; break;
		 	default: str = 'processed';
		}
		return 'A writeup is being ' + str;
	}

	for (var id in e2.ajax.pending){
		var x = e2.ajax.pending[id];
		if (warnings[x.htmlcode] && (str = eval(warnings[x.htmlcode]))) break;
	};
	if (x && str !== false) str = // was something pending, and not to be ignored
		(str || 'Something on this page is being updated') +
		". Please wait a moment.";
	return str;
  };

  // rename vote button: no longer needed, but can still send form
  $(function(){
	$('#votebutton').each(function(){
		this.value = 'blab!' ;
		this.title = 'send writeup message(s)' ;
	});
  });

  // switch automatic chatter update on and off
  e2('#chatterbox:not(.pending)', function(){
	function onOff(on){
		if (on){
			e2.ajax.updateList('chatterbox_chatter');
			e2.ajax.lists.chatterbox_chatter.manager.restart(11);
		}else{
			e2.ajax.lists.chatterbox_chatter.manager.restart(-1);
  		}
	}

	// checkbox to turn it on and off
	$('#autoChat').parent().remove(); // may be one left over if update failed
	$('#message_send').after(
		' <label title="Keep chat up to date even if the focus/cursor is somewhere else">'+
		'<input type="checkbox" value="1" name="autoChat" id="autoChat"'+
		(e2.autoChat ? ' checked="checked"' : '') + '>Keep updating</label>')
	.next().find('input') // click can't go on label or you get two clicks
	.click(function(e){
		onOff(e2.autoChat = this.checked);
		if (!e2.isChatterlight) e2.setCookie('autoChat', e2.autoChat ? '1' : '0');
		$('#message').focus();
	});

	// always update when focus is in chatterbox
	$(this)
	.focusin(function(){
		onOff(true); // do this even if autoChat is on, to restart inactivity countdown
		if (e2.getFocus(this) == 'autoChat') return; // don't check it or the click will uncheck it
		$('#autoChat', this)[0].checked = e2.autoChat; // is unchecked if autoChat has died
	})
	.focusout(function(){
		if (!e2.autoChat) onOff(false);
	});
  });

  if (e2.isChatterlight) e2('#message', e2(function(){
	$(this).css('width','').focus();
  }).defer); // defer for IE 
}
// End contents of Everything2 AJAX

// Begin contents of settings script
e2.deleteCookie('settings_useTinyMCE');

void new function(zensheet){
	if (!zensheet) return;

	var originalTheme = zensheet.href;
	var originalSpeed = e2.fxDuration;
	var themeMenu = $("#settings_styleselector")[0];

	// give previews of the effects of a couple of settings on the [Settings] page
	if (themeMenu){
		$(themeMenu).change(newTheme);
		$('<label><input type="checkbox" id="showThemePreview" value="1" '+
				'checked="checked">Preview theme</label>')
			.insertAfter(themeMenu); // theme menu has no label
		var themeOption = $('#showThemePreview').click(newTheme)[0];
	}

        if(!e2.guest)
        {
	     // drag and drop nodelet menus on [Nodelet Settings] page
	     $('#rearrangenodelets')
//           .disableSelection()
	     .css({
		cursor: 'n-resize',
//		'list-style-image': 'url("")', up-down arrow, anybody?
		'list-style-position': 'inside' // no frustration when dragging with the blob
  	     })
	     .sortable({
		axis: 'y',
		update: function(){
	   		$('#rearrangenodelets select').each(function(n){
				this.name = 'nodeletedit' + (n+1);
      		})
	   	}
	     })
	     .find('li').append(' &ndash;&#x2195;&ndash;');
        }

	function newTheme(){
		if (!themeOption.checked || $(this).attr('selected'))
			return zensheet.href = originalTheme;
		zensheet.href=(themeMenu.value != 'default' ?
			'/node/'+themeMenu.value :
			'/node/stylesheet/'+THEME.default_style) + '?displaytype=serve';
	}

	function widget(){ $('#speedtest').trigger('click'); }

	function newSpeed(event){
		e2.fxDuration = (1 * this.value) || 200;
		if(e2.fxDuration == 1){
			jQuery.fx.off = true;
		}else{
			jQuery.fx.off = false;
		}
		widget();
		setTimeout(
			function(){
				widget();
				e2.fxDuration = originalSpeed;
			},
			Math.max(e2.fxDuration*2,100) );
	}
}(document.getElementById('zensheet'));

// End contents of settings script 

// 1985920.js sortlist
// Used in showbookmarks

// by Bruno Bornsztein - www.feedmarker.com or blog.feedmarker.com
// You're free to use this however you want. You can even take this
// attribution out if you like.

// Make sure the list you want to sort has a unique id Then create a
// link to sort the list in the following format: <a
// href="javascript:void(0);" onclick="sort(this)" list_id="the id of
// the list you want to sort" order="asc or desc">Sort</a> that will
// just just the list by it list item values

// if you want to sort by an attribute you've included within each
// list item (i.e. <LI size="10">), just do this: // <a
// href="javascript:void(0);" onclick="sort(this)" list_id="the id of
// the list you want to sort" order="asc or desc" sortby="your
// attribute">Sort</a>

function ts_getInnerText(el) {
  //Thanks to http://www.kryogenix.org/code/browser/sorttable/ for this function
	if (typeof el == "string") return el;
	if (typeof el == "undefined") { return el; };
	if (el.innerText) return el.innerText;	//Not needed but it is faster
	var str = "";

	var cs = el.childNodes;
	var l = cs.length;
	for (var i = 0; i < l; i++) {
		switch (cs[i].nodeType) {
		case 1: //ELEMENT_NODE
			str += ts_getInnerText(cs[i]);
			break;
		case 3:	//TEXT_NODE
			str += cs[i].nodeValue;
			break;
		}
	}
	return str;
}


function ts_getInnerText(el) {
	if (typeof el == "string") return el;
	if (typeof el == "undefined") { return el; };
	if (el.innerText) return el.innerText;	//Not needed but it is faster
	var str = "";

	var cs = el.childNodes;
	var l = cs.length;
	for (var i = 0; i < l; i++) {
		switch (cs[i].nodeType) {
		case 1: //ELEMENT_NODE
			str += ts_getInnerText(cs[i]);
			break;
		case 3:	//TEXT_NODE
			str += cs[i].nodeValue;
			break;
		}
	}
	return str;
}

function parse_list_to_array(list_id, attribute){
	var list = document.getElementById(list_id);
	var cs = list.childNodes;
	var list_array = new Array();

	var l = cs.length;
	for (var i = 0; i < l; i++) {
    node = cs[i];
    if (node.nodeName == "LI"){
      if(!attribute){
        var value = ts_getInnerText(node);
        list_array.push([node, value]);
      } else{
        list_array.push([node, node.getAttribute(attribute)]);
      }
	  }
  }

  //returns an array with the node in [0] and the attribute in [1]
  return list_array;
}


function sort(link){

  var list_id = link.getAttribute('list_id');
  var order = link.getAttribute('order');
  var sortby = link.getAttribute('sortby');

  if (order == 'desc'){
    order = 'asc';
    link.setAttribute('order','asc');
  } else {
    order = 'desc';
    link.setAttribute('order','desc');
  }

  var array = parse_list_to_array(list_id, sortby);

  // Work out a type to sort by
  var itm = array[1][1];
  var sortfn = mysortfn_by_attribute;
  if (itm.match(/^[\d\.]+$/)) sortfn = ts_sort_numeric;


  array.sort(sortfn);

  switch (order){
  case "desc":
    array.reverse();
    break;
  }

  var list = document.getElementById(list_id);

  for (var k = 0; k < array.length; k++){
    list.appendChild(array[k][0]);
  }

  return;
}

function mysortfn_by_attribute(a,b) {

  // Note that each thing we are passed is an array, so we don't
  // compare the things we're passed; instead, we compare their second
  // column

  if (a[1]<b[1]) return -1;
  if (a[1]>b[1]) return 1;
  return 0;
}

function ts_sort_numeric(a,b) {
  var aa = a[1];
  if (isNaN(aa)) aa = 0;
  var bb = b[1];
  if (isNaN(bb)) bb = 0;
  return bb-aa;
}

// Used on classic user edit page to enable Check All button

if ($('#bookmarklist li'))
{
  if ($('#bookmarklist li').length > 1)
  {
    $('#checkall').show().click(function(){jQuery('#bookmarklist input').attr('checked','true');});
  }
}

// Basic E2 markup parsing functions

function linknodetitle(text_to_parse)
{
  var linkparts = text_to_parse.split(/\s*[|\]]+/,2);
  var nodename = linkparts[0];
  var title = linkparts[1];

  if(typeof title == 'undefined')
  {
    title=nodename;
  }

  if(typeof title == 'string' && title.match(/^\s*$/i))
  {
    title=nodename;
  }

  return '<a href="/node/title/'+encodeURI(nodename)+'">'+title+'</a>';
}

function linkparse(text_to_parse)
{
  var regularlinks = /\[([^[\]]*(?:\[[^\]|]*[\]|][^[\]]*)?)]/gi;
  return text_to_parse.replace(regularlinks, function(matching_text,n1){return linknodetitle(n1)});
}

// Messagebox widget as #messagebox
$("#messagebox").submit(function(event){
  event.preventDefault();

  postdata = JSON.stringify({for_id: $("#messagebox input[name=for_id]").val(), 
    message: $("#messagebox textarea[name=message]").val()
  });
  set_disabled = function(state){
    ["textarea[name=message]","input[name=submitbutton]"].forEach(function(item){
      $("#messagebox "+item).attr("disabled",state);
    });
  };

  $.ajax({
    url: '/api/messages/create',
    beforeSend: function(xhr,settings) {
      set_disabled(true);
    },
    type: 'POST',
    dataType: 'json',
    contentType: 'application/json; charset=utf-8',
    data: postdata,
    success: function(result) {
      set_disabled(false);
      $("#messagebox textarea[name=message]").val("");
      $("#messageboxresult").html("Message sent");
    },
    error: function(xhr, resp, text) {
      set_disabled(false);
      $("#messageboxresult").html("Message sending failed");
      console.log(xhr, resp, text);
    },
  });
});
