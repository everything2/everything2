// 1884065.js - E2 Annotation tool
// Possibly unused

var AnnotationTool = {

	node_id: null,
	ajaxNode: 1873513,
	URL : "/index.pl",
	allowdelete: 1,
	color: "",
	node_id: "0",
	nextlocation : "",
	currentblab : null,
	makeblabroot : null,
	blabregexp : new RegExp("msgwuauthor",""),
	scratchregexp : new RegExp("skratchMsg",""),

	AnnotationTool: function() {

 		AnnotationTool.init();
 



 
 
	},

	makeblab: function(node) {
		if (AnnotationTool.makeblabroot==null) {
			AnnotationTool.makeblabroot=node;
		}

		if (node.name && (node.name.match(AnnotationTool.blabregexp) || node.name.match(AnnotationTool.scratchregexp))) {
			if (node.type=="text"){
				if (AnnotationTool.currentblab != null && AnnotationTool.currentblab.value=="[e2 annotation tool|annotations]: ") {
					AnnotationTool.currentblab.value="";
				}
				AnnotationTool.currentblab=node;
				AnnotationTool.currentblab.value="[e2 annotation tool|annotations]: ";
			 }
		}
		else if (node.className == "oddrow annotationspan") {
			// if we are in the scope of a blabbox, add the comment to it.
			if (AnnotationTool.currentblab!=null) { 
				AnnotationTool.currentblab.value+=node.id+"; ";
			 }
		}
		else if (node.hasChildNodes()) {
			// visit each child 
			for(var child=node.firstChild; child!=null; child=child.nextSibling) {
				AnnotationTool.makeblab(child);
			}
		 }
		// test whether to terminate recursion and remove the blabbox initialisation
		if (node==AnnotationTool.makeblabroot) {
			node=null;
			if (AnnotationTool.currentblab != null && AnnotationTool.currentblab.value=="[e2 annotation tool|annotations]: ") {
				AnnotationTool.currentblab.value="";
			 }
		 }
	},

	searchFor : function(regex,node) {
		var returnval=null;
		if (node.nodeType==3){
			if (node.data.match(regex)) {
				 return "ok";
			 } 
		 }
		else if (node.hasChildNodes()) {
			 if (node.nodeType==1 && node.tagName=="TEXTAREA") {
				 return null;
			 }
			 for(var child=node.firstChild; child!=null; child=child.nextSibling) {
				 returnval = AnnotationTool.searchFor(regex,child);
				 if (returnval=="ok") {
					return [node,child];
				 }
				 else if (returnval!=null) {
					return returnval;
				 }
			 }
		 }

		 return returnval;
	},

	killcomment : function(text) {
		params = {
			annotation_id: AnnotationTool.node_id,
			del: encodeURIComponent(text)
		};
		new Ajax.Request(AnnotationTool.URL, {parameters: params});
	},


	init : function() {

		AnnotationTool.node_id = e2.node_id;

 		AnnotationTool.allowdelete = (document.body.className.search(/\bwriteup\b/)==-1 && document.title!="Nothing Found@Everything2.com" && document.title!="Findings:@Everything2.com");

		params = {
			annotation_id : AnnotationTool.node_id,
			mode: "annotate",
			node_id: AnnotationTool.ajaxNode
		};
 
		new Ajax.Request(AnnotationTool.URL, {parameters: params, onComplete: function(annotations) {
			//alert(annotations.responseText);
			for (var comment in annotations) {
				new Comment(annotations[comment][0],annotations[comment][1]);
			} 
		 }}
		 );

 
		form1 = AnnotationTool.create("div","enable annotation adding",{name: "annotatorform", id: "annotatorform", style: "padding: 0px 1px 2px 1px; border: 1px solid black;", className: "oddrow"});

		addannotation = AnnotationTool.create("input","",{id: "addannotation", name: "addannotation", type: "checkbox", checked: ""});

		putinblab = AnnotationTool.create("small", "makeblabs", {style: "color : blue; padding: 2px 2px 0px 2px; margin: -2px 0px 2px 5px; border : 1px solid black; cursor : pointer; display: inline", id: "makeblabs"});
		
	 	form1.appendChild(addannotation);
		form1.appendChild(putinblab);

		 // put notelet in position
		$('annotate').setStyle({
			position: "fixed",
			top: "0px",
			left: "0px",
			height: "2ex",
			borderTop: "1px solid black",
		});

 		// make the background color for the form
		 AnnotationTool.color=$('annotate').className;
		 if (AnnotationTool.color!="") {
			 form1.style.backgroundColor=AnnotationTool.color;
		 }
 
		 // put the form in the notelet
		 $('annotate').appendChild(form1);

		Event.observe('makeblabs','mousedown', function() {AnnotationTool.makeblab(document.documentElement);});

		Event.observe($(document),"mouseup",function() {

			 if ($("addannotation").checked) {
				txt= (window.getSelection)? window.getSelection(): document.selection.createRange().text;
				txt = txt.toString();
				if (txt.length>0) {
					$("addannotation").checked=false;
					new AnnotationTool.Annotator(txt);
				 }
			}
		 });

 		AnnotationTool.nextlocation="";

 	},

	Annotator: function(location) {

		 AnnotationTool.nextlocation=location;

		 //find the textnode and its parent
		 var commentplace = AnnotationTool.searchFor(new RegExp(location, ""),document.documentElement);
		 if (commentplace==null) {
			 alert("You mustn't include any links, italics or bolds in your selection");
			 return null;
		 }

		parent=commentplace[0];
		child=commentplace[1];

		form=AnnotationTool.create("form",location+":",{style : "margin-bottom: 0px", id: 'annoform'});

		anchor= AnnotationTool.create("span"," ",{style: "position: relative; display: inline;", id: "anchor"});

		box= AnnotationTool.create("div",content,{style: "position: absolute; background-color: white; border: 1px solid black; color: #222; display: block; top: 10px; left: 0px; padding: 2px", id: "annobox"});	

		commands= AnnotationTool.create("span");

		cancel = AnnotationTool.create("small","cancel", {style: "color: blue; text-decoration: underline; cursor: pointer", id: "cancel"});  


		ok = AnnotationTool.create("small","ok", {style: "color: blue; margin-left: 5px; text-decoration: underline; cursor: pointer", id : "ok"});  




		commentinput = AnnotationTool.create("input","",{type: "text", id: "commentinput"});

		commands.appendChild(cancel);
		commands.appendChild(ok);
		form.appendChild(commentinput);
		form.appendChild(commands);
	 	box.appendChild(form);
	 	anchor.appendChild(box);

	 	parent.insertBefore(anchor,child); 
		//$('commentinput').select();

		Event.observe($('annoform'),"submit", function() {AnnotationTool.submitIt();});

		Event.observe($('ok'),"mousedown", function() {AnnotationTool.submitIt();});


		Event.observe($('cancel'),"mousedown", function() {
			$('annobox').remove(); 
			$("addannotation").checked=true;
		});

	


	},

	submitIt: function() {
alert(AnnotationTool.node_id);
		var commentinput = $F("commentinput");
		params = {
			mode: "annotate",
			node_id: AnnotationTool.ajaxNode,
			annotation_id : AnnotationTool.node_id,
			location: AnnotationTool.nextlocation,
			comment: commentinput
		};
		 new Ajax.Request(AnnotationTool.URL, {parameters: params, onComplete: function(response) {alert(response.responseText);}});
		 $('annobox').remove(); 
		 new Comment(AnnotationTool.nextlocation,commentinput);
		 $("addannotation").checked=true;
 	},

	Comment: function(location, comment) {
		 if (location=="") {location="dlfhdjfhskjfhjskdhfjkdhfjd";}
		 var commentplace = AnnotationTool.searchFor(new RegExp(location, ""),document.documentElement);
		 if (commentplace==null){
			 if (AnnotationTool.node_id!=1147724 && AnnotationTool.node_id!=1065273 && AnnotationTool.allowdelete) {
				 AnnotationTool.killcomment(location);
			 }
			 return null;
		 }

//alert("test");
		var parent = commentplace[0];
		var child = commentplace[1];
		var sibling = child.nextSibling;
		parent.removeChild(child);
		var othertext = child.data.split(location);

		span1 = AnnotationTool.create("span",location,{style: "padding: 1px; background-color: " +AnnotationTool.color, className: "oddrow annotationspan", id: location + " -> " + comment});
 
//alert(sibling);
		 if (sibling != null) {
			 parent.insertBefore(document.createTextNode(othertext[0]),sibling);
			 parent.insertBefore(span1,sibling); 
			 parent.insertBefore(document.createTextNode(othertext[1]),sibling);
		 }
		 else {
			 parent.appendChild(document.createTextNode(othertext[0]));
			 parent.appendChild(span1); 
			 parent.appendChild(document.createTextNode(othertext[1]));
		 }
		
		 new SmallBox(10,10,comment,span1);
	},

	create: function(elType,elText,attributes) {
		el = document.createElement(elType);
		elText = $A(elText);
		elText.each(function(s) {
			if (typeof(s) == "string") {
				el.appendChild(document.createTextNode(s));
			}
			else {
				el.appendChild(s);
			}
		});
		if (attributes) {
			h = $H(attributes);
			h.each(function(pair) {
				el.setAttribute(pair.key,pair.value);
			});
		}
		return el;
	},

	smallBox: function(x,y,content,parent,id) {

		parent.style.position="relative";

		box= create("div",content,{style: "position: absolute; background-color: white; border: 1px solid black; color: #222; display: none; top: "+y+"; left: "+x+"; padding: 2px"});

 		if (content.length>50) {
			 box.style.width="300px";
		 }
 
 		commands=AnnotationTool.create("div");

 		del= AnnotationTool.create("small", "delete", {style: "color: blue; text-decoration: underline; cursor: pointer"});
		del.onmousedown= function(e) {
			 var deltext=this.parentNode.parentNode.parentNode.firstChild; 
			 var delspan=deltext.parentNode;
			 var delparent=delspan.parentNode;
			 delparent.replaceChild(deltext,delspan)
			 AnnotationTool.killcomment(deltext.data);
		 } 

 
		hideLink= AnnotationTool.create("small","hide", {style : 'color: blue; text-decoration:underline; margin-left: 5px; cursor: pointer', id: "anno_hidelink"});
		hideLink.onmousedown= function(e) {
			 this.parentNode.parentNode.style.display="none"; 
		 } 

 		show = AnnotationTool.create("span"," \u2660",{style : 'color: #e33; cursor: pointer; padding-left: 2px', id: "anno_showlink"});
		show.onmousedown= function(e) {
			this.previousSibling.style.display="block";
			this.previousSibling.style.zIndex=1000;
		}

		commands.appendChild(del);
		commands.appendChild(hideLink);

		box.appendChild(commands);

		parent.appendChild(box);
		parent.appendChild(show);

	}
};

AnnotationTool.AnnotationTool(); 
