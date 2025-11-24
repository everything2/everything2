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
		// e2.collapsedNodelets = e2.nodeletCollapser.existing;
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
				query[name] = (value && 
                    value.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
					) || query[name] || '';

			console.log(query[name])
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

 	e2.ajax.addList('messages_messages', {
		ascending: true, // put newest at bottom (default is newest at top)
		getJSON: 'testshowmessages',
		args: ',j',
		idGroup: 'message_',
		preserve: '.showwidget .open', // don't remove list items which match or whose contents match this
		period: 23
	});
			
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

/* [E2 Rot13 Encoder] / 1271440 */
$("input[name='e2_rot13_encoder']").click(function() {
  var do_rot13 = function(str){
    var am="abcdefghijklmABCDEFGHIJKLM";
    var nz="nopqrstuvwxyzNOPQRSTUVWXYZ";
    for(var i=0;i<str.length;i++)
    {
      var ch=str.charAt(i);
      var ca=am.indexOf(ch);
      if(ca>=0){ str=str.substr(0,i)+nz.charAt(ca)+str.substr(i+1);}else{
        var cz=nz.indexOf(ch);
        if (cz>=0) str=str.substr(0,i)+am.charAt(cz)+str.substr(i+1);
      }
    }
    return str
  };
  $("textarea[name='rotter']").val(do_rot13($("textarea[name='rotter'").val()));
});

/* [Everything Quote Server / 407437 */
$("#quoteserver").html(function() {
  var quoteserver = [
    "[To Shape Teh Future!|TSTF], dude",
    "BROCCOLI IS THE MOST INTELLIGENT OF ALL VEGETABLES!!! YOU DARE... DEFY... BROCCOLI!?! <br><br>--[zot-fot-piq]",
    "Might does make Right - that's why it rhymes.<br><br>--[dem bones]",
    "Reading books in general is a [bad idea].<br><br>They're full of [sentence]s, some of which are not even true, many of which contain words like '[fuck]' or '[mythos|God]'.<br><br>--[icicle]",
    "[aisha|One] of us is vibrating<br><br><br><small>[Cow Of Doom]</small>",
    "We are raised to honor all the wrong explorers and discoverers - thieves planting flags, murderers carrying crosses. Let us at last praise the [Underground Tokyo|colonizers of dreams]. <br><br>--[Peter S. Beagle]",
    "Well, [Our Town] is a lot like my town, only people don't propose to each other over [ice cream sodas].  They propose to each other over [failed pregnancy tests and bong hits].<br><br>--[icicle]",  
    "Avoid humour. Always.<br><br>--[ToasterLeavings]",
    "Sweetheart, put down your flamethrower. You know I always loved you.<br><br>--[Lawrence Raab]",
    "Hemingway is a square and a pomp and a drunk.<br><br>--[the gilded frame], [literature like acorns]",
    "The kiss originated when the first male reptile licked the first female reptile, implying in a [subtle], complimentary way that she was as [succulent] as the small reptile he had for dinner the night before.<br><br>--[F. Scott Fitzgerald]",
    "My right to swing my fist ends when it hits your face.<br><br>--[Thomas Jefferson]",
    "Every central government worships uniformity: uniformity relieves it from inquiring into an infinity of details, which must be attended to if rules have to be adapted to different men, instead of indiscriminately subjecting all men to the same rule.<br>--[Alexis de Tocqueville]",
    "[Biology] is practicated kemistry, and [chemistry|kemistry] i.s practicated physics, and [physics] is practicated math, and math is practicated [logic], and logic is practicated [philosophy] as well as philosopy is theoreticated logic, and logic is theoreticated [math] and math is theoreticated physics, and physics is theoreticated kemistry, and kemistry is theoreticated biology...<br><br>--[redhog]",
    "I beg to differ, on principle<br><br>--Webster Levy-Kwieczin",
    "balloon doggies: 'The master race. What humans will evolve into. [in a word: fragile|In a word]: [fragile].'<br><BR>--[zot-fot-piq]",
    "If pianos could polish themselves<br>they would be turned to cats;<br>In mirrors of self-esteem efface their lust<br>Licking their likeness to dust<br><br>--[Lawrence Durrell], <i>[The Avignon Quintet]</i>",
    "I forget. Can monkeys talk?",
    "reality is fatiguing<br><br>--[Lawrence Durrell], <i>[The Avignon Quintet]</i>",
    "He was a cheerful man for a neurologist<br><br>--[Lawrence Durrell], <i>[The Avignon Quintet]</i>",
    "And lo there came upon them a great [slug] and the slug looked out over all that had been created and spoke to thou saying: '[KICK ASS]' and the slug slugged on, and [be cool|all was cool]...<br><br>--[dem bones]",
    "[There is no good depression. It's not sexy. It's not fun. It's not the new rock and roll.]<br><br>--[heyoka]",
    "cool! i have a [snoopy] band-aid! [it keeps my brains in!]<br><br>--[ideath], [cheddarbox]",
    "Reminds me of the [epic] movie 'The [Bridge] on the River [Katmai]', it is hard to make a bridge when all the [engineers] are prisoners.<br><br>--Bill Jackson",
    "No [Viet Cong] ever called me [nigger].<br><br>--[Muhammad Ali], on why he would not go to [Vietnam]",
    "[Love] wakes men, once a [lifetime] each;<br>They lift their heavy [eyelid|lids], and look;<br>And, lo, what [textbook|one sweet page] can teach,<br>They read with [joy], then shut the [book].<br>And some give thanks, and some [blaspheme],<br>And most [forget]; but either way,<br>That and the child's unheeded [dream]<br>Is all the [light] of all their day.<br><br>--[Uncle Gabby], <i>[Tony Millionaire's The Adventures of Sock Monkey|The Adventures of Tony Millionaire's Sock Monkey]</i>",
    "[The book of love] is long and boring. No one can lift the damn thing.<br><br>-- [The Magnetic Fields|Stephen Merritt]",
    "There is no such thing as a 'self-made' man. [interpersonality in Tamil Nadu|We are made up of thousands of others]. <br>Everyone who has ever done a kind deed for us, or spoken one word of [encouragement] to us, has entered into <br>the make-up of our character and of our thoughts.<br><br>--[George Matthew Adams]",
    "<i>Men never start from humble beginnings,</i> I thought. <i>They seem to come out of the womb seeking a woman's approval.</i><br><br>--[Templeton], [04/03/00: tether me to the real]",
    "Have some [tact] for breakfast!  It's helpful in avoiding the [eat crow|crow] you've got coming for dinner.<br><br>--[dem bones]",
    "You can get more with a kind word and a gun than you can with a kind word alone.<br><br>--[Al Capone]",
    "If you're going to put your time into this, do [something worth doing].<br><br>- [ideath] -",
    "As an adolescent I aspired to lasting [fame], I craved factual certainty, and I thirsted for [a meaningful vision of human life] -- so I became a [scientist]. This is like becoming an archbishop so you can meet girls.<br><br>--[Matt Cartmill]",
    "I know not with what [weapons] [World War III] will be fought, but [World War IV] will be fought with [sticks and stones].<br><br>--[Albert Einstein]",
    "Flow with whatever is happening and [let your mind be free].<br>Stay centered by accepting whatever you are doing. This is the ultimate.<br><br>--[Chuang Tzu]",
    "It's the Tarantino script of confessions - [chinoodle] in [Chatterbox] in response to [everyone]'s [Genital Home Wart Removal] node <br><br>",
    "[Theatre] is [Life]. [Cinema] is [Art]. [TV] is [Furniture].",
    "I am not the first to point out that [capitalism], having defeated [communism], now seems about to do the same to [democracy]. The [market] is doing splendidly, yet we are not.<br><br>--[Ian Frazier]",
    "Eat your pets",
    "I don't crack the door too far for anyone who's [pushing too hard on me].<br><br>[Liz Phair]",
    "Just remember, [math without numbers] scares people, and [people without numbers] scares math.<br><br>--[ameoba], [Amy's drug addled rantings: 11-10-97]",
    "This is my '[depressed stance]'. When you're [depressed], it makes a lot of difference how you stand. The [worst] thing you can do is straighten up and hold your head high because then you'll start to [feel better]. If you're going to get any [joy] out of being depressed, you've got to stand like this.<br><br>--[Charlie Brown]",
    "No matter how [cynical] I get, I can't keep up.<br><br>--[Lily Tomlin]",
    "The [computer] can't tell you the [emotional] story. It can give you the exact [mathematical design], but what's missing is the [eyebrows].<br><br>--[Frank Zappa]",
    "Hoping to goodness is not theologically sound.<br><br>--[Charles Schulz], [Peanuts]",
    "The majority of the [stupid] is invincible and [guaranteed for all time]. The terror of their [tyranny], however, is alleviated by their lack of [consistency].<br><br>--[Albert Einstein]",
    "The [wide world] is all about you; you can [fence] yourselves in, but you cannot for ever fence it out.<br><br>--[Gildor], [The Fellowship Of The Ring], by [J.R.R. Tolkien]",
    "So much to do, so much to do...Maybe later I'll go [kick God's ass]...  Oh, wait. [I forgot]. <b>I CAN'T.</b><br><br>--[Satan]",
    "He who makes a [beast] of himself gets rid of the [pain] of being a [man].<br><br>--[Hunter S. Thompson]",
    "[Survivor2: Journal of the Bones (Endgame)|They say she done them, all of them, in.  <br>They say she done it with an axe.]",
    "As far as I'm concerned, being any [gender] is a [drag].<br><br>[Patti Smith]",
    "A title like [recreational surgery] is false advertising!  I was expecting something far more depraved!<br><br>--[Uberfetus], in the [chatterbox]",
    "Those with the greatest [faith] have the greatest [crises].<br><br>Zed Saeed (a guy [ideath] met on the train, going into New York)",
    "..did you know that [friends come in boxes]..<br><br>--[Gary Numan]",
    "We try hard to make it work the way it does in movies.<br><br>--The [Gnutella] Support Team",
    "Regret for the things we did can be tempered by time; it is [regret] for the things we did not do that is inconsolable.<br><br>--[Sydney J. Harris]",
    "There are very few things I take seriously in life, and my [sense of humor] is one of them.<br><br>--[CaptainSpam]",
    "When you have [eliminate]d [everything] that is [impossible], what remains, however [improbable], is the [truth].<br><br>--[Sherlock Holmes|S. Holmes]",
    "Highest are those who are born wise. Next are those who become wise by learning. After them come those who have to work hard in order to acquire learning. Finally, to the lowest class of the common people belong those who work hard without ever managing to learn.<br><br>--[Confucius]",
    "The oldest and strongest emotion of mankind is [fear] and the oldest and strongest kind of fear is [fear of the unknown].<br><br>--[H. P. Lovecraft]",
    "I have been fortunate to be born with a [restless and efficient brain], with a capacity of [clear thought] and an ability to put that thought into words ... I am the lucky beneficiary of a lucky break in the [genetic sweepstakes].<br><br>--[Isaac Asimov]",
    "It was funny how people were people everywhere you went, even if the people concerned weren't the people the people who made up the phrase <i>people are people everywhere</i> had traditionally thought of as people.<br><br>--[Terry Pratchett], <i>[The Fifth Elephant]</i>",
    "Sometimes you just need the clear [epiphany] that an [ass kicking] provides.<br><br>--[Nathan Regener]",
    "You Live and Learn or you don't Live long.<br><br>[Lazarus Long]",
    "[King Kong died for your sins]<br><br>[Principia Discordia]",
    "This book is a [mirror]. When a [monkey] looks in, no apostle looks out.<br><br>Lichtenberg, [Principia Discordia]",
    "[Surrealism] aims at the total transformation of the mind and all that resembles it.<br><br>Breton",
    "[Bullshit] makes the flowers grow, and that is [beautiful].<br><br>[Principia Discordia]",
    "The preferred method of entering a building is to use a tank [main gun round], direct fire [artillery round], or [TOW], [Dragon], or [Hellfire missile] to clear the first room.<br><br>--THE [RANGER HANDBOOK], [U.S. Army], 1992",
    "If you want to get into a [fight], there is only one good choice of targets. [Pacifist]s. They don't fight back.<br><br>--[Buster Crash], The [Flametrick Subs]",
    "There are no differences but differences of [degree]<br>between different [degrees of difference]<br>and no [difference].<br><br>--[William James], under [nitrous oxide], 1882",
    "Nobody steps on a church in my town.<br><br>--[Ghostbusters]",
    "[Things fall apart... it's scientific.]<br><br>--[Talking Heads|David Byrne]",
    "I don't want to run a company, I'm not good at managing people. You have a problem with the guy in the next cubicle? I don't care. Shoot him or something.<br><br>[Marc Andreessen], May 1997",
    "You know how you feel right now is how [wimps|pussies] feel all the time.<br><br>--[dem bones], after a serious bout of [dune running]",
    "Some see it as a glass [pessimist|half empty], some see it as a glass [optimist|half full]. <br>I prefer to see it as a glass that's twice as big as it needs to be.<br><br>--[George Carlin]",
    "Whoever is fundamentally a [teacher] takes things -- including himself  -- seriously only as they affect his [student]s.<br><br>--[Friedrich Nietzsche], <i>[Beyond Good and Evil]</i>",
    "[Life] is a series of [small awakening]s.<br><br>[Electric Mollusk], <i>[Someone please kill me]</i>",
    "I don't know the meaning of the word [surrender]!<br>I mean, I know it, I'm not dumb... just not in this [context].<br><br>--[The Tick]",
    "[Withdrawal] in [disgust] is not the same as [apathy].<br><br>--[Richard Linklater]",
    "To eat were best done at [home].<br><br>--[Macbeth|Lady Macbeth]",
    "[Tragedy] is if I cut my finger; [comedy] is if you walk into an open sewer and die.<br><br>--[Mel Brooks]",
    "[Work] is [Worship].",
    "[Memory] is like a train; you can see it getting [smaller] as it pulls away...<br><br>--[Tom Waits]",
    "[N-Wing] hasn't tasted [urine] yet.<br><br>--[N-Wing] in Chatterbox",
    "[Obscenity] is whatever gives a [moralist] an [erection].",
    "Amicus Plato amicus Aristoteles magis amica veritas <i>Plato is my friend, Aristotle is my friend, but my best friend is truth</i>. --Sir Isaac Newton",
    "<i>Knifegirl nods gravely</i><br><br>--[Knifegirl] (obviously) as [zot-fot-piq] went on and on in the [Chatterbox]",
    "The [law], in its equality, forbids the [eat the rich|rich] as well as the [kill the poor|poor] to [sleep] under bridges, to [beg] in the streets, and to [steal] bread.<br><br>--[Anatole France]",
    "To man the [World] is [twofold], in accordance with his [twofold attitude].--Martin Buber, [I & Thou]", 
    "Life is a gift of [nature], but beautiful living is the gift of [wisdom].<br><br>--[Greek] [adage]",
    "[Friendship] is one [soul] in two bodies.<br><br>--[Aristotle]",
    "I thought of how odd it is for billions of people to be [alive], yet not one of them is really quite sure what makes people people. The only activities I could think of that have no other animal equivalent were [smoking], [body-building], and [writing]. That's not much, considering how [special] we seem to think we are. <br><br>--[Douglas Coupland], [Life After God]",
    "Time ticks by; we grow older. Before we know it, too much time has passed and we've missed the chance to have had other people [hurt] us. To a younger me this sounded like [luck]; to an older me this sounds like a [quiet] [tragedy]. <br><br>--[Douglas Coupland], [Life After God]",
    "Approach [life] and [cooking] with reckless abandon. <br><br>--the Dalai Lama",
    "Take into account that great [love] and great [achievements] involve great [risk]. <br><br>--The [Dalai Lama]",
    "I shall come to you [in the night] and we shall see who is stronger--a [little girl] who won't eat her dinner or a [great big man] with [cocaine] in his veins.<br><br>--[Sigmund Freud] (in a letter to his fiancee)",
    "Have you any idea what the numbers for the [Theory of Everything] look like?<br><br>--[God] to [Jim Morrison], [Doc Holliday], et al, in the book [Jim Morrison's Adventures in the Afterlife].",
    "Groups and individuals contain [microfascisms] just waiting to [crystallize].<br><br>--[Deleuze & Guattari]",
    "The basic difference between [classical music] and [jazz] is that in the former the music is always greater than its performance--whereas the way jazz is [performed] is always more important than what is being played.<br><br>--[Andre Previn]",
    "God created the [integer|Integers]; all the rest is the work of [Man].<br><br>--[L. Kronecker]",
    "We have a saying around here [senator]: Don't [piss] down my back and tell me it's [raining].<br><br>--Fletcher, [The Outlaw Josey Wales]",
    "Sometimes people say, 'She's no great [talent]<br>I could [write] like she does'.<br> They are right. <br>They could; but I do.<br><br>--[Elizabeth Wurtzel]",
    "You were [born]. And so you're [free]. So [Happy Birthday].<br><br>--[Laurie Anderson]",
    "Either get busy [living] or get busy [dying].<br><br>[The Shawshank Redemption]",
    "I cannot and will not cut my [conscience] to fit this year's [fashion|fashions].<br><br>--[Lillian Hellman], [HUAC], 1954",
    "Why should I drink [Tequila] in Mexico, when I can get such good [kerosene] in the U.S.? <br><br>--[John Barrymore]",
    "[Undead] are my specialty, really.<br><br>--[thefez]",
    "That's all it is: [information]. Even a dream or simulated experience is simultaneous [reality] and [fantasy]. Any way you look at it, all the information a person acquires in a lifetime is just [a drop in the bucket].<br><br>--Batou, [Ghost in the Shell]",
    "Like flies to wanton boys, are we to the [gods]. They kill us for their [sport].<br><br>--[Gloucester], [King Lear]",
    "Those who will not reason, are [bigots], those who cannot, are [fools], and those who dare not, are [slaves].<br><br>--[George Gordon Noel Byron]",
    "The urge to [perform] is not an indication of [talent], and don't you ever forget it.<br><br>--[Garrison Keillor]",
    "There is hopeful [symbolism] in the fact that flags do not wave in a vacuum.<br><br>--[Arthur C. Clarke]",
    "[Nature] has given [women] so much power that the [law] has wisely given them very little<br><br>[Samuel Johnson]",
    "I think [polygamy] is absolutely [splendid].<br><br>--[Adam West]",
    "To live is to war with trolls in [heart] and [soul]. To write is to sit in judgement on oneself.<br><br>[Henrik Ibsen]",
    "By the time you swear that you are his,<br>shivering and sighing, <br>and he promises his [passion] is,<br>[infinite], undying,<br>Lady, make a note of this:<br>one of you is [lying].<br><br>--[Dorothy Parker]",
    "A [computer] lets you make more mistakes faster than any invention in human history--with the possible exceptions of [handguns] and [tequila].<br><br>--[Mitch Ratliffe], [Technology Review]",
    "We [praise] the man who is [angry] on the right grounds, against the right persons, in the right manner, at the right moment, and for the right length of time.<br><br>--[Aristotle], [Nicomachean Ethics], IV",
    "Every man with a belly full of the [classics] is an enemy of the human race.<br><br>--[Henry Miller]",
    "In my work<br>I will take the blame for what is [wrong]<br>For that which is clearly mine.<br>But what is [right] I can not comprehend.<br><br>--[James Hubbell]",
    "I prefer the [wicked] rather than the [foolish]. The wicked sometimes rest.<br><br>--[Alexandre Dumas]",
    "There's a [truism] that the road to [Hell] is often paved with good intentions. The corollary is that [evil] is best known not by its motives but by its <i>methods</i>.<br><br>--[Eric S. Raymond]",
    "Now, now my good man, this is no time for making [enemies]. <br><br>--[Voltaire], on his deathbed, in response to a priest asking that he renounce [Satan]",
    "I'm a member of an [monkey|ape-like] race at the [end|asshole-end] of the twentieth century...<br><br>--[James], [Low]",
    "Shut your [Multifarious postings of Deborah909|multifarious] ass up, [dem bones|bones].<br><br>--[knifegirl], [Chatterbox]",
    "[Abandon all hope ye who enter here]",
    "God made [night] but man made [darkness].<br><br>--[Spike Milligan]",
    "If I die in [war] you remember me. If I live in [peace] you don't.<br><br>--[Spike Milligan]",
    "The trouble with us in [America] isn't that [the poetry of life] has turned to prose, but that it has turned to [advertising] copy.<br><br>-- [Louis Kronenberger], [1954]",
    "It is harder to fight against [pleasure] than against [anger].<br><br>-- [Aristotle]",
    "A [critic] is a bundle of biases held loosely together by [a sense of taste].<br><br>--[Whitney Balliett]",
    "I'm out of your [back door] and into another<br>Your [boyfriend] doesn't know about me and your [mother]<br><br>--[The Beastie Boys], [3-Minute Rule]",
    "We'll cut the [thick] and break the [thin]...<br><br>--[Peter Murphy], [Cuts You Up]",
    "I live with [desertion]...and eight million people.<br><br>--[The Cure], [Other Voices]",
    "A [prayer] can't travel so far these days...<br><br>--[David Bowie], [A Small Plot Of Land]",
    "Give me back the [Berlin wall]<br>Give me [Joseph Stalin|Stalin] and [St. Paul]<br>Give me [Christ]<br>Or give me [Hiroshima]...<br><br>--[Leonard Cohen], [The Future]",
    "[Who By Fire?]<br><br>--[Leonard Cohen]",
    "[the alphabet is a playground (overview)|The alphabet is a playground]",
    "Breathe in...then squeeze the trigger on the [exhale].<br><br>--[TheFez]",
    "I'm allergic to [power]...<br><br>--[Nate]",
    "[Liberty] without [socialism] is [privilege] and [injustice]; [socialism] without [liberty] is [slavery] and [brutality].<br><br>--[Mikhail Bakunin]",
    "If [God] really existed, it would be necessary to [abolish] him.<br><br>--[Mikhail Bakunin]",
    "[Skepticism] is the agent of [truth].<br><br>--[Joseph Conrad]",
    "What is a [rebel]?  A [man] who says [no].<br><br>--[Albert Camus]",
    "If a man really wants to make a [million dollars], the best way would be to start his own [religion].<br><br>--[L. Ron Hubbard]",
    "If [God] does not [exist], [everything] is permitted.<br><br>--[Fyodor Dostoyevsky]",
    "The [distinction] between [past], [present], and [future] is only a stubbornly persistent [illusion].<br><br>--[Albert Einstein]",
    "If the [law] is of such a [nature] that it requires you to be an agent of [injustice] to another, then I say, [breaking the law|break the law].<br><br>--[Henry David Thoreau]",
    "You must realize that the [computer] has it in for you. The irrefutable [proof] of this is that the [computer] always does what you tell it to do.",
    "Political [language]...is designed to make [lies] sound truthful and [murder] respectable, and to give an appearance of [solidity] to pure wind.<br><br>--[George Orwell]",
    "The entire sum of [existence] is the [magic] of being needed by just one person.<br><br>--[Vii Putnam]",
    "A ship in harbor is [safe], but that's not what ships are built for.<br><br>--[John Shedd]",
    "An [Error] does not become [Truth] by reason of multiplied propagation, nor does Truth become Error just because nobody sees it.<br><br>--[Mohandas Gandhi]",
    "When people are [free] to do as they please, they usually [imitate] each other.<br><br>--[Eric Hoffer]",
    "Give a man a [fire] and he's [warm] for a day, but set fire to him and he's warm for the rest of his [life].<br><br>--[Terry Pratchett]",
    "Just because it's [not nice] doesn't mean it's not [miraculous].<br><br>--[Terry Pratchett]",
    "He was said to have the [body] of a twenty-five year old, although no one knew where he kept it...<br><br>--[Terry Pratchett]",
    "You can take a [horticulture] but you can't make her think<br><br>--[Groucho Marx]",
    "I'm Great [Me]<br><br>--[Rhys Lewis], Personal Statement on a job application",
    "EDB is a dirty [slut].<br><br>--[ohe]",
    "For what shall it [profit] a man, if he shall gain the whole world, and lose his own [soul]?<br><br>--[Matthew 16:26]",
    "The [faith] that stands on [authority] is not faith.<br><br>--[Ralph Waldo Emerson]",
    "So far as I can remember, there is not one word in [the Gospels] in praise of [intelligence].<br><br>--[Bertrand Russell]",
    "We should take care not to make the [intellect] our god; it has, of course, powerful muscles, but no [personality].<br><br>--[Albert Einstein]",
    "Only two things are [infinite], the [Universe] and human stupidity, and I'm not sure about the former.<br><br>--[Albert Einstein]",
    "In the beginning, there was [nothing]. Then [god] said <i>Let there be light</i>, and there was still [nothing], but you could see it.<br><br>--[Dave Thomas]",
    "It is dangerous to be [right] when the [government] is [wrong].<br><br>--[Voltaire]",
    "[What luck for rulers that men do not think.]<br><br>--[Adolf Hitler]",
    "The aim of [education] should be to teach us rather [how] to [think], than [what] to think - rather to [improve] our minds, so as to enable us to think for ourselves, than to load the memory with the thoughts of other men.<br><br>--[James Beattle]",
    "[Science] is built up with [facts], as a [house] is with stones. But a collection of facts is not more a science than a heap of stones is a home.<br><br>--[Henri Poincaré]",
    "[Television] made me what I am.<br><br>--[David Byrne]",
    "[Ideas] lie everywhere, like apples fallen and melting in the [grass] for lack of wayfaring strangers with an [eye] and a [tongue] for [beauty].<br><br>--[Ray Bradbury]",
    "[Fascism] is [fascism]. I don't care if the trains run on time. <br><br>--[Douglas McFarland]",
    "I'd rather be [brilliant] than on time.<br><br>--[edebroux]",
    "When [I] look [up], I miss all the [big stuff].  When I look [down], I [trip] over [things].<br><br>--[Ani Difranco]",
    "What makes the universe so hard to [comprehend] is that there is nothing to [compare] it with.",
    "I have nothing to declare but my [genius].<br><br>--[Oscar Wilde]",
    "Server Error (Error Id 5066529)! <br><br>An [error] has occured. Please contact the site [Nathan, this is unacceptable|administrator] with the Error Id. [Thank you].<br><br>--[Everything Quote Server]",
    "Human beings can always be relied upon to assert, with vigor, their God-given right to be [stupid].<br><br>--[Dean Koontz]",
    "Well, that was about as useful as [bong hits] at 7:30 in the morning...<br><br>--overheard by [Ailie] after her [inverse theory] class",
    "The only man who makes no [mistakes] is the man who never does anything. Do not be [afraid] of mistakes providing you do not make the same one [twice].<br><br>--[Theodore Roosevelt]",
    "I am not interested in the [past]. I am interested in the [future] for that is where I intend to spend the rest of my [life].<br><br>--[Charles F. Kettering]",
    "To be irritated by [criticism] is to acknowledge it is deserved.<br><br>--[Cornelius Tacitus]",
    "[Damocles] got sucker punched--<br>a [bastard sword] at Sunday brunch",
    "[Fantastic] tricks the [truth].",
    "These are the motions of a [lifetime],<br>Given to us in the spirit of [tragedy]<br>By [mad], laughing [children].",
    "You might want to [Gary|get down] for this...<br><br>--[the gilded frame]",
    "You've got an [organ] going there...no wonder the sound has so much [body]...",
    "I don't <i>do</i> [pennies].<br><br>--[The Gilded Frame]",
    "All [pleasure] is [relief].",
    "Well, [dem bones|dude], if you're not going to go to the [hospital] maybe we should smoke another bowl?<br><br>--[TheFez]",
    "That'd be the [butt], Bob<br><br>--[tregoweth], [the most interesting place you've had sex]",
    "[Art] is anything you can get away with.<br><br>--[Marshall McLuhan]",
    "Admit [Nothing]. Blame [Everyone]. Be [Bitter].<br><br>--?[Jonathan Carroll]?",
    "For as a man thinketh in his [heart], so is he.<br><br>--[Proverbs] 23:7",
    "The mind is the [man], and knowledge [mind]; a man is but what he knoweth.<br><br>--[Francis Bacon]",
    "Repetition is the [death] of the soul.",
    "Eat the [rich].",
    "E2: The Return. <i>This time it's personal</i>.<br><br>--[CaptainSpam], [E2]",
    "Give in to [love], or give in to [fear].",
    "The only thing to [fear] is [fearlessness].<br><br>--[R.E.M.]",
    "[History] is made to seem [unfair].<br><br>--[R.E.M.]",
    "[Grace Beats Karma]",
    "[Simplicity] of character is the natural result of [Deep Thoughts|profound thought].",
    "<i>[I've]got[a]match[your]embrace[and]my[collapse]...</i><br><br>--[They Might Be Giants], [I've Got A Match]",
    "Where your eyes don't go a filthy [scarecrow] waves his broomstick arms and does a [parody] of each [unconscious] thing you do...<br><br>--[They Might Be Giants], [Where Your Eyes Don't Go]",
    "[Subvert] the dominant paradigm.",
    "Avoid the [cliche] of your time.",
    "[Everything Drugs|Participate in your own manipulation.]",
    "Drink [cold], <br>piss [warm]<br> and fuck the [Hitler|Huns].<br><br>--[Henry Miller]",
    "Then [Goldilocks] said, 'These hands have too much [semen] on them. And these hands don't have enough [semen] on them. But these hands - these [semen]-covered hands are just right.'<br><br>--[jessicapierce], [What to do if you've got too much semen on your hands]",
    "I do not resemble a [warrior] so much as a [short bus|special student] out on a [shore leave|day pass]. So be it.<br><br>--[hoopy_frood], [The Squirrel Diaries]",
    "In the [Fall] of 1999, I figured out that I'm just not as [smart] as I like to think I am.<br><br>--[pife], [I Wish I Had Thought Of Everything]",
    "<i>Let's get those [missiles] ready to destroy the [universe]!</i><br><br>--[They Might Be Giants], [For Science] ",
    "No one in the world ever gets what they [want] and that is [beautiful]<br><br>--[They Might Be Giants], [Don't Let's Start]",
    "[Nathan, This Is Unacceptable]",
    "It is not your [duty] to finish the [work], but you are not at liberty to [neglect] it.<br> ([Avot]. 1:10)",
    "I represent<br><b>[GOD]</b><br>you fuck<br><br>--[Unamerican Activities|!!!srini x]",
    "I never did [a day's work] in my life; [it was all fun].<br><br>--[Thomas Edison]",
    "A society is a [healthy society] only to the degree that it exhibits [anarchistic] traits.<br><br>--Jens Bjørneboe",
    "The [weed] of crime bears [bitter fruit]. But it makes a pretty good [milkshake].<br><br>--<i>[Sam & Max]</i>",
    "[Truth] suffers from too much [analysis].<br><br>--ancient [Fremen] saying,<br><i>[Dune Messiah]</i> by [Frank Herbert]",
    "My head is a [strange] place.<br><br>--[pukesick]",
    "Live your [life], do your [work], then [take your hat].<br><br>--[Henry David Thoreau]",
    "I am trying to wrap my [brain] around your weirdness; it's not working.<br><br>--[Dylan Hillerman: Freelance Illustrator|Dylan Hillerman]",
    "I'm not [nodes about Everything addiction|addicted]. I can stop any time my computer crashes.<br><br>--[The Grey Defender]",
    "When I hear the word [culture] I [that's when i reach for my revolver|reach for my revolver].<br><br>attributed to [Hermann Göring]",
    "I got no time for the jibba-jabba!<br><br>--[Mr. T]",
    "Dude. If you had a [Sharpie], you could perform surgery!<br><br>--[RevPhil]",
    "Never eat at a place called [Mom]'s. Never play [cards] with a man named Doc. And never [lie down] with a woman who's got more [troubles] than you.<br><br>--[Nelson Algren]",
    "A boy <i>likes</i> being a member of the [bourgeoisie]. Being a member of the bourgeoisie is <i>good</i> for a boy.<br>It makes him feel <i>warm</i> and <i>happy</i>.<br><br>--[Donald Barthelme], <i>[Our Work And Why We Do It]</i>",
    "I have the [hammer], I will [smash] anybody who threatens, however remotely, the [company] way of life. We know what we're doing. The [vodka] ration is generous. Our reputation for excellence is unexcelled, in every part of the world. And will be maintained until the destruction of our [art] by some other art which is just as good but which, I am happy to say, has not yet been invented.<br><br>--[Donald Barthelme], <i>[Our Work And Why We Do It]</i>",
    "With communication, comes [understanding] and [clarity];<br>With understanding, [fear] diminishes;<br>In the absence of fear, [hope] emerges;<br>And in the presence of hope, [anything is possible].<br><br>--[Ellen Stovall]",
    "One [artist] I read about recently dismembered baby dolls, sprayed them with paints and hung them up on the wall in disfigured poses.<br>You know, that would convey a message to someone of a [pessimistic], angst-ridden mindset.<br><br>--<em>[Thomas Kinkade], [Painter of Light]®</em>",
    "Why do people keep insisting that I join the [21st Century]? <br>I *<strong>live</strong>* in the 21st Century! I just don't want to be bothered by the [shitheads] on the Internet!<br><br>--<em>[Harlan Ellison]<em>",
    "What's all this business about being a [writer]?, It's just putting one word after another.<br><br>--<em>[Irving Thalberg]</em>",
    "I know you believe you understand what you think I said, but I am not sure you realise that what you heard is not what I meant.<br>--<em>[Alan Greenspan]</em>",
    "Airing one's [dirty linen] never makes for a masterpiece.<br><br>--<em>[François Truffaut]</em>",
    "I hate [Submissions for the Everything Quote Server | quotations]. Tell me what you know.<br><br>-- <em>[Ralph Waldo Emerson], May 1849</em>",
    "I had the song '[Fish Heads]' stuck in my head in 1985. [All] of 1985.<br><br>--<em>[jwz]</em>",
    "[Passers-by were amazed by the unusually large amounts of blood].",
    "[Don't node nude!]",
    "The most [merciful] thing in the world, I think, is the inability of the human mind to correlate all its contents.<br><br>--<em>[H.P. Lovecraft]</em>",
    "Famous remarks are very [seldom] quoted correctly. <br><br>--<em>[Simeon Strunsky]</em>",
    "I love deadlines. I love the [whooshing] sound they make as they fly by. <br><br>-- <em>[Douglas Adams]</em>",
    "You don't pray in my school and I won't think in your church. <br><br>-- <em>A bumper sticker seen on the back of a [Toyota]</em>",
    "Of the four wars in my lifetime, none came about because the U.S. was too strong.<br><br>-- <em>[Ronald Reagan]</em>",
    "Find your own [trajectory] and stick to it. Find kindred spirits. Follow your bliss.<br><br>-- <em>[Joseph Campbell]</em>",
    "Truth is strong because it is true...Truth is justice because it is true...<br>Don't you think it is very persuasive?<br><br>--<em>[Taro], [Serial Experiments Lain], Layer 09:Protocol</em>",
    "Why does man [kill]? Man kills for food. But not only for food - frequently a beverage is also required.<br><br>-- <em>[Woody Allen]</em>",
    "Despite my [ghoulish] reputation, I really have the heart of a small boy. I keep it in a [jar] on my desk.<br><br>-- <em>[Robert Bloch]</em>",
    "Of course you're mad. If you weren't mad, you wouldn't be here.<br><br>-- <em>the [Mad Hatter] to Alice (from [Lewis Carroll | Lewis Carroll's] [Alice in Wonderland])</em>",
    "No, we won't think noble because we're not noble. We won't live in [beautiful harmony] because there's no such thing in this world, nor should there be. We promise only to do our best and live out our lives. <br><br>Dear [God] that's all we can promise in [truth].  <br><br>-- <em>[Lillian Hellman]</em>",
    "[Sarcastic]? You mean [malicious]. Yes, I am a little malicious. I only fear that my malice is to be wasted on such miserable objects.<br><br>-- <em>Thomas Mann</em>",
    "Always read stuff that will make you look good if you die in the middle of it.<br><br>-- <em>P. J. O'Rourke</em>",
    "as yes is to if, [love] is to yes<br><br>-- <em>spud\@nothingness.net</em>",
    "[Madness] is something rare in individuals - but in groups, parties, peoples, ages it is the rule.<br><br>-- <em>[Friedrich Nietzsche], [Beyond Good and Evil]</em>", 
    "I don't remember what the point was, but actually {[Bill Gates]} conceded that I was right and then just moved on, which I found extremely scary that he would consider something, consider his own position, consider this alternative view, weigh the merits of each argument, and then adopt the best view. And it was irrelevant whether the best view was his or someone else's.<br><br>-- <em>[Larry Ellison] </em>",
    "A [diplomat] is a man who says you have an open mind, instead of telling you that you have a hole in the head.<br><br>-- <em>Unknown</em>",
    "I once knew a rotund lesbian [Luxembourg | Luxembourger] who enjoyed making laborious dot-matrix style pictures of [Seven of Nine] with a felt tip pen.<br><br>--<em>[The Alchemist]</em>",
    "I just wrote a [node] with links in it. [hard link | Those brackets are great]. Really easy to do stuff.<br><br>-- <em>ThePress</em>",
    "For some reason, I felt I was hard pressed to find much that was Mexican in [Mexico].<br><br>--<em>[Valhalla]</em>",
    "We can't afford to be [innocent].<br><br>--<em>[Girlface]</em>",
    "[Globalisation] is an American ideology. It stands for expansion on our terms, and for free trade [as long as it serves us].<br><br>-- <em>[Chalmers Johnson], Manager of the [Japan Policy Reseach Institute].</em>",
    "[Oh my God]! Space aliens! Don't eat me, I have a wife and kids! Eat them. <br><br>-- <em>[Homer Simpson] - [The Treehouse of Horror]</em>",
    "To model our political system upon speculations of lasting [tranquillity], is to calculate on the weaker springs of the human character.<br><br>-- <em>[Alexander Hamilton]</em>",
    "Restriction of free thought and [free speech] is the most dangerous of all subversions. It is the one un-American act that could most easily defeat us.<br><br>-- <em>[William O. Douglas]</em>",
    "Nothing is illegal if one hundred businessmen decide to do it.<br><br>-- <em>[Andrew Young]</em>",
    "Get crazy with the [Cheez Whiz],<br><br>-- <em>[Beck] - '[Where It's At]'</em>",
    "Question with [boldness] even the existence of a God; because, if there be one, he must more approve of the homage of reason, than that of blind-folded fear.<br><br>-- <em>[Thomas Jefferson]</em>",
    "Every word is like an unnecessary stain on [silence] and [nothingness].<br><br>-- <em>[Samuel Beckett]</em>",
    "Happiness isn't something you experience; it's something you remember.<br><br>-- <em>[Oscar Levant]</em>",
    "A man can make up for his intelligence with his effort, but a man cannot make up for his effort with his intelligence. <br><br>-- <em>[Joseph Garvin]</em>",
    "He hoped and prayed that there wasn't an [afterlife]. Then he realised there was a contradiction involved here and merely hoped that there wasn't an afterlife.<br><br>-- <em>[Douglas Adams]</em>",
    "Take me [drunk], I'm home again!",
    "Every time you manage to close the door on [Reality], it comes in through the window. <br><br>-- <em>[Unknown]</em>",
    "Care about other people. Not what they think.", 
    "Those who say it cannot be done... are often passed by those doing it.-- <em>[Unknown]</em>",
    "One treats others with [courtesy] not because they are gentlemen or gentlewomen, but because you are.-- <em>G. Henrichs</em>",
    "Faith is Belief without evidence in what is told by one who speaks without [knowledge], of things without [parallel].-- <em>[Ambrose Bierce]</em>",
    "A sharp [axe] is easier to wield than a sharp [wit].",
    "[Fuck the system]? Nah, you might catch something.",
    "Shell to [DOS]... Come in DOS, do you copy? Shell to DOS...",
    "Man who go to bed with itchy butt, wake with smelly finger",
    "From every tree in the garden did he grant them to eat, save but one. And that tree, in the centre of the garden, was called the tree of life. And the [Satan | Snake] said to Eve, 'Eat of this fruit and you will become as God.'<br><br>-- <em>[Genesis 3 | Book of Genesis, Chapter 3, Verse 4]</em>",
    "As memory may be a [paradise] from which we cannot be driven, it may also be a hell from which we cannot escape.<br><br>-- <em>[John Lancaster Spalding]</em>",
    "Stupidity is present among the most [intelligent] of man.",
    "A list is only as strong as its [You are the Weakest Link, Goodbye | are the weakest link].<br><br>-- <em>Don Knuth</em>",
    "I cannot believe that [God] plays dice with the [cosmos].<br><br>-- <em>Albert Einstein, on the randomness of [quantum mechanics]</em>",
    "Christmas is a time when kids tell Santa what they want and adults pay for it. Deficits are when adults tell the government what they want-and their kids pay for it.<br><br>-- <em>[Richard Lamm]</em>",
    "There is an exception to every rule, except the rule of exceptions.",
    "The surest way to corrupt a youth is to instruct him to hold in higher esteem those who think alike than those who think differently.<br><br>-- [Fredrich Nietzsche]",
    "What the hell, It's only [XP | Karma].",
    "+fhjmnoptxB", 
    "I saw him earlier - he was in the [bathroom] getting a drink of water - and the seat fell and hit him on the head.",
    "[EDB | Death] rides a swift horse.",
    "Why am I better than you, you ask? If you need to think about that, there you are.",
    "heh if the fbi ever rings me im going to keep them talking for as long as possible, i have to get someone back for the cost of all these parking tickets.<br><br>-- <em>'trapper', [#cyberarmy] [DALNet]</em>",
    "any hot ladies want to chat with an ultimate [pokemon] trainer?",
    "[History Repeating | History will always be repeated] because there are only a [finite] number of possible actions.<br><br>-- <em>[Nanosecond]</em>",
    "Eternal vigilance is the price of liberty.<br><br>-- <em>[Thomas Jefferson]</em>",
    "Let us make sure of the facts before being concerned with the cause.<br><br>-- <em>Fontenelle</em>",
    "You can tell a lot about a fellow's character by his way of eating [jelly beans].<br><br>-- <em>[Ronald Reagan]</em>",
    "I want to know God's thoughts....the rest, are details.<br><br>-- <em>[Albert Einstein]</em>",
    "Don't run from [sniper | snipers], you'll just die tired.",
    "Whoever decided to call it necking was a poor judge of [anatomy].<br><br> -- <em>Groucho Marx</em>",
    "We are born naked, wet, and hungry. Then things get worse.",
    "There is nothing more uncommon than [common sense].<br><br>-- <em>[Frank Lloyd Wright]</em>",
    "A great many people will think they're thinking when they are merely rearranging their prejudices.<br><br>-- <em>[William James]</em>",
    "Common sense is the collection of prejudices acquired by age eighteen.<br><br>-- <em>[Albert Einstein]</em>",
    "I am free of all prejudices. I hate everyone equally. <br><br>-- <em>[W.C. Fields]</em>", 
    "[Fashion] is a form of ugliness so intolerable that we have to alter it every six months.<br><br>-- <em>[Oscar Wilde]</em>",
    "The [optimist] sees opportunity in every danger; the [pessimist] sees danger in every opportunity.<br><br>-- <em>[Winston Churchill]</em>",
    "Why do grandparents and grandchildren get along so well? They have the same enemy-- the [mother].<br><br>-- <em>[Claudette Colbert]</em>",
    "Whenever you have an efficient government you have a [dictatorship].<br><br>-- <em>[Harry S. Truman]</em>",
    "There's no fool like an old fool -- you can't beat [XP | experience].<br><br>-- <em>[Jacob Braude]</em>",
    "There is nothing so annoying as to have two people talking when you're busy interrupting.<br><br>-- <em>[Mark Twain]</em>",
    "[Editor | Power] corrupts. [Gods | Absolute power] corrupts absolutely.<br><br>-- <em>[Rosabeth Moss Kantor]</em>",
    "[Imagination] is more important than knowledge.<br><br>-- <em>[Albert Einstein]</em>", 
    "[Imagination] rules the world.<br><br> -- <em>[Napoleon]</em>",
    "There's a [sucker] born every minute.<br><br> -- <em>[PT Barnum]</em>",
    "The whole is equal to the sum of its parts.<br><br>-- <em>[Euclid]</em>",
    "[Consistency] only comes in death.",
    "They that can give up essential [liberty] to obtain a little temporary [safety] deserve neither liberty nor safety.<br><br>-- <em>[Benjamin Franklin]</em>",
    "grrrrr....<br><br>-- <em>[EDB]</em>",
    "You know, the condom is the [Cinderella | glass slipper] of our generation. You slip it on when you meet a stranger. You dance all night, then you throw it away. The [condom], I mean. Not the stranger.<br><br>-- <em>[Marla Singer] - [Fight Club]</em>",
    "Our generation has had no [Great Depression], no [First World War | Great War]. Our war is a spiritual war. Our depression is our lives.<br><br>-- <em>[Tyler Durden] - [Fight Club]</em>",
    "You are not your [job].<br>You are not the money in your [bank account].<br>You are not the [car] you drive.<br>You are not how much money is in your [wallet].<br><br>[You are the all-singing, all-dancing crap of the world].<br><br>-- <em>[Tyler Durden] - [Fight Club]</em>",
    "Yes, there is no benefit of having [copper] at .25um, but that's not the point. The point is would you rather go to copper when you can, or when you have to?<br><br>-- <em>[chic_hearne]</em>",
    "You wanna know something funnier? [Rambus] are made up of a bunch of old [AMD] guys that left back in the mid-late 80's. Hehe ... Talk about stealth...<br><br>-- <em>[Michael Lim], alluding to Rambus's hand in the weakening of [Intel] Corp. in the year 2000</em>",
    "It was because he wanted there to be [conspirator | conspirators]. It was much better to imagine men in some smoky room somewhere, made mad and cynical by privilege and power, plotting over the [Courvoisier | brandy]. You had to cling to this sort of image, because if you didn't then you might have to face the fact that bad things happened because ordinary people, the kind who brushed the dog and told their children [bedtime stories], were capable of then going out and doing horrible things to other ordinary people. It was much easier to blame it on Them. It was bleakly depressing to think that They were Us. If it was Them, then nothing was anyone's fault. If is was Us, what did that make Me? After all, I'm one of Us. I must be. I've certainly never thought of myself as one of Them. No one ever thinks of themselves as one of Them. We're always one of Us. It's Them that do the bad things<br><br>--<em>[Terry Pratchett]</em>",
    "Sort of like the old joke about the woman who was trying to get [pregnant] after having been married for two years. She goes to the [doctor] who says 'but you're still a [virgin]' and she says 'Well, I'm married to an [Intel] salesman and he just sits on the edge of the bed and tells me how great it is going to be<br><br>-- <em>[idiot]</em>",
    "[Mustang | Mustangs] and [Thunderbirds] and [Spitfire | Spitfires] - Oh MY!<br><br>--<em>[tejek]</em>",
    "Oh that bug, that is no bug, that is a creature I mean feature, a new evolutionary [CPU] from [Intel], it creates different answers for you to rely on and those companies that survive will be stronger<br><br>-- <em>[Bill Jackson ]</em>",
    "[WTF] ... while spec is evaded as 'not important for [itanium]' ... what does [intel] think our cluster is going to do, [mp3] decoding?<br><br>--<em>[Tim Wilkens] </em>",
    "I would have loved to be a fly on the wall this morning to hear the first words out of [Jerry Sanders]' mouth when he heard of the 1.13GHz [Pentium III] recall. For that matter, I would have loved to hear the conversation when Micky D. called Barrett this morning. I would have loved to see the look on Barrett's face when his secretary said, 'Craig, Michael's on the phone and he  sounds [a little pissed].'<br><br>-- <em>[Pravin Kamdar] </em>",
    "I'll connect the dots for youcheap [MHz] + dumb public = [profit]<br><br>-- <em>[Paul DeMone]</em>",  
    "Michael Dell has built a large company...now he wants to build a small company from it<br><br> -- <em>[Bill Jackson], on [Dell]'s single sourcing and public bashing of [AMD] products</em>",
    "Our strategy is high performance at fair prices. Our competitor's is fair performance at high prices<br><br>-- <em>[Jerry Sanders]</em>", 
    "Only a fool would bet against you. After all, it's not [RAMBUS] or [Willy] it's the benchmarks....! Reminds me of [Star Trek] [OS] episode (later in a movie) about the '[Kobiashi Maru]'...the no win situation...what do you do? You change the rules! [Intel] will change the benchmarks! Bet on it...<br><br> -- <em>[Jim McMannis]</em>",
    "In the Kingdom of the [MHz], the man with one [GHz] is king.<br><br>-- <em>JC</em>",
    "There are lies, damn lies, and then what the [PR] guy says.<br><br>-- <em>[Drew Prairie]</em>",
    "Wafer [frisbee], That is a good way to lose your head.<br><br>-- <em>[Bill Jackson]</em>",
    "...a [Gateway] Select commercial came on. In the commercial they were talking about the superior [AMD Athlon] processor. Then at the end they showed the Gateway screen with the AMD logo where the [Intel] logo usually is. My wife turns to me a goes 'where was the [Intel Pentium III music | dint din ding]?'<br><br> -- <em>[Kwas]</em>",
    "It looks like they tried the 'Get 9 women, I want that baby in a month' approach-- <em>[Bill Jackson], on the [Coppermine] chipset</em>",
    "It's not just the arrival of chips which match -- or out-perform -- the [Pentium III]; and it's not just the total unavailability of Pentium III gigahertz processors, and it's not just the continuing farce of [Rambus]; what's now in question is the very basis of [Intel] technology. Because logically, what [AMD] is doing shouldn't be possible<br><br>-- <em>Kewney</em>",
    "[Intel] has done the impossible! [Dual-boot] with one [OS]!<br><br>-- <em>[Steve Harris], on the [Coppermine bug]</em>",
    "We hold these truths to be self-evident, that all men people are created equal<br><br>--  <em>[Thomas Jefferson]</em>",
    "I think I must be a [mushroom] because they keep me in the dark and feed me [bullshit].<br><br>--  <em>[Unknown]</em>",
    "Truth has many faces<br><br>--<em>[Morgaine], [The Mists if Avalon] by [Marion Zimmer Bradley]</em>",
    "Two roads diverged in a wood and I- I took the one less travelled by<br>And that has made all the difference. <br><br>-- <em>[Robert Frost], [The Road not Taken]</em>",
    "Whatever you do, you'll regret it.<br><br>-- <em>[Allan McCleod Gray]</em>",
    "I don't suffer from [insanity] I enjoy every minute of it.",
    "[Sanity] is a playground for the unimaginative.", 
    "I'm not [weird], I think in new ways",
    "It's useless for [sheep] to pass resolutions in favour of vegetarianism when [wolf | wolves] remain of a different opinion.<br><br>-- <em>[William Ralph Inge]</em>",
    "Dear [Lord], give me [chastity] and self-restraint. . . but not yet, Oh Lord, not yet!<br><br> -- <em>[Saint Augustine]</em>",
    "The [truth] is the one thing that nobody will believe.<br><br>-- <em>[George Bernard Shaw]</em>",
    "[Violence] never settles anything.<br><br>-- <em>Genghis Khan</em>",
    "The mice voted to bell the cat.<br><br> -- <em>[Aesop]</em>",
    "[Democracy] can withstand anything but democrats.<br><br> -- <em>[Robert Heinlein]</em>",
    "[PMS | Pre-menstrual Syndrome] - Just before their periods women behave the way men do all the time.<br><br>-- <em>[Robert Heinlein]</em>",
    "Women are meant to be loved, not understood.<br><br>-- <em>[Oscar Wilde]</em>",
    "Rascality has limits; [stupidity] has not.<br><br>--  <em>[Napoleon Bonaparte] </em>",
    "The [optimist] proclaims that we live in the best of all possible worlds; the [pessimist] fears this is true.<br><br>-- <em>[James Branch Cabell]</em>",
    "Obvious is the most dangerous word in mathematics.<br><br>-- <em>[Eric Bell]</em>",
    "Minds are like parachutes; they only function when they are open. -- <em>[Sir James Dewar]</em>",
    "Don't go around saying the world owes you a [living]; the world owes you [nothing]; it was here first.<br><br>-- <em>[Mark Twain]</em>",
    "The man who never makes a mistake always takes orders from one who does.",
    "If a [million] people say a foolish thing, it is still a [foolish] thing.-- <em>[Anatole France]</em>",
    "Too bad all the people who know how to run this country are busy running [taxi | taxicabs] or [hairdresser | cutting hair]. - <em>[George Burns]</em>",
    "The only [fool] bigger than the person who knows it all is the person who argues with him.<br><br>-- <em>[Stanislaw Jerszy Lec]</em>",
    "I will not [condemn] you for what you did yesterday, if you do it right today.<br><br>--<em>[Sheldon S. Maye]</em>",
    "We know what a person thinks not when he tells us what he thinks, but by his actions. <br><br>-- <em>[Isaac Bashevis Singer]</em>",
    "Those are my [principles]. If you don't like them I have others.<br><br>-- <em>[Groucho Marx]</em>",
    "A [classic] is a book which people praise and don't read.<br><br>-- <em>[Mark Twain]</em>",
    "A jury consists of twelve people who determine which client has the better [lawyer].<br><br>-- <em>[Robert Frost]</em>",
    "Of those who say [nothing], few are silent.<br><br>-- <em>[Thomas Neill]</em>",
    "[Wise] men talk because they have something to say; [fools], because they have to say something.<br><br>-- <em>[Plato]</em>",
    "Those who cannot remember the [past] are condemned to repeat it.<br><br>-- <em>[George Santayana]</em>",
    "There are three types of people in this world. Those who can count, and those who can't. - <em>Seen on a [bumper sticker]</em>",
    "[History] is the version of past events that people have decided to agree upon.<br><br>-- <em>[Napoleon Bonaparte]</em>",
    "I can't understand why people are frightened by new ideas. I'm frightened of old ones. <br><br>-- <em>[John Cage]</em>",
    "[Imagination] is the one weapon in the war against reality.<br><br>-- <em>[Jules de Gaultier]</em>",
    "The important thing is never to stop questioning.<br><br>-- <em>[Albert Einstein]</em>",
    "If you want to make enemies, try to change something.<br><br>-- <em>[Woodrow Wilson]</em>",
    "You must believe in free will; there is no choice.<br><br>-- <em>[Isaac Bashevis Singer]</em>",
    "I haven't failed, I've found 10,000 ways that don't work.<br><br>-- <em>[Albert Einstein]</em>",
    "Why does the [USAF | Air Force] need expensive new bombers? Have the people we've been bombing over the years been complaining?<br><br>-- <em>[George Wallace]</em>",
    "A [cynic] is a man who knows the price of everything, and the value of nothing. <br><br>-- <em>[Oscar Wilde]</em>",
    "Don't say you don't have enough time. You have exactly the same number of hours per day that were given to [Helen Keller], [Pasteur], [Michaelangelo], [Mother Teresa], [Leonardo da Vinci], [Thomas Jefferson], and [Albert Einstein].<br><br>-- <em>[H. Jackson Brown]</em>",
    "It's kind of fun to do the impossible.<br><br> -- <em>[Walt Disney]</em>",
    "It has to start somewhere. It has to start sometime. What better place than here? What better time than now?<br><br>-- <em>[Rage Against the Machine], [Guerilla Radio], [The Battle of Los Angeles]</em>",
    "[Dog eat Dog], every day<br>On our fellow men we pray<br>Dog eat Dog, to get by<br>Hope you like my [genocide].<br><br>-- <em>[The Offspring], [Genocide], [Smash]</em>",
    "[Life] is a lesson, you learn it when you're through.<br><br> -- <em>[Limp Bizkit], [Take a Look Around]</em>",
    "Who is the greater [fool]?  <br> The fool or the fool that follows him?<br><br>-- <em>[Obi-Wan Kenobi], [Star Wars | Star Wars: A New Hope]</em>",
    "[Do or do not], There is no try.<br><br>-- <em>[Yoda], [The Empire Strikes Back | Star Wars The Empire Strikes Back]</em>",
    "'[Houston], we have a problem.'<br><br>-- <em>[Jim Lovell], on board [Apollo 13]</em>",
    "There is no [king] who has not had a slave among his ancestors, and no [slave] who has not had a king among his.<br><br>-- <em>[Helen Keller]</em>",
    "There is nothing like returning to a place that remains unchanged to find the ways in which you yourself have altered.<br><br>-- <em>[Nelson Mandela]</em>",
    "There is nothing that can be said by [mathematical] symbols and relations which cannot also be said by words. The converse, however, is false. Much that can be and is said by words cannot successfully be put into equations, because it is [nonsense].<br><br>-- <em>[C. Truesdell]</em>",
    "There was never a [genius] without a [tincture] of [madness]. <br><br>-- <em>[Aristotle]</em>",
    "There's a difference between [beauty] and [charm]. A beautiful woman is one I notice. A charming woman is one who notices me.<br><Br>-- <em>[John Erskine]</em>",
    "There's a fine line between [genius] and [insanity]. I have erased this line. <br><br>-- <em>[Oscar Levant]</em>",
    "There's many a best-seller that could have been prevented by a good teacher.<br><br>-- <em>[Flannery O'Connor]</em>",
    "Those parts of the system that you can hit with a [hammer] (not advised) are called [hardware]; those program instructions that you can only curse at are called [software].",
    "This [book] fills a much-needed gap. <br><br>-- <em>[Moses Hadas]</em>",
    "Weaselling out of things is good. It's what separates us from the other animals....except [weasel | weasels].<br><br>-- <em>[Homer Simpson]</em>",
    "Whenever I dwell for any length of time on my own shortcomings, they gradually begin to seem mild, [harmless], rather engaging little things, not at all like the staring [defect | defects] in other people's characters.<br><br>-- <em>[Margaret Halsey]</em>",
    "Whenever I'm caught between two [evil | evils], I take the one I've never tried.<br><br>-- <em>[Mae West]</em>",
    "Who controls the [past] controls the [future]. Who controls the [present] controls the [past]. <br><br>-- <em>[George Orwell]</em>",
    "Whenever you find that you are on the side of the [majority], it is time to reform.<br><br>-- <em>[Mark Twain]</em>",
    "Whether outwardly or inwardly, whether in [space] or [time], the farther we penetrate the [unknown], the [vaster] and more [marvellous] it becomes.<br><br>-- <em>[Charles Lindbergh]</em>",
    "Whoever controls the [media]...the [image | images]...controls the [culture].<br><br> -- <em>[Allen Ginsberg]</em>",
    "Whoever undertakes to set himself up as a judge of [Truth] and [Knowledge] is shipwrecked by the laughter of the [God | gods].<br><br>-- <em>[Albert Einstein]</em>",
    "Why are [women] so much more interesting to [men] than [men] are to [women]?<br><br>-- <em>[Virginia Wolf]</em>",
    "Don't you try to out-weird me... I get stranger things than you free with my breakfast cereal<br><br>-- <em>[Zaphod Beeblebrox], [The Hitch Hiker's Guide to the Galaxy]</em>",
    "Time is an [illusion]. Lunchtime doubly so.<br><br> -- <em>[Ford Prefect], [The Hitch Hiker's Guide to the Galaxy]</em>",
    "One must have an interesting lifestyle if one has occasion to use the plural of '[clitoris]'. <br><br>-- <em>[Reverend | Rev.] Tony Bell (Letter to the '[Grauniad | Guardian]')</em>",
    "We are all in the [gutter], but some of us are looking at the [stars].<br><br>-- <em>[Oscar Wilde]</em>",
    "Winning is not [everything]. It's the [only] thing.<br><br>-- <em>[Vince Lombardi]</em>",
    "I often think that the night is more [alive] and more richly coloured than the day.<br><br>-- <em>[Vincent Van Gogh]</em>",
    "If an [American] is hit on the head by a ball at the ballpark, he sues. If a [Japanese] person is hit on the head, he says, 'It's my honour. It's my fault.'<br><br> -- <em>[Koji Yanase], of the [Japanese Federation of Bar Associations], on why there are half as many lawyers in his country as in the [Washington] area.</em>",
    "I ask people why they have deer heads on their walls. They say, \"Because it's such a [beautiful] animal.\" There you go! I think my mother is attractive, but I have [photograph|photographs] of her. <br><br> -- <em>[Ellen Degeneres]</em>",
    "I must not [fear]. Fear is the mind-killer. Fear is the [little death] that brings total obliteration. I will face my fear. I will permit it to pass over me and through me. And when it has gone past I will turn the inner eye to see its path. Where the fear has gone there will be nothing. [Only I will remain].<br><br> -- <em>[Frank Herbert], '[Bene Geressit] Litany Against Fear', [Dune]</em>",
    "The concept of [progress] acts as a mechanism to shield us from the terrors of the [future].<br><br>-- <em>[Frank Herbert], from the [Collected Sayings of Muad`Dib] by [Princess Irulan], [Dune]</em>",
    "Deep in the human unconscious is a pervasive need for a logical universe that makes sense. But the real universe is always one step beyond logic. <br><br>- <em>[Frank Herbert], from the [Collected Sayings of Muad`Dib] by [Princess Irulan], , [Dune]</em>",
    "[Touch the puppy] is so seriously [wrong] I have to suggest it.", 
    "If all the [raindrops] were [lemon drops] and [gum drops] oh what a world it would be!", 
    "In the land of the blind, the one eyed man is [king].",
    "When smashing monuments, save the pedestals - they always come in handy. -- <em>[Stanislaw Jerszy Lec]</em>",  
    "An intellect does not function on the premise of its own [impotence].<br><br>-- <em>[Ayn Rand]</em>",
    "Any sufficiently advanced [technology] is indistinguishable from [magic].<br><br>-- <em>[Arthur C. Clarke]</em>",
    "You see things and say, '[Why]?' But I dream things that never were and say, '[Why not]?'.<br><br>-- <em>[George Bernard Shaw]</em>",
    "If one morning I walked on top of the water across the [Potomac River], the headline that afternoon would read 'PRESIDENT CAN'T SWIM'.<br><br>-- <em>[Lyndon B. Johnson]</em>",
    "A citizen of [America] will cross the ocean to fight for [democracy], but won't cross the street to vote in a national [election].<br><br> -- <em>[Bill Vaughan]</em>",
    "Like a [monkey] ready to be shot off into a space. A [space monkey].<br><br> -- <em>[Tyler Durden], [Fight Club]</em>",
    "[Fashion] is what you adopt when you don't know who you are.<br><br>-- <em>[Quentin Crisp]</em>",
    "The mind of the [bigot] is like the [pupil] of the eye - the more [light] you pour upon it, the more it will [contract] <br><br>-- <em>[Oliver Wendell Holmes]</em>",
    "Millions long for [immortality] who do not know what to do with themselves on a rainy Sunday afternoon.<br><br>-- <em>[Susan Ertz]</em>",
    "A [fanatic] is one who can't change his [mind] and won't change the [subject].<br><br>-- <em>[Winston Churchill]</em>",  
    "I'm desperately trying to figure out why [kamikaze] pilots wore helmets. <br><br>-- <em>[Dave Edison]</em>", 
    "The person who is [master] of their [passion | passions] is [reason | reason's] slave. <br><br>--<em>[Cyril Connelly]</em>",
    "When the facts change, I change my mind -- what do you do, sir?.<br><br>-- <em>[John Maynard Keynes], upon being questioned by reporters about changing his mind on an issue</em>",
    "You're [ugly]. And you're [boring]. And you're totally [ordinary], and you know it.<br><br>-- <Em>[American Beauty]</em>",
    "The highest function of [ecology] is understanding consequences. <br><br>-- <em>[Frank Herbert], [Dune]</em>",
    "I don't believe in [God] because I don't believe in [Mother Goose].<br><br>-- <em>[Clarence Darrow]</em> ",
    "[Monkey]! [Bat]! [Robot Hat]!",
    "[Hail], Emperor, those who will die salute you.<br><br>-- <em>The [Gladiator | fighters'] greeting to the [Emperor] before gladiatorial games</em>",
    "There is no problem that cannot be solved with the proper application of [TNT | high explosives] - Me, amongst others.<br><br>--<em>[Glowin Orb]</em>",
    "[Commercialism] is a poor substitute for [angular momentum].<br><br>-- <em>[Fruan]'s retort to the statement '[Money makes the world go round  | Money makes the World go 'round].'</em>"
  ];

  return e2.linkparse(quoteserver[Math.floor(Math.random() * quoteserver.length)]);
});

/* [My Chatterlight] / 1983409 */

function InDebugMode(){
   return window.location.href.indexOf("debug")>0;
}

// General vars
var contentRefreshInterval = null;
var statusId = 0;

// Chatterbox vars
var chat_RefreshTime = 10000;   // in milliseconds (1000ms = 1s, 10000ms = 10s)
var chat_MsgLimit = 0;
var chat_MsgTime = new Date(2000, 1, 1);  // just a date in the past, the actual value doesn't matter
var chat_LastMessage = new Date();
var chat_NextSilenceNotification = 60000;
var chat_SilenceNotificationInterval = 60000;
var chat_IsFirstLoad = true;
var chat_GravatarSize = 32;
var chat_EggCommands = {
   anvil:         'anvils',
   blame:         'blames',
   egg:           'eggs',
   fireball:      'casts fireball on',
   giantsquid:    'giant squids',
   highfive:      'highfives',
   hug:           'hugs',
   hugg:          'mis-spells',
   immolate:      'casts fireball on',
   maul:          'mauls',
   omelet:        'omelets',
   omelette:      'French-omelets',
   pie:           'pies',
   pizza:         'pizzas',
   rubberchicken: 'rubber chickens',
   smite:         'smites',
   special:       "does something 'special' to",
   tea:           'makes a nice cup of tea for',
   tomato:        'tomatoes'
};

// Message Inbox vars
var mi_RefreshTime = 60000;    // in milliseconds (1000ms = 1s, 60000ms = 1min)
var mi_MsgLimit = 0;
var mi_IsFirstLoad = true;
var mi_Backtime = 1440;        // in minutes (1440min = 1day)
var mi_GravatarSize = 32;

// Other Users vars
var ou_RefreshTime = 60000;    // in milliseconds
var ou_IsFirstLoad = true;
var ou_GravatarSize = 22;

function RefreshMessageInbox(){
   $.ajax({
      type: 'GET',
      url: '/index.pl?node=Universal Message XML Ticker&for_node=me&msglimit='+mi_MsgLimit+'&backtime='+mi_Backtime,
      dataType: 'xml',
      timeout: 25000,
      success: ParseMessageInbox
   });
}

function ParseMessageInbox(xml){
   if(InDebugMode()){
      // TODO
   }

   var msgCtr = 0;
   var author, group, html;
   $(xml).find("msg").each(function(){
      if($(this).attr('archive')!='1'){
         msgCtr++;
         mi_MsgLimit = $(this).attr('msg_id');
      
         author = $(this).find('from').find('e2link');
         group = $(this).find('grp').find('e2link');
      
         html = '<div class="Private clearfix" id="msg_'+mi_MsgLimit+'">';// +
         html+=   '<img src="https://s3-us-west-2.amazonaws.com/hnimagew.everything2.com/' + GetClassName(author.text()) + '" alt="'+GetClassName(author.text())+'" align="left" height="'+mi_GravatarSize+'" width="'+mi_GravatarSize+'" />';// +
         html+=   '<p class="To">Private Message from <a href="/user/'+$.trim(author.text())+'">'+author.text()+'</a></b> to ';
         if(group.length==0){html += 'you';}
         else{html += '<a href="/node/usergroup/'+$.trim(group.text())+'">'+group.text()+'</a>';}
         html += ' ('+ParseE2Date($(this).attr('msg_time'))+')</p>' +
            '<p class="Text">'+$(this).find('txt').text()+'</p>' +
            '<ul>' +
            '<li><a href="#" onclick="Reply(\''+GetMsgUsername(author.text())+'\')">Reply to '+author.text()+'</a></li>';
         if(group.length>0){html += '<li><a href="#" onclick="Reply(\''+GetMsgUsername(group.text())+'\')">Reply to '+group.text()+'</a></li>';}
         html += '<li><a href="#" onclick="ArchiveMsg('+mi_MsgLimit+')">Archive</a></li>' +
            '<li><a href="#" onclick="DeleteMsg('+mi_MsgLimit+')">Delete</a></li>' +
            '</ul><div class="Clear"></div>' +
            '</div>';

         $('#Chatter').append(html);
      }
   });
   if(mi_IsFirstLoad&&msgCtr>0){
      ShowNotification('All of your private messages for the page 24 hours have been loaded above.');
   }
   ResizeChatArea(msgCtr>0);
   mi_IsFirstLoad = false;
}

function RefreshChatterbox(){
   var d = new Date();
   $.ajax({
      type: 'GET',
      url: '/index.pl?node=Universal Message XML Ticker&msglimit='+chat_MsgLimit+'&backtime=10&t='+d.getTime(),
      dataType: 'xml',
      timeout: 15000,
      success: ParseChatterbox
   });
}
function ParseChatterbox(xml){
   var uniqueId;
   // get topic
   var topic = $(xml).find('topic').text();
   /*
    * Why use the 'utility' area? When you take text (or HTML) and put it into the DOM, the 
    * browser may change the content as it sees fit (usually whitespace and
    * linebreaks, but it is not limited to that). Therefore comparing our
    * variable to the innerHTML of an existing DOM object might not match up even
    * if the topic has not changed. So we put our "new" topic into a hidden DOM
    * object, and compare the inner content of the two objects instead.
    */
   $('#utility').html(topic);
   // if the topic has changed, let the user know
   if ($('#utility').html() != $('#Topic').html()){
      if ($('#Topic').html() != ''){
         ShowNotification('The topic has changed.');
      }
      $('#Topic').html(topic);
   }

   var msgTime, minutes, author, newMsgLimit;
   var msgCtr = 0;

   /*
    * I found it extremely difficult to debug certain things while no one was talking,
    * this just adds some random text to the chatter on each reload.
    */
   if (InDebugMode()){
      var rndMsgId = GenerateUniqueId(10);
      $('#Chatter').append('<div class="msg" id="msg_'+rndMsgId+'">' + 
         '&lt;<a href="/user/'+rndMsgId+'" class="Author '+GetClassName(rndMsgId)+'">'+rndMsgId+'</a>&gt; ' +
         '<span class="Text">'+ParseMsgText(rndMsgId)+'</span>' +
         '</div>');
   }

   var html;
   $(xml).find("msg").each(function()
   {
      // set vars
      // It's possible that if a user force refresheds (or just "Talks"),
      // that we'll get duplicate messages, so we filter below based on the msg_id
      newMsgLimit = $(this).attr('msg_id');
      if (newMsgLimit > chat_MsgLimit){
         msgCtr++;
         html = ParsePublicMessage($(this));
         $('#Chatter').append(html);
      }
   });

   if (msgCtr==0 && chat_IsFirstLoad){
      ShowNotification('<b>You appear to be alone. No one has said anything for quite a while. Say something interesting, and maybe someone will respond...</b>');
   }
   var now = new Date();
   var silenceCount = now.getTime() - chat_LastMessage.getTime();
   if (silenceCount >= chat_NextSilenceNotification){
      chat_NextSilenceNotification += chat_SilenceNotificationInterval;
      ShowNotification('Nothing has been said in the last '+Math.floor(silenceCount/1000.0)+' seconds');
   }
   ResizeChatArea(msgCtr>0);
   chat_IsFirstLoad = false;
}

function ParsePublicMessage(msg){
   var html='';

   // msg time
   var prevMsgTime = chat_MsgTime;
   chat_LastMessage = new Date();
   nextSilenceNotification = chat_SilenceNotificationInterval;
   chat_MsgTime = ParseE2Date($(msg).attr('msg_time'));
   if(prevMsgTime.getMinutes() != chat_MsgTime.getMinutes() || prevMsgTime.getHours() != chat_MsgTime.getHours()){
      html += '<div class="dt">'+chat_MsgTime.getHours()+':'+Pad(chat_MsgTime.getMinutes(),2)+'</div>';
   }

   // Other Users helper
   var author = $(msg).find('from').find('e2link').text();
   if (!IsKnownUser(author)){
      InsertOtherUserUsername(author,true);
   }

   // msg   
   chat_MsgLimit = $(msg).attr('msg_id');
   var txt = $.trim($(msg).find('txt').text());
   var cssClass = 'Msg';
   var authorHtml = GetUserLink(author);
   // handle commands
   if(txt.indexOf('/')==0){
      // update cssClass and remove the command
      var spacePos = txt.indexOf(' ');
      var cmd = $.trim(txt.substring(1,spacePos).toLowerCase());
      cssClass += (' '+cmd);
      txt = $.trim(txt.substring(spacePos));
      if(chat_EggCommands[cmd]){
         txt = (chat_EggCommands[cmd]+' '+txt);
      }
   }else{
      authorHtml = '&lt;'+authorHtml+'&gt;';
   }
// gravatar src = "https://gravatar.com/avatar/'+$(msg).find('from').find('e2link').attr('md5')+'?d='+$('#gravatarType').val()+'&s=22"
   html += ('<div class="'+cssClass+' clearfix" id="'+$(msg).attr('msg_id')+'">' +
      '<img src="https://s3-us-west-2.amazonaws.com/hnimagew.everything2.com/' + GetClassName(author) + '" alt="'+EncodeHtml(author)+'" height="'+chat_GravatarSize+'" width="'+chat_GravatarSize+'" align="left" />' +
      '<span class="Author '+EncodeHtml(author)+'">'+authorHtml+'</span> ' +
      '<span class="Text">'+txt+'</span>' +
      '</div>');
   return html;
}

function ArchiveMsg(id){
   RemoveElement($('#msg_'+id), 1000);
}

function DeleteMsg(id){
   RemoveElement($('#msg_'+id), 1000);
}

function Reply(username){
   $('#message').val('/msg '+GetMsgUsername(username) + ' ').focus();
}

function GetMsgUsername(username){
   return username.replace(' ', '_');
}

function ResizeChatArea(doScroll){
   if(InDebugMode() && (chat_IsFirstLoad || mi_IsFirstLoad || ou_IsFirstLoad)){
      alert('firstload stop');
   }
      

   /*
    * For some reason IE does not handle height() or css('height', x) 
    * properly when you use a calculated value, so we are very explicit
    * in setting the heights below.
    */

   // First grow as needed
   var ch;
   var prevHeight = $(document).height() + 1;
   while(prevHeight > $(document).height()){
      ch = parseInt($('#Chatter').css('height').replace('px',''));
      ch += 10;
      $('#Chatter').css('height',ch+'px');
   }

   var oh;
   prevHeight = $(document).height() + 1;
   while(prevHeight > $(document).height()){
      oh = parseInt($('#OtherUsers').css('height').replace('px',''));
      oh += 10;
      $('#OtherUsers').css('height',oh+'px');
   }

   prevHeight = $(document).height() + 1;
   while(prevHeight > $(document).height()){
      prevHeight = $(document).height();
      ch = parseInt($('#Chatter').css('height').replace('px',''));
      ch -= 1;
      oh = parseInt($('#OtherUsers').css('height').replace('px',''));
      oh -= 1;
      $('#Chatter').css('height',ch+'px');
      $('#OtherUsers').css('height',oh+'px');
   }
   if(doScroll){
      $("#Chatter").attr({ scrollTop: ($("#Chatter").attr("scrollHeight")) });
   }
}

function RemoveElement(sel, speed){
   $(sel).fadeOut(speed, function() { $(this).remove(); });
}

function ParseE2Date(str){
   /*
    * E2's tickers output dates in a format that can't be parsed by JavaScript's
    * built-in date methods, so we needed our own.
    */
   var arDt = str.split(' '); // split into date and time
   if (arDt.length == 2){
      var arYmd = arDt[0].split('-'); // split into year, month, day
      if (arYmd.length == 3){
         var arHms = arDt[1].split(':'); // split into hour, minute, second
         if (arHms.length == 3){
            return new Date(parseInt(arYmd[0]), parseInt(arYmd[1])-1, parseInt(arYmd[2]), parseInt(arHms[0]), parseInt(arHms[1]), parseInt(arHms[2]));
         }
      }else{
         return new Date(2000, 0, 1);
      }
   }else{
      return new Date(2000, 0, 1);
   }
}

/*
 * Generate a unique value that can be used to identify an element for scripting.
 * Statistically, given a large enough 'n' each value will be unique, though
 * of course it is possible that duplicate values could be generated.
 * Example: When n=10, there are 62^10 possible values (839+ quadrillion)
 */
function GenerateUniqueId(n){
   var chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
   var id = '';
   for (var i=0; i<n; i++) {
      var rnum = Math.floor(Math.random() * chars.length);
      id += chars.substring(rnum,rnum+1);
   }
   return id;
}

/*
 * Left-pads a number with zeros. Useful for outputing dates (i.e., months
 * and days).
 * Example: For April, output "04" instead of "4".
 */
function Pad(n,ln){
   var sn = n+'';
   while(sn.length<ln){
      sn = '0'+sn;
   }
   return sn;
}

/*
 * Basically, and symbol or non-ASCII character cases problems with jQuery
 * and/or CSS selectors. Some of the issues are obvious due to the syntax of
 * jQuery and CSS, but others may just be illegal characters for class names
 * and ids. This function removes inappropriate characters. The only
 * exception are dashes and underscores (which are legal), and spaces which
 * are converted to underscores instead of being removed.
 */
var regexpClassName = new RegExp('([^A-Za-z0-9_\\- ])','g');
function GetClassName(s){
   s = s.replace(/([^A-Za-z0-9_\-])/g, '_');
   //while(s.match(regexpClassName )){
   //   s = s.replace(regexpClassName, '');
   //}
   //while(s.indexOf(' ')>=0){
   //   s = s.replace(' ', '_');
   //}
   return s;
}

/*
 * This function is incomplete. Its purpose is (will be) to properly format messages
 * so they are output similarly to how [showchatter] outputs them. Examples of
 * messages that need formatting include: /me, /sing, /fireball, etc.
 */
function ParseMsgText(txt){
   return txt;
}

function Talk()
{
   var msg = $.trim($('#message').val());
   $('#message').val('');
   var checkmsg = ''; // this is temporary, in the future it will hold private msgs to be deleted
   if (msg.length > 0){
      $.ajax({
         type: 'POST',
         data: 'node=Universal Message XML Ticker&msglimit='+chat_MsgLimit+'&backtime=10&op=message&message='+encodeURIComponent(msg),
         url: '/index.pl',
         dataType: 'xml',
         timeout: 15000,
         contentType: 'application/x-www-form-urlencoded',
         success: ParseChatterbox
      });
      if(msg.indexOf('/msg')==0||msg.indexOf('/tell')==0){
         RefreshMessageInbox();
      }
   }else{
      RefreshChatterbox();
   }
}

/*
 *==============================================================================
 * OTHER USERS
 *==============================================================================
 */

function RefreshOtherUsers(){
   $.ajax({
      type: 'GET',
      url: '/index.pl?node=Other Users XML Ticker II&nosort=1',
      dataType: 'xml',
      success: ParseOtherUsers
   });
}

function IsKnownUser(username){
   var id = GetClassName(username);
   if ($('#OU_'+id).length > 0){
      return true;
   }
   return false;
}

function ParseOtherUsers(xml){
   // First loop through and add users
   var curUserCount = $('#OtherUsers').find('.OtherUser').length;
   var newUserCount = 0;
   $(xml).find("user").each(function()
   {
      author = $.trim($(this).find('e2link').text());
      if (!IsKnownUser(author)){
         InsertOtherUser($(this));
         newUserCount++;
      }
   });
   // Then loop through and remove users
   var found, username;
   $('#OtherUsers').find('.Username').each(function(){
      username = $.trim($(this).text());
      found = false;
      $(xml).find('e2link').each(function()
      {
         if($.trim($(this).text()).toUpperCase() == username.toUpperCase()){
            found=true;
            return;
         }
      });
      if(!found){
         RemoveElement('#OU_'+GetClassName(username), 5000);
      }
   });
   if(newUserCount>0){
      RemoveElement('.NewOu', 60000);
   }
   ou_IsFirstLoad = false;
   $('#ou_loading').css('visibility', 'hidden');
}

function InsertOtherUserUsername(username, isTemp){
   var inserted=false;
   var id = 'OU_'+GetClassName(username);
   var html;
   $('#OtherUsers').find('.Username').each(function(){
      if(inserted){return;}
      if(username.toUpperCase() <= $(this).text().toUpperCase()){
         html = '<div class="OtherUser" id="'+id+'"><a class="Username" href="/user/'+username+'">'+username+'</a>';
         if(!ou_IsFirstLoad){
            html += '<span class="NewOu">New Login</span>';
         }
         html += '</div>';
         $(this).parent().before(html);
         inserted=true;
         return;
      }
   });
   if(!inserted){
      html = '<div class="OtherUser" id="'+id+'"><a class="Username" href="/user/'+username+'">'+username+'</a>';
      if(!ou_IsFirstLoad){
         html += '<span class="NewOu">New Login</span>';
      }
      html += '</div>';
      $('#OtherUsers').append(html);
   }
   /*
    * Why temp? Because the other users nodelet is only updated every 5(?)
    * minutes, and we might discover other online users by watching the actual
    * chatter. Unfortunately, the universal message xml ticker does not tell us
    * who the editors, admins, coders, edev, ops, etc are. Therefore, we add a
    * temporary entry in the page's other users list, and add the 'official'
    * entry when the other users ticker updates itself.
    */
   if(isTemp){
      RemoveElement('#'+id, 30000);
   }
   return id;
}

function InsertOtherUser(ou){
   var inserted=false;
   var username = $.trim($(ou).find('e2link').text());
   var id = InsertOtherUserUsername(username, false);
   var md5 = $(ou).find('e2link').attr('md5');
   if(md5.length==32){
      $('#'+id).prepend('<img src="https://s3-us-west-2.amazonaws.com/hnimagew.everything2.com/' + GetClassName(author) + '" alt="'+GetClassName(username)+'" height="'+ou_GravatarSize+'" width="'+ou_GravatarSize+'" /> ');
   }
   var position = '';
   if($(ou).attr('e2god')=='1'){position+='<abbr title="Administrator"> @ </abbr>';}
   if($(ou).attr('ce')=='1'){position+='<abbr title="Editor"> $ </abbr>';}
   if($(ou).attr('chanop')=='1'){position+='<abbr title="Chat Moderator"> ! </abbr>';}
   if($(ou).attr('committer')=='1'){position+='<abbr title="Sr. Developer"> * </abbr>';}
   if($(ou).attr('edev')=='1'){position+='<abbr title="Jr. Developer"> % </abbr>';}
   if(position.length>0){
      $('#'+id).append(' ('+position+')');
   }
}


function OtherUsersSort(a,b){
   if(a.username.toUpperCase()<b.username.toUpperCase()){
      return -1;
   }else{
      return 1;
   }
}

/*
 *========================================
 * General Methods
 *========================================
 */
function ShowNotification(s){
   var uniqueId = GenerateUniqueId(10);
   $('#Chatter').append('<div class="Note" id="s_'+uniqueId+'">'+s+'</div>');
   RemoveElement('#s_'+uniqueId, 45000);
   ResizeChatArea(true);
}

function GetUserUrl(u){
   return '/user/'+encodeURIComponent(u);
}

function GetUserLink(u){
   return '<a href="'+GetUserUrl(u)+'">'+EncodeHtml(u)+'</a>';
}

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

/* end [My Chatterlight] / 1983409 */

/* [Message Inbox 2] / 1798778 */

function replyTo(s, c) {
       if (c || document.message_inbox_form.setvar_autofillInbox.checked) {
          document.message_inbox_form.message.value = "/msg "+s+" ";
          document.message_inbox_form.message.focus();
       }
}

function clearReply() {
	document.message_inbox_form.message.value = "";
}

function checkAll(){
    for (i=0; i < document.message_inbox_form.elements.length; i++) {
      if(document.message_inbox_form.elements[i].name.substring(0,9) == "deletemsg")
          {document.message_inbox_form.elements[i].checked=true;}
    }
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

/* Google Analytics Script */
(function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
(i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
})(window,document,'script','//www.google-analytics.com/analytics.js','ga');

ga('create', 'UA-1314738-1', 'auto');
ga('require', 'displayfeatures');
ga('send', 'pageview');
