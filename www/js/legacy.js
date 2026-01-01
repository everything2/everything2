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
	}

// END e2 = $.extend(function(){..} , e2, { ...
});

// NOW DO STUFF:

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

// Unload warning for unsaved changes
e2.beforeunload = {};
window.onbeforeunload = function(e){
	for (var fn in e2.beforeunload){
		var func = e2.beforeunload[fn];
		var str = func(e);
		if (str){
			// Modern browsers show their own confirmation dialog
			e.returnValue = str;
			return str;
		}
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

  // ======================= Update Triggers

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

		// now do it
		var el = this;
		e2.ajax.update(updateTarget, htmlcode,
			{query: query , args: args}, !updateOnly, doneUpdate);
		if (event && event.preventDefault) event.preventDefault();
		return false;

		// tidy up/report error afterwards
		function doneUpdate(stringIfsuccessfulOrRequestIfNot, success, statusText){
			$(el).add(ersatz).removeClass('pending') ;

			if (success) {
				if ( el.originalHeight ) el.style.height = el.originalHeight ;
				if ( el.originalValue != null && el.value == sentValue ) el.value = el.originalValue ;
			} else {
				var tag = target.css('display') == 'block' ? 'div' : 'span';
				target.append('<'+tag+' class="error"><strong>Error:</strong> '+statusText+'</'+tag+'>');
				ersatz.replaceWith(target);
				e2(target); // jquery unbinds all the magic when you take it out of the DOM
			}

			if (hadFocus && $('#'+hadFocus).length)
				e2(function(){$('#'+hadFocus).focus();}).defer() ;
		}
	}
  // END e2.ajax = {
  };

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

  // REMOVED: Drag and drop nodelet sorting (December 2025)
  // Nodelet ordering now managed via Settings page

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

}
// End contents of Everything2 AJAX

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
  // Optimistic UI update - change immediately for responsiveness
  const wasBookmarked = button.getAttribute('data-bookmarked') === '1';
  const newState = !wasBookmarked;

  // Update UI immediately
  button.setAttribute('data-bookmarked', newState ? '1' : '0');
  button.style.color = newState ? '#4060b0' : '#999';
  button.title = newState ? 'Remove bookmark' : 'Bookmark this page';

  try {
    const response = await fetch(`/api/cool/bookmark/${nodeId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });

    const data = await response.json();

    if (!data.success) {
      throw new Error(data.error || 'Failed to toggle bookmark');
    }

    // Verify server state matches our optimistic update (in case of race conditions)
    const isBookmarked = data.bookmarked;
    if (isBookmarked !== newState) {
      button.setAttribute('data-bookmarked', isBookmarked ? '1' : '0');
      button.style.color = isBookmarked ? '#4060b0' : '#999';
      button.title = isBookmarked ? 'Remove bookmark' : 'Bookmark this page';
    }
  } catch (error) {
    // Revert to original state on error
    button.setAttribute('data-bookmarked', wasBookmarked ? '1' : '0');
    button.style.color = wasBookmarked ? '#4060b0' : '#999';
    button.title = wasBookmarked ? 'Remove bookmark' : 'Bookmark this page';

    console.error('Error toggling bookmark:', error);
    alert(`Failed to toggle bookmark: ${error.message}`);
  }
};
