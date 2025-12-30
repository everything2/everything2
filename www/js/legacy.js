// 1874924.js "default javascript"
// Used on every pageload

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
  sleepAfter: 17, // minutes
  linkparse: function(text_to_parse)
    {
      var regularlinks = /\[([^[\]]*(?:\[[^\]|]*[\]|][^[\]]*)?)]/gi;
      return text_to_parse.replace(regularlinks, function(matching_text,n1){return linknodetitle(n1)});
    }
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
		// Trim leading/trailing whitespace from search input
		var searchInput = $('#node_search');
		searchInput.val(searchInput.val().trim());

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
			}else if (this.className && /\bconfirmop=/.test(this.className)){
				// Handle AJAX requests where query is in className (e.g., voting buttons)
				var parname = /\bnotanop\b=([^?&]*)/.exec( this.className ) || 'op';
				if (parname.index){ // notanop
					parname = parname[1] ;
					this.className = this.className.replace( /\bnotanop\b=([^?&]*)/ , '');
				}
				this.className = this.className.replace( /\bconfirmop=/ , parname + '=' );
			}else{
				this.name = this.form.notanop ? this.form.notanop.value : 'op';
			}
		}
	},
	
	// jQuery.append() calls scripts with AJAX and runs them, which doesn't always work (version 1.4.3):
	// it fails on load for JS QuickTags HTML toolbar and on run for tinyMCE 2.0, for example. So:
	loadScript: function(x){
          if(x !== undefined)
          {
            // x is an url or a bogus script element made with jQuery('...') ('bogus' = fails except in FF)
            var scr = document.createElement('script');
            scr.setAttribute('type', 'text/javascript');
            scr.setAttribute('src', (typeof x == 'string' ? x : x.src));
            $('head')[0].appendChild(scr);
          }
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
		var aids = {
			active: {},

			// No library here since the functions are below
                        // The load function just skips a blank library attribute
			'HTML toolbar': {
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
			// Check both href and className for confirmop (AJAX voting uses className)
			if ((/[?&]confirmop=/.test(this.href) || /[?&]confirmop=/.test(this.className)) && tag != 'a')// links already done
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
				query[name] = (value && 
                    value.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
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

	// DEPRECATED: Notifications now handled by React component
	// Legacy notification polling removed - all users have React Notifications nodelet
	// e2.ajax.addList('notifications_list',{ ... });

	// LEGACY CHATTERBOX AJAX REMOVED - Now handled by React polling system
	// See: react/components/Nodelets/Chatterbox.js
	// Uses: react/hooks/useChatterPolling.js + react/hooks/useActivityDetection.js
	// API: /api/chatter/ (GET) and /api/chatter/create (POST)

// REMOVED: 	e2.ajax.addList('chatterbox_messages', {
// REMOVED: 		ascending: true, // put newest at bottom (default is newest at top)
// REMOVED: 		getJSON: 'showmessages',
// REMOVED: 		args: ',j',
// REMOVED: 		idGroup: 'message_',
// REMOVED: 		preserve: 'input:checked', // don't remove list items which match or whose contents match this
// REMOVED: 		period: 23,
// REMOVED: 		callback: function(){ // called after update iff anything changed
// REMOVED: 			if ( $('#chatterbox_messages *')[0] && !$('#formcbox hr').length )
// REMOVED: 				$('#chatterbox_chatter').before('<hr width="40%">');
// REMOVED: 		}
// REMOVED: 	});

	// LEGACY MESSAGES AJAX REMOVED - Now handled by React Messages nodelet
	// See: react/components/Nodelets/Messages.js
	// Uses: /api/messages endpoint

// REMOVED: 	e2.ajax.addList('chatterbox_chatter', {
// REMOVED: 		ascending: true,
// REMOVED: 		getJSON: 'showchatter',
// REMOVED: 		args: 'json',
// REMOVED: 		idGroup: 'chat_',
// REMOVED: 		period: e2.autoChat ? 11 : -1, // -1 creates periodical function in stopped state
// REMOVED:   //		preserve: '.chat', // never remove chat items
// REMOVED: 		callback:(function(){
// REMOVED: 			// scroll down as chat updated.
// REMOVED: 			// NB: Without this, slide down of chat is unreliable in IE8, even without scrollbar
// REMOVED: 
// REMOVED: 			var chat, userScrolled = false,
// REMOVED: 
// REMOVED: 			scrollChat = new e2.periodical(function(){
// REMOVED: 				chat.scrollTop = chat.scrollHeight;
// REMOVED: 			}, -1);
// REMOVED: 
// REMOVED: 
// REMOVED: 			// tell scrollChat what to scroll, or not to scroll if user has scrolled up
// REMOVED: 			e2('#chatterbox_chatter', function(){
// REMOVED: 				scrollChat.restart(jQuery.fx.interval/1000, e2.fxDuration*3/1000);
// REMOVED: 				$(this)
// REMOVED:   //				.addClass('autochat') // limits height and adds scroll bar if needed
// REMOVED: 				.scroll(function(e){
// REMOVED: 					userScrolled = (this.scrollHeight - this.scrollTop - this.clientHeight > 16);
// REMOVED: 				});
// REMOVED: 				chat = this;
// REMOVED: 			});
// REMOVED: 
// REMOVED: 			return function(){
// REMOVED: 				if (!userScrolled) scrollChat.restart();
// REMOVED: 			};
// REMOVED: 		})(),
// REMOVED: 
// REMOVED: 		stopAfter: e2.sleepAfter * 60, // seconds
// REMOVED: 		die: function(){
// REMOVED: 			$('#autoChat').each(function(){this.checked=false;});
// REMOVED: 			$('#chatterbox *').blur(); // '#chatterbox :focus' fails if window is not focussed
// REMOVED: 			e2.ajax.insertListItem($('#chatterbox_chatter'), $(
// REMOVED: 				'<p id="chat_stopped"><strong>Chatterbox refresh stopped.</strong></p>'),0,1);
// REMOVED: 		}
// REMOVED: 	});

	e2('.dismiss', 'click', e2.ajax.dismissListItem);

	// LEGACY OTHER USERS AJAX REMOVED - Now handled by React polling
	// See: react/components/Nodelets/OtherUsers.js
	// Uses: react/hooks/useOtherUsersPolling.js (2-minute intervals)
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

function EncodeHtml(t){  
  return $('<div/>').text(t).html();  
}  
 
function DecodeHtml(h){  
  return $('<div/>').html(h).text();  
} 

function SwapGravatars(){
   var g = $('#gravatarType').val();
   $("img[src*='gravatar.com']").each(function(){
      $(this).attr('src', $(this).attr('src').replace('?d=identicon&', '?d='+g+'&'));
      $(this).attr('src', $(this).attr('src').replace('?d=monsterid&', '?d='+g+'&'));
      $(this).attr('src', $(this).attr('src').replace('?d=wavatar&', '?d='+g+'&'));
   });
}

/* HTMLToolBar - Editor code, previously node_id 2069738.js */
// Based on JS QuickTags version 1.3.1
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

/* Google Analytics 4 - gtag.js loaded via htmlcode displayHead */
window.dataLayer = window.dataLayer || [];
function gtag(){dataLayer.push(arguments);}
gtag('js', new Date());

// Configure GA4 with user login status custom dimension
// Requires creating 'user_login_status' custom dimension in GA4 Admin
var userLoginStatus = (window.e2 && window.e2.guest === 0) ? 'logged_in' : 'guest';
gtag('config', 'G-2GBBBF9ZDK', {
  'user_login_status': userLoginStatus
});

// Ad blocker detection - sends event after page load
// Requires creating 'ad_status' custom dimension in GA4 Admin
window.addEventListener('load', function() {
  setTimeout(function() {
    var adStatus = 'no_ad_slot'; // default: no ad element on page
    var adElement = document.querySelector('.adsbygoogle');

    if (adElement) {
      // Ad slot exists, check if it rendered
      if (adElement.offsetHeight > 0 && adElement.querySelector('iframe')) {
        adStatus = 'ad_shown';
      } else if (typeof window.adsbygoogle === 'undefined') {
        adStatus = 'blocked_script'; // AdSense script blocked
      } else {
        adStatus = 'blocked_render'; // Script loaded but ad didn't render
      }
    }

    gtag('event', 'ad_check', {
      'ad_status': adStatus,
      'user_type': userLoginStatus
    });
  }, 3000); // Wait 3s for ads to load
});

// Editor cool and bookmark toggle functions for page-level buttons
// These will be moved to React components when React takes over the page header
window.toggleEditorCool = async function(nodeId, button) {
  try {
    const response = await fetch(`/api/cool/edcool/${nodeId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });

    const data = await response.json();

    if (!data.success) {
      throw new Error(data.error || 'Failed to toggle editor cool');
    }

    // Update button state
    const isCooled = data.edcooled;
    button.setAttribute('data-cooled', isCooled ? '1' : '0');
    button.style.color = isCooled ? '#f4d03f' : '#999';
    button.title = isCooled ? 'Remove editor cool' : 'Add editor cool (endorsement)';
  } catch (error) {
    console.error('Error toggling editor cool:', error);
    alert(`Failed to toggle editor cool: ${error.message}`);
  }
};

window.toggleBookmark = async function(nodeId, button) {
  try {
    const response = await fetch(`/api/cool/bookmark/${nodeId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });

    const data = await response.json();

    if (!data.success) {
      throw new Error(data.error || 'Failed to toggle bookmark');
    }

    // Update button state
    const isBookmarked = data.bookmarked;
    button.setAttribute('data-bookmarked', isBookmarked ? '1' : '0');
    button.style.color = isBookmarked ? '#4060b0' : '#999';
    button.title = isBookmarked ? 'Remove bookmark' : 'Bookmark this page';
  } catch (error) {
    console.error('Error toggling bookmark:', error);
    alert(`Failed to toggle bookmark: ${error.message}`);
  }
};
